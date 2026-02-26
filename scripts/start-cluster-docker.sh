#!/bin/bash

CLUSTER_NAME="talos-docker-demo"
CONFIG_FILE="./kubeconfig"

echo "Checking prerequisites..."

# 1. Check if talosctl is installed
if ! command -v talosctl &> /dev/null; then
    echo "Error: 'talosctl' is not installed."
    echo "Run the installation script first:"
    echo "   ../scripts/install-talosctl.sh"
    exit 1
fi

# 2. Check if Docker is installed
if ! docker info > /dev/null 2>&1; then
    echo "Error: Docker is not installed, you lack permissions, or the daemon is not running."
    echo "Install Docker and make sure it is running before continuing."
    exit 1
fi

echo "Prerequisites met."
echo "---------------------------------------------------"

# 3. Check if the cluster exists to remove it
if docker ps -a --format '{{.Names}}' | grep -q "${CLUSTER_NAME}-controlplane"; then
    echo "The cluster '${CLUSTER_NAME}' already exists in Docker."
    echo "Removing the previous cluster to start fresh..."
    talosctl cluster destroy --name "$CLUSTER_NAME"
    sleep 5
fi

# 4. Create the new cluster
echo "Creating Talos cluster in Docker (2 workers)..."
talosctl cluster create docker \
  --name $CLUSTER_NAME \
  --workers 2 

echo ""
echo "Generating kubeconfig..."
# This generates the 'kubeconfig' file in the current directory (.)
talosctl kubeconfig . --nodes 10.5.0.2 --endpoints 10.5.0.2

echo ""
echo "Cluster deployed."
echo "---------------------------------------------------"
kubectl get nodes --kubeconfig=./kubeconfig

echo ""
echo "---------------------------------------------------"
echo "Deploying test Nginx..."
kubectl --kubeconfig=./kubeconfig apply -f ../manifests/nginx-demo.yaml
kubectl --kubeconfig=./kubeconfig rollout status deployment/nginx-demo

echo ""
echo "---------------------------------------------------"
echo "To verify the Nginx deployment in your browser:"
echo "http://10.5.0.2:30080"

echo ""
echo "Current response:"
curl -s http://10.5.0.2:30080 | head -n 15