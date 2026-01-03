# Kubernetes Cluster Setup & Teardown for CentOS/RHEL

This repository contains automated scripts and documentation for setting up and tearing down Kubernetes clusters on CentOS/Rocky Linux/AlmaLinux using kubeadm and containerd.

## 📁 Repository Contents

| File | Description |
|------|-------------|
| `cel_machine_cluster_setup.md` | Detailed manual setup documentation |
| `remove_master_slaves_k8s_setup.md` | Manual teardown documentation |
| `k8s_setup.sh` | **Automated setup script** |
| `k8s_teardown.sh` | **Automated teardown script** |
| `README.md` | This guide |

## 🎯 Quick Start

### For Impatient Users:
```bash
# 1. Setup all nodes
./k8s_setup.sh setup-common && sudo reboot

# 2. After reboot, setup master
./k8s_setup.sh master

# 3. On worker nodes (use join command from master output)
./k8s_setup.sh worker 'kubeadm join MASTER_IP:6443 --token TOKEN --discovery-token-ca-cert-hash sha256:HASH'
```

## 📋 Prerequisites

### System Requirements
- **OS**: CentOS 7/8, Rocky Linux 8/9, or AlmaLinux 8/9
- **Architecture**: x86_64
- **RAM**: Minimum 2GB (Master: 4GB recommended)
- **CPU**: Minimum 2 cores
- **Disk**: Minimum 20GB free space

### Network Requirements
- All nodes must have unique hostnames
- All nodes must have unique MAC addresses
- All nodes must be able to communicate with each other
- Internet access for downloading packages
- Ports 6443, 2379-2380, 10250, 10259, 10257 (Master)
- Ports 10250, 30000-32767 (Workers)

### Access Requirements
- **sudo** access on all nodes
- **NOT** running as root user (scripts will check and prevent this)

## 🚀 Setup Process

### Step 1: Common Setup (All Nodes)

Run this on **ALL** nodes (master + workers):

```bash
# Download and make executable
chmod +x k8s_setup.sh

# Run common setup
./k8s_setup.sh setup-common
```

**What this does:**
- ✅ Disables SELinux and swap
- ✅ Configures kernel modules and sysctl
- ✅ Installs and configures containerd
- ✅ Installs kubeadm, kubelet, kubectl
- ✅ Adds Kubernetes repository

**⚠️ IMPORTANT**: Reboot all nodes after this step:
```bash
sudo reboot
```

### Step 2: Initialize Master Node

Run this on the **MASTER** node only:

```bash
./k8s_setup.sh master
```

**What this does:**
- ✅ Initializes Kubernetes control plane
- ✅ Configures kubectl for current user
- ✅ Installs Weave CNI plugin
- ✅ Displays join command for workers

**Expected Output:**
```
[SUCCESS] Master node initialized successfully
[INFO] Installing CNI plugin (Weave Net)...
[WARNING] Save the following join command for worker nodes:

kubeadm join 10.126.8.31:6443 --token dr4oth.zfcxykuzx3x7xg87 --discovery-token-ca-cert-hash sha256:8aecf7622a6706c8125c08c323a37356eaa8d533844370af50f5288fd48a0b45
```

**🔥 COPY THE JOIN COMMAND** - you'll need it for workers!

### Step 3: Join Worker Nodes

Run this on each **WORKER** node:

```bash
./k8s_setup.sh worker 'PASTE_JOIN_COMMAND_HERE'
```

**Example:**
```bash
./k8s_setup.sh worker 'kubeadm join 10.126.8.31:6443 --token dr4oth.zfcxykuzx3x7xg87 --discovery-token-ca-cert-hash sha256:8aecf7622a6706c8125c08c323a37356eaa8d533844370af50f5288fd48a0b45'
```

### Step 4: Verify Cluster

From the **master** node:

```bash
# Check cluster status
./k8s_setup.sh status

# Or manually:
kubectl get nodes -o wide
kubectl get pods -A
```

**Expected healthy output:**
```
NAME      STATUS   ROLES           AGE   VERSION
master    Ready    control-plane   5m    v1.27.x
worker1   Ready    <none>          3m    v1.27.x
worker2   Ready    <none>          2m    v1.27.x
```

## 🧹 Teardown Process

The teardown script provides three levels of cleanup:

### Option 1: Complete Removal (Recommended)
```bash
./k8s_teardown.sh full
```
- ✅ Removes everything (cluster, packages, configs)
- ✅ Optionally restores swap and SELinux
- ✅ Cleans networking and iptables
- ⚠️ **DESTRUCTIVE** - asks for confirmation

### Option 2: Quick Reset
```bash
./k8s_teardown.sh quick
```
- ✅ Resets cluster but keeps packages
- ✅ Good for quick reinstallation
- ⚠️ Less destructive than full removal

### Option 3: Minimal Reset
```bash
./k8s_teardown.sh reset-only
```
- ✅ Only runs `kubeadm reset`
- ✅ Minimal cleanup
- ✅ Good for troubleshooting

## 📖 Detailed Documentation

For manual step-by-step instructions, refer to:
- [cel_machine_cluster_setup.md](cel_machine_cluster_setup.md) - Complete setup guide
- [remove_master_slaves_k8s_setup.md](remove_master_slaves_k8s_setup.md) - Complete teardown guide

## 🛠️ Script Usage

### Setup Script (`k8s_setup.sh`)

```bash
Usage: ./k8s_setup.sh [OPTION]

Options:
  setup-common    Setup common components (all nodes)
  master          Initialize as master node
  worker <cmd>    Join as worker node with join command
  status          Show cluster status
  help            Show help message

Examples:
  ./k8s_setup.sh setup-common                    # Run on all nodes first
  ./k8s_setup.sh master                          # Run on master node
  ./k8s_setup.sh worker 'kubeadm join ...'      # Run on worker nodes
  ./k8s_setup.sh status                          # Check cluster status
```

### Teardown Script (`k8s_teardown.sh`)

```bash
Usage: ./k8s_teardown.sh [OPTION]

Options:
  full            Complete teardown (recommended)
  quick           Quick reset (keeps packages)
  reset-only      Only reset kubeadm (minimal)
  help            Show help message

Examples:
  ./k8s_teardown.sh full         # Complete removal
  ./k8s_teardown.sh quick        # Reset for reinstall
  ./k8s_teardown.sh reset-only   # Minimal reset
```

## 🔧 Troubleshooting

### Common Issues & Solutions

#### 1. "kubeadm init" fails
```bash
# Check prerequisites
./k8s_setup.sh setup-common
sudo reboot
```

#### 2. Worker can't join cluster
```bash
# Reset worker and try again
./k8s_teardown.sh reset-only
./k8s_setup.sh worker 'JOIN_COMMAND'
```

#### 3. Pods stuck in "ContainerCreating"
```bash
# Check CNI
kubectl get pods -A
kubectl describe pod POD_NAME -n NAMESPACE

# Reinstall CNI if needed
kubectl delete -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml
kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml
```

#### 4. Join token expired
```bash
# Generate new token on master
sudo kubeadm token create --print-join-command
```

#### 5. containerd not working
```bash
# Restart containerd
sudo systemctl restart containerd
sudo systemctl status containerd

# Check socket
ls -l /var/run/containerd/containerd.sock
```

### Log Locations
- **kubelet**: `journalctl -u kubelet -f`
- **containerd**: `journalctl -u containerd -f`
- **kubeadm**: `/var/log/kubeadm.log`

## 💡 Pro Tips

### 1. Save Join Command
After master initialization, save the join command:
```bash
# On master, generate new join command anytime
sudo kubeadm token create --print-join-command
```

### 2. Quick Health Check
```bash
# One-liner cluster health
kubectl get nodes,pods -A --no-headers | grep -E "(NotReady|Error|CrashLoop|Pending)"
```

### 3. Reset Single Worker
```bash
# On worker node
./k8s_teardown.sh reset-only
./k8s_setup.sh worker 'NEW_JOIN_COMMAND'
```

### 4. Backup Master Config
```bash
# Backup important configs
sudo cp -r /etc/kubernetes /root/k8s-backup-$(date +%Y%m%d)
```

## 🚨 Safety Features

Both scripts include safety features:
- ✅ **Root prevention**: Won't run as root user
- ✅ **Confirmation prompts**: Ask before destructive operations
- ✅ **Error checking**: Validate each step
- ✅ **Colored output**: Easy to read status messages
- ✅ **Rollback support**: Multiple teardown levels

## 🎉 Success Indicators

Your cluster is ready when you see:
- All nodes show `Ready` status
- All system pods are `Running`
- You can deploy test workloads successfully

Test with a simple pod:
```bash
kubectl run test-pod --image=nginx --port=80
kubectl get pods
kubectl delete pod test-pod
```

## 📞 Support

For issues:
1. Check the troubleshooting section above
2. Review the detailed markdown documentation
3. Check system logs with `journalctl`
4. Ensure all prerequisites are met

---

**Happy Kubernetesing! 🎊**