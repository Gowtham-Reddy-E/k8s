#!/bin/bash

# Kubernetes Cluster Teardown Script for CentOS/RHEL
# This script removes Kubernetes, containerd, and cleans up the system

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

# Function to confirm action
confirm_action() {
    print_warning "This will completely remove Kubernetes and containerd from this system!"
    print_warning "All cluster data, containers, and configurations will be lost."
    echo ""
    read -p "Are you sure you want to continue? (yes/no): " choice
    case "$choice" in
        yes|YES|y|Y)
            return 0
            ;;
        *)
            print_status "Operation cancelled."
            exit 0
            ;;
    esac
}

# Function to reset kubeadm
reset_kubeadm() {
    print_status "Resetting kubeadm cluster..."
    
    # Reset kubeadm
    sudo kubeadm reset -f
    
    print_success "kubeadm reset completed"
}

# Function to remove Kubernetes directories
remove_k8s_directories() {
    print_status "Removing Kubernetes directories..."
    
    # Remove Kubernetes directories
    sudo rm -rf /etc/kubernetes /var/lib/etcd /var/lib/kubelet /var/lib/cni /etc/cni/net.d
    
    print_success "Kubernetes directories removed"
}

# Function to remove kubeconfig files
remove_kubeconfig() {
    print_status "Removing kubeconfig files..."
    
    # Remove user kubeconfig
    rm -rf $HOME/.kube
    
    # Remove root kubeconfig
    sudo rm -rf /root/.kube
    
    print_success "kubeconfig files removed"
}

# Function to stop and disable kubelet
stop_kubelet() {
    print_status "Stopping and disabling kubelet..."
    
    # Stop and disable kubelet
    sudo systemctl stop kubelet 2>/dev/null || true
    sudo systemctl disable kubelet 2>/dev/null || true
    sudo systemctl daemon-reload
    
    print_success "kubelet stopped and disabled"
}

# Function to remove Kubernetes packages
remove_k8s_packages() {
    print_status "Removing Kubernetes packages..."
    
    # Remove Kubernetes packages
    sudo yum remove -y kubeadm kubelet kubectl kubernetes-cni 2>/dev/null || true
    sudo yum clean all
    sudo rm -rf /var/cache/yum
    sudo rm -f /etc/yum.repos.d/kubernetes.repo
    
    print_success "Kubernetes packages removed"
}

# Function to stop and remove containerd
remove_containerd() {
    print_status "Stopping and removing containerd..."
    
    # Stop and disable containerd
    sudo systemctl stop containerd 2>/dev/null || true
    sudo systemctl disable containerd 2>/dev/null || true
    
    # Remove containerd directories
    sudo rm -rf /etc/containerd /var/lib/containerd /var/run/containerd
    
    # Ask if user wants to remove containerd package
    read -p "Do you want to remove the containerd package? (y/n): " remove_pkg
    case "$remove_pkg" in
        y|Y|yes|YES)
            sudo yum remove -y containerd 2>/dev/null || true
            print_success "containerd package removed"
            ;;
        *)
            print_status "containerd package kept (only stopped and cleaned)"
            ;;
    esac
    
    print_success "containerd stopped and cleaned"
}

# Function to remove Docker (optional)
remove_docker() {
    # Check if Docker is installed
    if systemctl is-enabled docker 2>/dev/null || systemctl is-active docker 2>/dev/null; then
        read -p "Docker detected. Do you want to remove it? (y/n): " remove_docker
        case "$remove_docker" in
            y|Y|yes|YES)
                print_status "Stopping and removing Docker..."
                
                sudo systemctl stop docker 2>/dev/null || true
                sudo systemctl disable docker 2>/dev/null || true
                sudo rm -rf /var/lib/docker /var/run/docker
                sudo yum remove -y docker-ce docker-ce-cli docker-ce-rootless-extras docker-buildx-plugin docker-compose-plugin 2>/dev/null || true
                
                print_success "Docker removed"
                ;;
            *)
                print_status "Docker kept"
                ;;
        esac
    else
        print_status "Docker not found, skipping"
    fi
}

# Function to cleanup iptables and bridge networks
cleanup_networking() {
    print_status "Cleaning up iptables and bridge networks..."
    
    # Flush iptables
    sudo iptables -F 2>/dev/null || true
    sudo iptables -X 2>/dev/null || true
    sudo iptables -t nat -F 2>/dev/null || true
    sudo iptables -t nat -X 2>/dev/null || true
    sudo iptables -t mangle -F 2>/dev/null || true
    sudo iptables -t mangle -X 2>/dev/null || true
    sudo iptables -t raw -F 2>/dev/null || true
    sudo iptables -t raw -X 2>/dev/null || true
    
    # Remove leftover bridges
    sudo ip link delete cni0 2>/dev/null || true
    sudo ip link delete flannel.1 2>/dev/null || true
    sudo ip link delete weave 2>/dev/null || true
    sudo ip link delete docker0 2>/dev/null || true
    
    print_success "Networking cleanup completed"
}

# Function to restore swap
restore_swap() {
    read -p "Do you want to restore swap? (y/n): " restore_swap
    case "$restore_swap" in
        y|Y|yes|YES)
            print_status "Restoring swap..."
            
            sudo sed -i '/ swap / s/^#//' /etc/fstab
            sudo swapon -a
            
            print_success "Swap restored"
            echo "Current swap status:"
            free -h | grep -i swap
            ;;
        *)
            print_status "Swap not restored"
            ;;
    esac
}

# Function to restore SELinux
restore_selinux() {
    read -p "Do you want to restore SELinux to enforcing mode? (y/n): " restore_sel
    case "$restore_sel" in
        y|Y|yes|YES)
            print_status "Restoring SELinux..."
            
            sudo setenforce 1 2>/dev/null || true
            sudo sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
            
            print_success "SELinux restored to enforcing mode"
            echo "Current SELinux status: $(getenforce)"
            print_warning "Reboot required for SELinux changes to take full effect"
            ;;
        *)
            print_status "SELinux not restored"
            ;;
    esac
}

# Function to cleanup kernel modules
cleanup_kernel_modules() {
    print_status "Cleaning up kernel modules configuration..."
    
    sudo rm -f /etc/modules-load.d/k8s.conf
    sudo rm -f /etc/sysctl.d/k8s.conf
    
    print_success "Kernel modules configuration cleaned"
}

# Function to show system status
show_final_status() {
    print_status "Final system status:"
    echo ""
    
    echo "SELinux status: $(getenforce)"
    echo "Swap status:"
    free -h | grep -i swap
    echo ""
    
    # Check if any Kubernetes processes are still running
    if pgrep -f "kube|containerd|docker" >/dev/null 2>&1; then
        print_warning "Some Kubernetes/container processes may still be running:"
        pgrep -f "kube|containerd|docker" | xargs ps -p 2>/dev/null || true
    else
        print_success "No Kubernetes/container processes found"
    fi
    
    echo ""
    print_success "Kubernetes cluster teardown completed!"
    print_warning "Consider rebooting the system for a clean state"
}

# Function to show usage
usage() {
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  full            Complete teardown (recommended)"
    echo "  quick           Quick reset (keeps packages)"
    echo "  reset-only      Only reset kubeadm (minimal)"
    echo "  help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 full         # Complete removal of Kubernetes and containerd"
    echo "  $0 quick        # Reset cluster but keep packages for reinstall"
    echo "  $0 reset-only   # Only reset kubeadm cluster"
}

# Function for full teardown
full_teardown() {
    confirm_action
    
    reset_kubeadm
    remove_k8s_directories
    remove_kubeconfig
    stop_kubelet
    remove_k8s_packages
    remove_containerd
    remove_docker
    cleanup_networking
    cleanup_kernel_modules
    restore_swap
    restore_selinux
    
    show_final_status
}

# Function for quick reset
quick_reset() {
    confirm_action
    
    reset_kubeadm
    remove_k8s_directories
    remove_kubeconfig
    stop_kubelet
    cleanup_networking
    
    print_success "Quick reset completed!"
    print_status "Packages kept for potential reinstall"
}

# Function for reset only
reset_only() {
    print_warning "This will only reset the kubeadm cluster"
    read -p "Continue? (y/n): " choice
    case "$choice" in
        y|Y|yes|YES)
            reset_kubeadm
            remove_k8s_directories
            remove_kubeconfig
            print_success "kubeadm reset completed!"
            ;;
        *)
            print_status "Operation cancelled"
            ;;
    esac
}

# Main script logic
main() {
    check_root
    
    case "${1:-help}" in
        full)
            full_teardown
            ;;
        quick)
            quick_reset
            ;;
        reset-only)
            reset_only
            ;;
        help|*)
            usage
            ;;
    esac
}

# Run main function with all arguments
main "$@"