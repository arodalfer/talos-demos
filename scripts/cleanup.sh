#!/bin/bash

echo "Limpieza total del entorno Talos..."

# --- 1. LIMPIEZA DE DOCKER ---
echo "1. Limpiando clúster de Docker..."
CLUSTER_DOCKER="talos-docker-demo"

if command -v talosctl &> /dev/null; then
    if talosctl cluster destroy --name "$CLUSTER_DOCKER" > /dev/null 2>&1; then
        echo "Clúster '$CLUSTER_DOCKER' eliminado."
    else
        echo "No se encontró el clúster '$CLUSTER_DOCKER' (o ya estaba borrado)."
    fi
else
    echo "talosctl no instalado. Omitiendo limpieza de Docker."
fi

# --- 2. LIMPIEZA DE VIRTUALBOX ---
echo ""
echo "2. Limpiando máquinas de VirtualBox..."
CONFIG_FILE="cluster.env"

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    
    borrar_vm() {
        local VM_NAME="$1"
        if VBoxManage showvminfo "$VM_NAME" &> /dev/null; then
            echo "   Apagando y eliminando: $VM_NAME..."
            VBoxManage controlvm "$VM_NAME" poweroff > /dev/null 2>&1
            sleep 2
            VBoxManage unregistervm "$VM_NAME" --delete > /dev/null 2>&1
            echo "$VM_NAME eliminada."
        fi
    }

    # Borrar Control Plane
    borrar_vm "$CP_NAME"
    
    # Borrar Workers
    if [ "$WORKER_COUNT" -gt 0 ]; then
        for i in $(seq 1 $WORKER_COUNT); do
            borrar_vm "${WORKER_BASE_NAME}-${i}"
        done
    fi
else
    echo "No se encontró '$CONFIG_FILE'. Omitiendo limpieza de VirtualBox."
fi

# --- 3. LIMPIEZA DE ARCHIVOS LOCALES ---
echo ""
echo "3. Limpiando archivos de configuración locales..."
rm -f kubeconfig talosconfig cluster-ips.env controlplane.yaml worker.yaml

# Preguntar si se quiere borrar la ISO para liberar 1.2GB de espacio
if ls *.iso 1> /dev/null 2>&1; then
    echo ""
    read -p "¿Quieres borrar la ISO descargada? (s/N): " BORRAR_ISO
    if [[ "$BORRAR_ISO" == "s" || "$BORRAR_ISO" == "S" ]]; then
        rm -f *.iso
        echo "ISO eliminada."
    else
        echo "ISO conservada para futuros despliegues."
    fi
fi

echo "Entorno completamente limpio"