#!/bin/bash
set -euo pipefail

exec > >(tee -a /var/log/k8s-bootstrap.log) 2>&1
echo "=== bootstrapping worker node ==="

# Ensure the container runtime is running
systemctl enable --now containerd

# Wait for the control plane to publish the join command
JOIN_COMMAND=""
for _ in $(seq 1 90); do
  JOIN_COMMAND="$(aws ssm get-parameter \
    --name "${PARAM_NAME}" \
    --with-decryption \
    --query 'Parameter.Value' \
    --output text 2>/dev/null || true)"
  if [ -n "${JOIN_COMMAND}" ] && [ "${JOIN_COMMAND}" != "None" ]; then
    break
  fi
  sleep 20
done

if [ -z "${JOIN_COMMAND}" ] || [ "${JOIN_COMMAND}" = "None" ]; then
  echo "ERROR: timed out waiting for the join command" >&2
  exit 1
fi

echo "joining cluster: ${JOIN_COMMAND}"
${JOIN_COMMAND}

echo "=== worker bootstrap complete ==="
