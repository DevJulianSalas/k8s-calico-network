#!/usr/bin/env bash
set -euxo pipefail

# Clean package caches to shrink the image
dnf clean all
rm -rf /var/cache/dnf /var/tmp/* /tmp/*

# Reset machine identity so every instance gets a unique one
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id

# Remove SSH host keys; they are regenerated on first boot
rm -f /etc/ssh/ssh_host_*

# Reset cloud-init so it re-runs provisioning on first boot
cloud-init clean --logs --seed || true

# Truncate logs
find /var/log -type f -exec truncate -s 0 {} \;

sync
