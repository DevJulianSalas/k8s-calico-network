#!/usr/bin/env bash
set -euxo pipefail

# Disable swap (required by kubelet)
swapoff -a
sed -i.bak '/[[:space:]]swap[[:space:]]/ s/^/#/' /etc/fstab

# Kernel modules required by Kubernetes networking
cat >/etc/modules-load.d/k8s.conf <<'EOF'
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

# sysctl settings for bridged traffic and IP forwarding
cat >/etc/sysctl.d/99-kubernetes.conf <<'EOF'
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system

# Base packages required by kubeadm and the container runtime
dnf install -y conntrack-tools socat iproute-tc iptables
