#!/usr/bin/env bash
set -euxo pipefail

# shellcheck source=/dev/null
. /tmp/k8s-versions.env

BASE="https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests"

mkdir -p /opt/calico

# Stage the operator, installation and manifest install files for offline bootstrap
curl -fsSL "${BASE}/tigera-operator.yaml" -o /opt/calico/tigera-operator.yaml
curl -fsSL "${BASE}/calico.yaml" -o /opt/calico/calico.yaml
install -m 0644 /tmp/calico-custom-resources.yaml /opt/calico/custom-resources.yaml

# Pre-pull the Tigera operator image referenced by the manifest (required)
OPERATOR_IMAGE="$(grep -oE 'quay\.io/tigera/operator:[^"'\''[:space:]]+' /opt/calico/tigera-operator.yaml | head -n1)"
ctr -n k8s.io images pull "${OPERATOR_IMAGE}"

# Pre-pull every image the release manifests reference (best-effort; the
# operator can pull anything missing at runtime through the NAT gateway)
for image in \
  $(grep -ho 'image: [^ ]*' /opt/calico/tigera-operator.yaml /opt/calico/calico.yaml \
    | awk '{print $2}' | sort -u); do
  ctr -n k8s.io images pull "${image}" \
    || echo "WARNING: could not pre-pull ${image}"
done
