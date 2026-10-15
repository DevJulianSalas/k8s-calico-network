#!/usr/bin/env bash
set -euxo pipefail

# Install containerd and configure the systemd cgroup driver
dnf install -y containerd

mkdir -p /etc/containerd
containerd config default >/etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

systemctl enable containerd
systemctl restart containerd
