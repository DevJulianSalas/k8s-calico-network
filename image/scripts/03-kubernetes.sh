#!/usr/bin/env bash
set -euxo pipefail

# shellcheck source=/dev/null
. /tmp/k8s-versions.env

# Configure the Kubernetes package repository for the requested minor version
sed "s/__KUBERNETES_MINOR__/${KUBERNETES_VERSION}/g" \
  /tmp/kubernetes.repo >/etc/yum.repos.d/kubernetes.repo

# Install kubelet and kubeadm
dnf install -y kubelet kubeadm --disableexcludes=kubernetes
systemctl enable kubelet

# Install kubectl (system-wide, so ec2-user and sudo can both use it)
if ! dnf install -y kubectl --disableexcludes=kubernetes; then
  echo "kubectl not available from the package repository; fetching the upstream binary"
fi

if ! command -v kubectl >/dev/null 2>&1; then
  KUBECTL_VERSION="$(kubeadm version -o short)"
  curl -fsSL -o /usr/local/bin/kubectl \
    "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/arm64/kubectl"
  chmod 0755 /usr/local/bin/kubectl
fi

kubectl version --client

# Pre-pull the control plane images into containerd so cluster init needs no internet
kubeadm config images pull --kubernetes-version "$(kubeadm version -o short)"
