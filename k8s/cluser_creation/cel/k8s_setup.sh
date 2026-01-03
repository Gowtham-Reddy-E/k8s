#!/bin/bash

# Kubernetes Cluster Setup Script for CentOS/RHEL
# This script sets up a Kubernetes cluster using kubeadm with containerd

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should not be run as root. Please run as a sudo user."
        exit 1
    fi
}

# Function to disable SELinux and Swap
disable_selinux_swap() {
    print_status "Disabling SELinux and Swap..."
    
    # Disable SELinux
    sudo setenforce 0
    sudo sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
    
    # Disable swap
    sudo swapoff -a
    sudo sed -i '/ swap / s/^/#/' /etc/fstab
    
    print_success "SELinux and Swap disabled"
    
    # Verify
    echo "SELinux status: $(getenforce)"
    echo "Swap status:"
    free -h | grep -i swap
}

# Function to enable kernel modules and sysctl
enable_kernel_modules() {
    print_status "Enabling kernel modules and sysctl settings..."
    
    # Enable br_netfilter module
    cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF
    
    sudo modprobe br_netfilter
    
    # Configure sysctl
    cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF
    
    sudo sysctl --system
    
    print_success "Kernel modules and sysctl configured"
}

# Function to install containerd
install_containerd() {
    print_status "Installing containerd..."
    
    # Install containerd
    sudo yum install -y yum-utils
    sudo yum install -y containerd
    
    # Generate default config
    sudo mkdir -p /etc/containerd
    sudo containerd config default | sudo tee /etc/containerd/config.toml
    
    # Configure containerd for systemd cgroup
    sudo sed -i 's/disabled_plugins = \["cri"\]/disabled_plugins = []/' /etc/containerd/config.toml
    sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
    
    # Start containerd
    sudo systemctl enable containerd
    sudo systemctl start containerd
    
    # Verify
    if sudo systemctl is-active --quiet containerd; then
        print_success "containerd installed and running"
    else
        print_error "containerd installation failed"
        exit 1
    fi
    
    # Verify CRI socket
    if [[ -S /var/run/containerd/containerd.sock ]]; then
        print_success "containerd CRI socket is available"
    else
        print_error "containerd CRI socket not found"
        exit 1
    fi
}

# Function to install Kubernetes components
install_kubernetes() {
    print_status "Installing Kubernetes components..."
    
    # Add Kubernetes repository
    cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.27/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.27/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl
EOF
    
    # Install Kubernetes components
    sudo yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
    
    # Enable kubelet
    sudo systemctl enable kubelet
    
    print_success "Kubernetes components installed"
    
    # Show versions
    echo "Installed versions:"
    kubeadm version
    kubelet --version
    kubectl version --client
}

# Function to initialize master node
init_master() {
    print_status "Initializing Kubernetes master node..."
    
    sudo kubeadm init
    
    if [[ $? -eq 0 ]]; then
        print_success "Master node initialized successfully"
        
        # Configure kubectl
        print_status "Configuring kubectl..."
        mkdir -p $HOME/.kube
        sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
        sudo chown $(id -u):$(id -g) $HOME/.kube/config
        
        print_success "kubectl configured"
        
        # Install CNI plugin
        install_cni
        
        # Show join command
        print_warning "Save the following join command for worker nodes:"
        echo ""
        sudo kubeadm token create --print-join-command
        echo ""
        
    else
        print_error "Master initialization failed"
        exit 1
    fi
}

# Function to install CNI plugin
install_cni() {
    print_status "Installing CNI plugin (Weave Net)..."
    
    kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml
    
    if [[ $? -eq 0 ]]; then
        print_success "CNI plugin installed"
        
        print_status "Waiting for nodes to be ready..."
        sleep 30
        
        kubectl get nodes
        kubectl get pods -A
    else
        print_error "CNI plugin installation failed"
    fi
}

# Function to join worker node
join_worker() {
    if [[ -z "$1" ]]; then
        print_error "Join command not provided"
        echo "Usage: $0 worker <join-command>"
        echo "Example: $0 worker 'kubeadm join 10.126.8.31:6443 --token xxx --discovery-token-ca-cert-hash sha256:xxx'"
        exit 1
    fi
    
    print_status "Joining worker node to cluster..."
    
    sudo $1
    
    if [[ $? -eq 0 ]]; then
        print_success "Worker node joined successfully"
    else
        print_error "Worker node join failed"
        exit 1
    fi
}

# Function to show cluster status
show_status() {
    print_status "Cluster status:"
    kubectl get nodes -o wide
    echo ""
    kubectl get pods -A
}

# Function to show usage
usage() {
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  setup-common    Setup common components (all nodes)"
    echo "  master          Initialize as master node"
    echo "  worker <cmd>    Join as worker node with join command"
    echo "  status          Show cluster status"
    echo "  help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 setup-common                    # Run on all nodes first"
    echo "  $0 master                          # Run on master node"
    echo "  $0 worker 'kubeadm join ...'      # Run on worker nodes"
    echo "  $0 status                          # Check cluster status"
}

# Main script logic
main() {
    check_root
    
    case "${1:-help}" in
        setup-common)
            disable_selinux_swap
            enable_kernel_modules
            install_containerd
            install_kubernetes
            print_success "Common setup completed successfully!"
            print_warning "Reboot recommended before proceeding with master/worker setup"
            ;;
        master)
            init_master
            show_status
            ;;
        worker)
            join_worker "$2"
            ;;
        status)
            show_status
            ;;
        help|*)
            usage
            ;;
    esac
}

# Run main function with all arguments
main "$@"