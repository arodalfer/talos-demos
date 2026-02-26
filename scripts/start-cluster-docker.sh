#!/bin/bash

CLUSTER_NAME="talos-docker-demo"
CONFIG_FILE="./kubeconfig"

echo "Verificando requisitos..."

# 1. Comprobar si talosctl está instalado
if ! command -v talosctl &> /dev/null; then
    echo "Error: 'talosctl' no está instalado."
    echo "Ejecuta primero el script de instalación:"
    echo "   ../scripts/install-talosctl.sh"
    exit 1
fi

# 2. Comprobar si Docker está instalado
if ! docker info > /dev/null 2>&1; then
    echo "Error: Docker no está instalado, no tienes permisos o el daemon no está corriendo."
    echo "Instala Docker y asegúrate de que esté iniciado antes de continuar."
    exit 1
fi

echo "Requisitos cumplidos."
echo "---------------------------------------------------"

# 3. Comprobar si el clúster existe para eliminarlo
if docker ps -a --format '{{.Names}}' | grep -q "${CLUSTER_NAME}-controlplane"; then
    echo "El clúster '${CLUSTER_NAME}' ya existe en Docker."
    echo "Eliminando el clúster anterior para empezar en limpio..."
    talosctl cluster destroy --name "$CLUSTER_NAME"
    sleep 5
fi

# 4. Crear el nuevo clúster
echo "Creando clúster Talos en Docker (2 workers)..."
talosctl cluster create docker \
  --name $CLUSTER_NAME \
  --workers 2 

echo ""
echo "Generando kubeconfig..."
# Esto genera el archivo 'kubeconfig' en el directorio actual (.)
talosctl kubeconfig . --nodes 10.5.0.2 --endpoints 10.5.0.2

echo ""
echo "Clúster desplegado."
echo "---------------------------------------------------"
kubectl get nodes --kubeconfig=./kubeconfig

echo ""
echo "---------------------------------------------------"
echo "Desplegando Nginx de prueba..."
kubectl --kubeconfig=./kubeconfig apply -f ../manifests/nginx-demo.yaml
kubectl --kubeconfig=./kubeconfig rollout status deployment/nginx-demo

echo ""
echo "---------------------------------------------------"
echo "Para verificar el despliegue de Nginx en tu navegador:"
echo "http://10.5.0.2:30080"

echo ""
echo "Respuesta actual:"
curl -s http://10.5.0.2:30080 | head -n 15