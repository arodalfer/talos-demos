#!/bin/bash

echo "Full cleanup of the Talos environment..."

# --- 1. CLEAN DOCKER ---
echo "1. Cleaning Docker cluster..."
CLUSTER_DOCKER="talos-docker-demo"

if command -v talosctl &> /dev/null; then
    if talosctl cluster destroy --name "$CLUSTER_DOCKER" > /dev/null 2>&1; then
        echo "Cluster '$CLUSTER_DOCKER' removed."
    else
        echo "Cluster '$CLUSTER_DOCKER' not found (or already deleted)."
    fi
else
    echo "talosctl not installed. Skipping Docker cleanup."
fi

# --- 2. CLEAN VIRTUALBOX ---
echo ""
echo "2. Cleaning VirtualBox VMs..."
CONFIG_FILE="cluster.env"

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    
    delete_vm() {
        local VM_NAME="$1"
        if VBoxManage showvminfo "$VM_NAME" &> /dev/null; then
            echo "   Powering off and deleting: $VM_NAME..."
            VBoxManage controlvm "$VM_NAME" poweroff > /dev/null 2>&1
            sleep 2
            VBoxManage unregistervm "$VM_NAME" --delete > /dev/null 2>&1
            echo "$VM_NAME deleted."
        fi
    }

    # Delete Control Plane
    delete_vm "$CP_NAME"
    
    # Delete Workers
    if [ "$WORKER_COUNT" -gt 0 ]; then
        for i in $(seq 1 $WORKER_COUNT); do
            delete_vm "${WORKER_BASE_NAME}-${i}"
        done
    fi
else
    echo "'$CONFIG_FILE' not found. Skipping VirtualBox cleanup."
fi

# --- 3. CLEAN LOCAL FILES ---
echo ""
echo "3. Cleaning local configuration files..."
rm -f kubeconfig talosconfig cluster-ips.env controlplane.yaml worker.yaml

if ls *.iso 1> /dev/null 2>&1; then
    echo ""
    read -p "Do you want to delete the downloaded ISO? (y/N): " DELETE_ISO
    if [[ "$DELETE_ISO" == "y" || "$DELETE_ISO" == "Y" ]]; then
        rm -f *.iso
        echo "ISO deleted."
    else
        echo "ISO kept for future deployments."
    fi
fi

echo "Environment fully cleaned"