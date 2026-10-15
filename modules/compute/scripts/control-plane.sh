#!/bin/bash
set -euo pipefail

exec > >(tee -a /var/log/k8s-bootstrap.log) 2>&1
echo "=== bootstrapping control plane ==="

# Ensure the container runtime is running
systemctl enable --now containerd

# Initialize the control plane
kubeadm init --pod-network-cidr="${POD_NETWORK_CIDR}" --upload-certs

# Expose kubeconfig to the default login user
mkdir -p /home/ec2-user/.kube
cp -f /etc/kubernetes/admin.conf /home/ec2-user/.kube/config
chown -R ec2-user:ec2-user /home/ec2-user/.kube

export KUBECONFIG=/etc/kubernetes/admin.conf

# Install Calico (operator + VXLAN installation)
kubectl apply -f /opt/calico/tigera-operator.yaml

# Wait for the Calico CRDs to be established before creating the CRs
kubectl wait --for=condition=Established --timeout=180s \
  crd/installations.operator.tigera.io

kubectl apply -f /opt/calico/custom-resources.yaml

# Wait for Calico to be ready before any worker joins. Without a working CNI
# the nodes stay NotReady and CoreDNS cannot be scheduled.
for _ in $(seq 1 60); do
  kubectl -n calico-system get daemonset calico-node >/dev/null 2>&1 && break
  sleep 10
done

kubectl -n tigera-operator rollout status deployment/tigera-operator --timeout=300s || true
kubectl -n calico-system rollout status daemonset/calico-node --timeout=900s || true
kubectl -n calico-system rollout status deployment/calico-kube-controllers --timeout=300s || true

# Wait for CoreDNS to become available (needs the CNI up)
kubectl -n kube-system rollout status deployment/coredns --timeout=300s || true

echo "=== cluster and CNI ready; publishing join command ==="

# Publish the join command so worker nodes can join
JOIN_COMMAND="$(kubeadm token create --print-join-command)"
aws ssm put-parameter \
  --name "${PARAM_NAME}" \
  --type SecureString \
  --overwrite \
  --value "${JOIN_COMMAND}"

echo "=== control plane bootstrap complete ==="
