---

# Kubernetes Cluster Creation on CentOS

---
* VM creation
* User setup
* SELinux & swap
* Kernel + sysctl
* **Docker (optional but installed)**
* **containerd (actual Kubernetes runtime)**
* **Kubernetes repos (NEW official pkgs.k8s.io)**
* kubeadm / kubelet / kubectl
* Master init
* Worker join
* **CNI options (choose one)**
* Validation
* Cleanup
* Clear explanations (KT-friendly)

You can drop this **as-is** into a `.md` file.

---

# Kubernetes Cluster Setup on CentOS using kubeadm

(**Docker + containerd + Kubernetes v1.27.x**)

This document provides **end-to-end steps** to set up a **Kubernetes cluster** on **CentOS / Rocky / Alma Linux** using **kubeadm**, with:

* **containerd** as the Kubernetes container runtime
* **Docker installed optionally** for image build/debugging
* Kubernetes version **v1.27.x**

---

## Architecture

* 1 × Control Plane (Master)
* 2 × Worker Nodes
* Container Runtime: **containerd**
* Container CLI (optional): **Docker**
* CNI: **Choose ONE (Calico or Weave)**

---

## Prerequisites

* OS: **CentOS 7 / Rocky / Alma**
* User with **sudo access**
* Internet access
* Swap disabled
* SELinux disabled

---

## Create VMs (Example: GCP)

```bash
gcloud compute instances create master worker-1 worker-2 \
  --zone us-central1-a \
  --machine-type e2-medium \
  --image-family centos-7 \
  --image-project centos-cloud
```

---

## Create User (Master & Worker)

```bash
adduser siva
passwd siva
usermod -aG wheel siva
su - siva
```

Enable SSH password authentication:

```bash
sudo vi /etc/ssh/sshd_config
```

Set:

```ini
PasswordAuthentication yes
```

Restart SSH:

```bash
sudo systemctl restart sshd
```

---

## Disable SELinux & Swap (MANDATORY)

### Why?

* kubelet **fails scheduling** when swap is enabled
* SELinux blocks container networking & volumes

```bash
# Disable SELinux immediately
sudo setenforce 0

# Disable SELinux permanently
sudo sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config

# Disable swap
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab
```

Verify:

```bash
getenforce
free -h
```

---

## Enable Kernel Modules & Sysctl (Master & Worker)

Required for **pod networking & forwarding**

```bash
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

sudo modprobe br_netfilter
```

```bash
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF
```

Apply:

```bash
sudo sysctl --system
```

---

## Install Docker (OPTIONAL – Utility Only)

**(Master & Worker)**

> Docker is installed only for:
>
> * `docker build`
> * image inspection
> * troubleshooting
>
> Kubernetes **DOES NOT use Docker as runtime**.

```bash
sudo yum install -y yum-utils

sudo yum-config-manager \
  --add-repo \
  https://download.docker.com/linux/centos/docker-ce.repo

sudo yum install -y docker-ce docker-ce-cli
```

Start Docker:

```bash
sudo systemctl enable docker
sudo systemctl start docker
```

Optional:

```bash
sudo usermod -aG docker siva
```

⚠️ Do NOT configure kubelet to use Docker
⚠️ Do NOT install `cri-dockerd`

---

## Install containerd (MANDATORY – Kubernetes Runtime)

**(Master & Worker)**

```bash
sudo yum install -y containerd
```

Generate default config:

```bash
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
```

Edit config:

```bash
sudo vi /etc/containerd/config.toml
```

### REQUIRED CHANGE (Very Important)

```toml
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
SystemdCgroup = true
```

⚠️ Do NOT modify `disabled_plugins`

Restart containerd:

```bash
sudo systemctl restart containerd
sudo systemctl enable containerd
```

Verify CRI socket:

```bash
ls -l /var/run/containerd/containerd.sock
```

---

## Install Kubernetes Components (Master & Worker)

### Add Kubernetes Repository (NEW Official Repo)

```bash
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.27/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.27/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl
EOF
```

### Install kubeadm, kubelet, kubectl

```bash
sudo yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
```

Enable kubelet:

```bash
sudo systemctl enable kubelet
```

---

## Initialize Kubernetes Cluster (MASTER ONLY)

```bash
sudo kubeadm init
```

On success, output will include:

* kubeconfig steps
* `kubeadm join` command

---

## Configure kubectl (MASTER ONLY)

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

Verify:

```bash
kubectl get nodes
```

(Control plane will be **NotReady** until CNI is installed)

---

## Join Worker Nodes (WORKER ONLY)

Run the join command printed by master:

```bash
sudo kubeadm join <MASTER_IP>:6443 \
  --token <TOKEN> \
  --discovery-token-ca-cert-hash sha256:<HASH>
```

---

## Install CNI Plugin (MASTER ONLY)

> **Install ONLY ONE CNI**

### Option 1: Calico (Recommended)

```bash
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml
```

### Option 2: Weave (Simple / Legacy)

```bash
kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml
```

---

## Verify Cluster

```bash
kubectl get nodes
kubectl get pods -A
```

All nodes should be **Ready**.

---

## Validation Commands

```bash
kubeadm version
kubelet --version
kubectl version --client
```

---

## Cleanup (If Needed)

```bash
sudo kubeadm reset -f
sudo rm -rf /etc/kubernetes /var/lib/etcd
sudo rm -rf /etc/cni/net.d
```

---

## Final Notes

* Kubernetes uses **containerd as container runtime**
* Docker is optional and **NOT used by kubelet**
* Swap must be disabled
* SELinux must be disabled
* Install ONLY ONE CNI
* Do NOT use `--ignore-preflight-errors=CRI`
* This setup matches Kubernetes **best practices**

---

✅ **This is a complete, KT-ready, production-clean Kubernetes setup guide**

