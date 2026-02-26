#!/bin/bash

# --- 1. LOAD EXTERNAL CONFIGURATION ---
CONFIG_FILE="cluster.env"
source "$CONFIG_FILE"
echo "Configuration loaded (Talos $TALOS_VERSION | Network: $BRIDGE_IF | Workers: $WORKER_COUNT)"

# --- 2. INTERNAL VARIABLES ---
CLUSTER_NAME="talos-vbox-demo"
ISO_NAME="metal-amd64.iso"
ISO_URL="https://github.com/siderolabs/talos/releases/download/${TALOS_VERSION}/${ISO_NAME}"

# --- 3. DOWNLOAD THE ISO ---
if [ ! -f "$ISO_NAME" ]; then
    echo "Downloading Talos ISO..."
    if ! curl -Lo "$ISO_NAME" "$ISO_URL"; then
        echo "Error downloading the ISO."
        exit 1
    fi
else
    echo "ISO found locally."
fi

# --- 4. FUNCTION TO CREATE VMs ---
create_vm() {
    local VM_NAME="$1"
    local RAM="$2"

    if VBoxManage showvminfo "$VM_NAME" &> /dev/null; then
        echo "VM '$VM_NAME' already exists. Skipping creation..."
        return
    fi

    echo "Creating: $VM_NAME (${RAM}MB RAM, 10GB Disk, Bridge)..."
    
    VBoxManage createvm --name "$VM_NAME" --ostype "Linux_64" --register > /dev/null
    VBoxManage modifyvm "$VM_NAME" --cpus 2 --memory "$RAM" --vram 16
    VBoxManage modifyvm "$VM_NAME" --nic1 bridged --bridgeadapter1 "$BRIDGE_IF"

    VBoxManage storagectl "$VM_NAME" --name "SATA" --add sata --controller IntelAhci
    VBoxManage createmedium disk --filename "${VM_NAME}.vdi" --size 10240 --format VDI > /dev/null
    VBoxManage storageattach "$VM_NAME" --storagectl "SATA" --port 0 --device 0 --type hdd --medium "${VM_NAME}.vdi"
    
    VBoxManage storageattach "$VM_NAME" --storagectl "SATA" --port 1 --device 0 --type dvddrive --medium "$(pwd)/$ISO_NAME"
    VBoxManage modifyvm "$VM_NAME" --boot1 disk --boot2 dvd --boot3 none --boot4 none
}

# --- 5. CREATE AND START VMS ---
create_vm "$CP_NAME" 2048

# Loop to create as many workers as indicated
if [ "$WORKER_COUNT" -gt 0 ]; then
    for i in $(seq 1 $WORKER_COUNT); do
        create_vm "${WORKER_BASE_NAME}-${i}" 2048
    done
fi

echo "Starting VMs..."
VBoxManage startvm "$CP_NAME" --type headless > /dev/null 2>&1 || echo "   $CP_NAME was already running."

if [ "$WORKER_COUNT" -gt 0 ]; then
    for i in $(seq 1 $WORKER_COUNT); do
        VBoxManage startvm "${WORKER_BASE_NAME}-${i}" --type headless > /dev/null 2>&1 || echo "   ${WORKER_BASE_NAME}-${i} was already running."
    done
fi

# --- 6. ENTER IPs ---
> cluster-ips.env

read -p "Enter IP for $CP_NAME: " CP_IP
echo "CP_IP=\"$CP_IP\"" >> cluster-ips.env

if [ "$WORKER_COUNT" -gt 0 ]; then
    for i in $(seq 1 $WORKER_COUNT); do
        read -p "Enter IP for ${WORKER_BASE_NAME}-${i}: " WORKER_IP
        echo "WORKER_IP_${i}=\"$WORKER_IP\"" >> cluster-ips.env
    done
fi

source cluster-ips.env

echo "---------------------------------------------------"
echo "IPs successfully saved in 'cluster-ips.env'."
echo "Phase 1 completed. VMs are ready for configuration."

# --- 7. GENERATE CONFIGURATION ---
echo "---------------------------------------------------"
echo "Generating Talos configuration files..."
talosctl gen config "$CLUSTER_NAME" "https://${CP_IP}:6443" --force

# --- 8. APPLY CONFIGURATION ---
echo "---------------------------------------------------"
echo "Injecting configuration into Control Plane ($CP_IP)..."
talosctl apply-config --nodes "$CP_IP" --file controlplane.yaml --insecure

if [ "$WORKER_COUNT" -gt 0 ]; then
    for i in $(seq 1 $WORKER_COUNT); do
        var_name="WORKER_IP_${i}"
        W_IP="${!var_name}"
        
        echo "Injecting configuration into Worker ($W_IP)..."
        talosctl apply-config --nodes "$W_IP" --file worker.yaml --insecure
    done
fi

# --- 9. CONFIGURE LOCAL CLIENT ---
export TALOSCONFIG=$(pwd)/talosconfig
talosctl config endpoint "$CP_IP"
talosctl config node "$CP_IP"

# --- 10. SMART WAIT AND BOOTSTRAP ---
echo "---------------------------------------------------"
echo -n "Waiting for Control Plane to install, reboot, and respond "

until timeout 3 talosctl kubeconfig . --nodes "$CP_IP" --endpoints "$CP_IP" --force > /dev/null 2>&1; do
    sleep 5
    echo -n "."
done

echo ""
echo "Control Plane is active"
echo "Starting Bootstrap (etcd)..."
talosctl bootstrap

# --- 11. GET KUBECONFIG ---
echo "---------------------------------------------------"
echo -n "Configuring local kubeconfig"
# This loop attempts to download the file every 5 seconds until successful
until talosctl kubeconfig . --force &> /dev/null; do
    sleep 5
    echo -n "."
done

# --- 12. WAIT FOR CLUSTER TO BE READY ---
echo "---------------------------------------------------"
echo -n "Waiting for Kubernetes API to respond "
until kubectl get nodes --kubeconfig=./kubeconfig > /dev/null 2>&1; do
    sleep 5
done
echo ""

echo "Waiting for network and DNS to start..."
kubectl wait --for=condition=Ready pods --all -n kube-system --timeout=300s --kubeconfig=./kubeconfig

echo "All internal services are running! Cluster is operational."

# --- 13. DEPLOY AND TEST NGINX ---
echo "---------------------------------------------------"
echo "Deploying test Nginx application..."
kubectl apply -f ../manifests/nginx-demo.yaml --kubeconfig=./kubeconfig

echo "Waiting for Nginx containers to be ready..."
kubectl rollout status deployment/nginx-demo --kubeconfig=./kubeconfig

echo "---------------------------------------------------"
echo "Testing HTTP connection to Nginx..."
echo "Making request to http://${CP_IP}:30080"
echo ""

curl -s "http://${CP_IP}:30080" | head -n 15

echo ""
echo "---------------------------------------------------"
echo "AUTOMATION COMPLETED SUCCESSFULLY"