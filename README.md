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

**Depending on the environment you choose:**
* For the Docker script: **Docker Desktop** or **Docker Engine** running.
* For the VirtualBox script: **VirtualBox** installed and the command line tools (`VBoxManage`) accessible in your PATH.