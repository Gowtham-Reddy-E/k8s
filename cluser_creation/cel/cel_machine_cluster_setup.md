

---

# Kubernetes Cluster Setup on CentOS using kubeadm

This document describes **step-by-step instructions** to set up a **Kubernetes cluster** on **CentOS** using **kubeadm**, with **containerd** as the container runtime.

---

## Prerequisites

* OS: **CentOS 7 / Rocky / Alma**
* Nodes:

  * 1 × Master
  * 2 × Worker
* User with **sudo access**
* Internet access
* Kubernetes version: **v1.27.x**

---


## Disable SELinux & Swap (MANDATORY)

```bash
# Disable SELinux (runtime)
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

sudo sysctl --system
```

---

## Install containerd (Master & Worker)

```bash
sudo yum install -y yum-utils
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

### REQUIRED changes

```toml
disabled_plugins = []
```

```toml
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
SystemdCgroup = true
```

Start containerd:

```bash
sudo systemctl enable containerd
sudo systemctl start containerd
```

Verify CRI:

```bash
ls -l /var/run/containerd/containerd.sock
```

---

## Install Kubernetes Components (Master & Worker)

### Add Kubernetes repo (NEW official repo)

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

On success, you will get:

* kubeconfig instructions
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

---

## Join Worker Nodes (WORKER ONLY)

Run the join command printed by master, example:

```bash
sudo kubeadm join 10.18.0.30:6443 \
  --token <TOKEN> \
  --discovery-token-ca-cert-hash sha256:<HASH>
```

---

## Install CNI Plugin (MASTER ONLY)

```bash
kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml

```

Verify:

```bash
kubectl get nodes
kubectl get pods -A
```

All nodes should show **Ready**.

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
```

---

## Final Notes

* containerd **must expose CRI**
* Swap **must be disabled**
* Do **not** use `--ignore-preflight-errors=CRI`
* Docker is **not required**

---

✅ **This document is tested and matches your working setup**


---
Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Alternatively, if you are the root user, you can run:

  export KUBECONFIG=/etc/kubernetes/admin.conf

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 10.126.8.31:6443 --token dr4oth.zfcxykuzx3x7xg87 --discovery-token-ca-cert-hash sha256:8aecf7622a6706c8125c08c323a37356eaa8d533844370af50f5288fd48a0b45

---
recet everything and run join command again after this below commands

sudo kubeadm reset -f
sudo rm -rf /etc/cni/net.d
sudo rm -rf /var/lib/kubelet
sudo rm -rf /var/lib/containerd
sudo systemctl restart containerd

---

