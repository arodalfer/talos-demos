# Talos Linux Local Deployment Scripts

This repository contains a set of Bash scripts to automate the deployment of **Talos Linux** clusters (an immutable operating system designed for Kubernetes) in local environments using **Docker** or **VirtualBox**.

It also includes the automatic deployment of a test Nginx application to verify that routing and clustering are working correctly.

## Repository Structure

* `manifests/nginx-demo.yaml`: Kubernetes manifest that includes a ConfigMap (custom web page), an Nginx Deployment, and a Service (NodePort) to expose the web.
* `scripts/install-talosctl.sh`: Script to automatically install the `talosctl` command line tool (supports macOS and Linux).
* `scripts/start-cluster-docker.sh`: Deploys a fast and lightweight Talos cluster using Docker containers.
* `scripts/start-cluster-vbox.sh`: Deploys a virtualised cluster by creating machines in VirtualBox.

---

## Prerequisites

Before running the scripts, ensure you have the following tools installed on your local system:

1. **[kubectl](https://kubernetes.io/docs/tasks/tools/)**: To interact with the Kubernetes API.
2. **curl**: To download the Talos ISO and perform connection tests.
3. **Kernel module `br_netfilter` (Linux only)**: Essential for Kubernetes CNI (Container Network Interface) to correctly route bridged network traffic. Ensure you load it on your host machine by running:
```bash
   sudo modprobe br_netfilter
```

**Depending on the environment you choose:**
* For the Docker script: **Docker Desktop** or **Docker Engine** running.
* For the VirtualBox script: **VirtualBox** installed and the command line tools (`VBoxManage`) accessible in your PATH.

## Installing Talos (Required)
IMPORTANT: Before attempting to launch the Docker or VirtualBox demo, it is strictly necessary to install the Talos command line tool (talosctl). Without it, the cluster creation scripts will fail.

Clone this repository, give the scripts execution permissions, and launch the automatic installer:
```bash
   git clone <URL_REPOSITORIO>
   chmod +x scripts/*.sh
   ./scripts/install-talosctl.sh
```

## Option A: Deployment with Docker 
This is the fastest and lightest way to try Talos. It uses Docker containers on your local machine to simulate the cluster nodes. You don't have to configure anything at all. Just run the script and in a couple of minutes you'll have the cluster up and running and Nginx deployed:
```bash
   ./scripts/start-cluster-docker.sh
```
## Option B: Deployment with VirtualBox 
This demo is more advanced and simulates a real environment by creating virtual machines that connect directly to your local network. Before running the script, you must configure the cluster.env file located in the scripts/ folder. This file controls how your machines will be created:
```bash
   # === cluster.env ===

   # Talos version
   TALOS_VERSION="v1.12.0"

   # Physical network interface for VirtualBox machines
   BRIDGE_IF="xxxxx"

   # Machine names
   CP_NAME="talos-master"
   WORKER_BASE_NAME="talos-worker"

   # Number of workers
   WORKER_COUNT=1
```
```bash
   cd scripts
   ./scripts/start-cluster-vbox.sh
```
## Clean up

To avoid consuming resources on your machine when you finish testing, we have included a script that automatically destroys everything: Docker clusters, VirtualBox machines, and residual configuration files.

Simply run:
```bash
   cd scripts
   ./scripts/cleanup.sh
```

