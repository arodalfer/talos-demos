#!/bin/bash

# --- 1. CARGAR CONFIGURACIÓN EXTERNA ---
CONFIG_FILE="cluster.env"
source "$CONFIG_FILE"
echo "Configuración cargada (Talos $TALOS_VERSION | Red: $BRIDGE_IF | Workers: $WORKER_COUNT)"

# --- 2. VARIABLES INTERNAS ---
CLUSTER_NAME="talos-vbox-demo"
ISO_NAME="metal-amd64.iso"
ISO_URL="https://github.com/siderolabs/talos/releases/download/${TALOS_VERSION}/${ISO_NAME}"

# --- 3. DESCARGA DE LA ISO ---
if [ ! -f "$ISO_NAME" ]; then
    echo "Descargando ISO de Talos..."
    if ! curl -Lo "$ISO_NAME" "$ISO_URL"; then
        echo "Error al descargar la ISO."
        exit 1
    fi
else
    echo "ISO encontrada localmente."
fi

# --- 4. FUNCIÓN PARA CREAR MÁQUINAS ---
crear_vm() {
    local VM_NAME="$1"
    local RAM="$2"

    if VBoxManage showvminfo "$VM_NAME" &> /dev/null; then
        echo "La máquina '$VM_NAME' ya existe. Omitiendo creación..."
        return
    fi

    echo "Creando: $VM_NAME (${RAM}MB RAM, 10GB Disco, Bridge)..."
    
    VBoxManage createvm --name "$VM_NAME" --ostype "Linux_64" --register > /dev/null
    VBoxManage modifyvm "$VM_NAME" --cpus 2 --memory "$RAM" --vram 16
    VBoxManage modifyvm "$VM_NAME" --nic1 bridged --bridgeadapter1 "$BRIDGE_IF"

    VBoxManage storagectl "$VM_NAME" --name "SATA" --add sata --controller IntelAhci
    VBoxManage createmedium disk --filename "${VM_NAME}.vdi" --size 10240 --format VDI > /dev/null
    VBoxManage storageattach "$VM_NAME" --storagectl "SATA" --port 0 --device 0 --type hdd --medium "${VM_NAME}.vdi"
    
    VBoxManage storageattach "$VM_NAME" --storagectl "SATA" --port 1 --device 0 --type dvddrive --medium "$(pwd)/$ISO_NAME"
    VBoxManage modifyvm "$VM_NAME" --boot1 disk --boot2 dvd --boot3 none --boot4 none
}

# --- 5. CREAR Y ARRANCAR MÁQUINAS ---
crear_vm "$CP_NAME" 2048

# Bucle para crear tantos workers como indique la variable
if [ "$WORKER_COUNT" -gt 0 ]; then
    for i in $(seq 1 $WORKER_COUNT); do
        crear_vm "${WORKER_BASE_NAME}-${i}" 2048
    done
fi

echo "Arrancando las máquinas..."
VBoxManage startvm "$CP_NAME" --type headless > /dev/null 2>&1 || echo "   $CP_NAME ya estaba encendida."

if [ "$WORKER_COUNT" -gt 0 ]; then
    for i in $(seq 1 $WORKER_COUNT); do
        VBoxManage startvm "${WORKER_BASE_NAME}-${i}" --type headless > /dev/null 2>&1 || echo "   ${WORKER_BASE_NAME}-${i} ya estaba encendido."
    done
fi

# --- 6. INTRODUCIR IPs ---
> cluster-ips.env

read -p "Introduce la IP de $CP_NAME: " CP_IP
echo "CP_IP=\"$CP_IP\"" >> cluster-ips.env

if [ "$WORKER_COUNT" -gt 0 ]; then
    for i in $(seq 1 $WORKER_COUNT); do
        read -p "Introduce la IP de ${WORKER_BASE_NAME}-${i}: " WORKER_IP
        echo "WORKER_IP_${i}=\"$WORKER_IP\"" >> cluster-ips.env
    done
fi

source cluster-ips.env

echo "---------------------------------------------------"
echo "IPs guardadas correctamente en 'cluster-ips.env'."
echo "Fase 1 completada. Máquinas listas para recibir configuración."

# --- 7. GENERAR CONFIGURACIÓN ---
echo "---------------------------------------------------"
echo "Generando archivos de configuración de Talos..."
talosctl gen config "$CLUSTER_NAME" "https://${CP_IP}:6443" --force

# --- 8. APLICAR CONFIGURACIÓN ---
echo "---------------------------------------------------"
echo "Inyectando configuración en el Control Plane ($CP_IP)..."
talosctl apply-config --nodes "$CP_IP" --file controlplane.yaml --insecure

if [ "$WORKER_COUNT" -gt 0 ]; then
    for i in $(seq 1 $WORKER_COUNT); do
        var_name="WORKER_IP_${i}"
        W_IP="${!var_name}"
        
        echo "Inyectando configuración en el Worker ($W_IP)..."
        talosctl apply-config --nodes "$W_IP" --file worker.yaml --insecure
    done
fi

# --- 9. CONFIGURAR CLIENTE LOCAL ---
export TALOSCONFIG=$(pwd)/talosconfig
talosctl config endpoint "$CP_IP"
talosctl config node "$CP_IP"

# --- 10. ESPERA INTELIGENTE Y BOOTSTRAP ---
echo "---------------------------------------------------"
echo -n "Esperando a que el Control Plane se instale, reinicie y responda "

until timeout 3 talosctl kubeconfig . --nodes "$CP_IP" --endpoints "$CP_IP" --force > /dev/null 2>&1; do
    sleep 5
    echo -n "."
done

echo ""
echo "Control Plane activo"
echo "Iniciando el Bootstrap (etcd)..."
talosctl bootstrap

# --- 11. OBTENER KUBECONFIG ---
echo "---------------------------------------------------"
echo -n "Configurando kubeconfig localmente"
# Este bucle intenta descargar el archivo cada 5 segundos hasta que lo logra
until talosctl kubeconfig . --force &> /dev/null; do
    sleep 5
    echo -n "."
done

# --- 12. ESPERAR A QUE EL CLÚSTER ESTÉ READY ---
echo "---------------------------------------------------"
echo -n "Esperando a que la API de Kubernetes responda "
until kubectl get nodes --kubeconfig=./kubeconfig > /dev/null 2>&1; do
    sleep 5
done
echo ""

echo "Esperando a que la red y los DNS arranquen..."
kubectl wait --for=condition=Ready pods --all -n kube-system --timeout=300s --kubeconfig=./kubeconfig

echo "¡Todos los servicios internos están corriendo! El clúster está operativo."

# --- 13. DESPLEGAR Y PROBAR NGINX ---
echo "---------------------------------------------------"
echo "Desplegando aplicación Nginx de prueba..."
kubectl apply -f ../manifests/nginx-demo.yaml --kubeconfig=./kubeconfig

echo "Esperando a que los contenedores de Nginx estén listos..."
kubectl rollout status deployment/nginx-demo --kubeconfig=./kubeconfig

echo "---------------------------------------------------"
echo "Probando la conexión HTTP hacia el Nginx..."
echo "Haciendo petición a http://${CP_IP}:30080"
echo ""

curl -s "http://${CP_IP}:30080" | head -n 15

echo ""
echo "---------------------------------------------------"
echo "AUTOMATIZACIÓN COMPLETADA CON ÉXITO"