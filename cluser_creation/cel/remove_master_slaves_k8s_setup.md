
---

# Kubernetes Cluster Teardown on CentOS

This document provides **step-by-step instructions** to remove **Kubernetes**, **containerd**, **Docker (optional)**, and **networking configs** from all nodes (Master & Worker).

---

## 1. Reset kubeadm (All Nodes)

```bash
# Reset kubeadm cluster
sudo kubeadm reset -f
```

This will:

* Stop kubelet
* Remove etcd data
* Remove control plane manifests
* Remove certificates

> ⚠️ Note: This does **not clean CNI configs**, iptables, or kubeconfig files.

---

## 2. Remove Kubernetes Directories

```bash
sudo rm -rf /etc/kubernetes /var/lib/etcd /var/lib/kubelet /var/lib/cni /etc/cni/net.d
```

---

## 3. Remove kubeconfig Files

```bash
rm -rf $HOME/.kube
sudo rm -rf /root/.kube
```

---

## 4. Stop & Disable kubelet

```bash
sudo systemctl stop kubelet
sudo systemctl disable kubelet
sudo systemctl daemon-reload
```

---

## 5. Remove Kubernetes Packages

```bash
sudo yum remove -y kubeadm kubelet kubectl kubernetes-cni
sudo yum clean all
sudo rm -rf /var/cache/yum
sudo rm -f /etc/yum.repos.d/kubernetes.repo
```

---

## 6. Stop & Remove containerd

```bash
sudo systemctl stop containerd
sudo systemctl disable containerd
sudo rm -rf /etc/containerd /var/lib/containerd /var/run/containerd
```

Optional: remove the package completely:

```bash
sudo yum remove -y containerd
```

---

## 7. (Optional) Stop & Remove Docker

If Docker was installed:

```bash
sudo systemctl stop docker
sudo systemctl disable docker
sudo rm -rf /var/lib/docker /var/run/docker
sudo yum remove -y docker-ce docker-ce-cli
```

---

## 8. Cleanup iptables & bridge networks

```bash
sudo iptables -F
sudo iptables -X
sudo iptables -t nat -F
sudo iptables -t nat -X
sudo iptables -t mangle -F
sudo iptables -t mangle -X
sudo iptables -t raw -F
sudo iptables -t raw -X

# Remove leftover bridges
sudo ip link delete cni0
sudo ip link delete flannel.1
sudo ip link delete docker0
```

---

## 9. Restore Swap (Optional)

```bash
sudo sed -i '/ swap / s/^#//' /etc/fstab
sudo swapon -a
```

---

## 10. Restore SELinux (Optional)

```bash
sudo setenforce 1
sudo sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
```

---

## ✅ Final Notes

After performing all these steps:

* All Kubernetes cluster data is removed
* containerd is uninstalled (or cleaned)
* Docker (if installed) is removed
* Networking / iptables cleaned
* Node is ready for a **fresh Kubernetes installation**

---

