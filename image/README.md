# image

Packer build for an ARM64 (Graviton) Amazon Linux 2023 AMI pre-loaded with everything needed to bootstrap a Kubernetes cluster with Calico:

- containerd (systemd cgroup driver)
- kubelet, kubeadm, kubectl
- Kubernetes control plane images pre-pulled
- Calico v3.33.0 (Tigera operator) images pre-pulled and manifests staged under `/opt/calico/`

## Files

| Path | Purpose |
|---|---|
| `build.pkr.hcl` | `amazon-ebs` source + build (arm64, encrypted boot, IMDSv2, manifest post-processor) |
| `variables.pkr.hcl` | Region, profile, Kubernetes/Calico versions, instance type, AMI prefix |
| `scripts/01-prereqs.sh` | swap off, kernel modules, sysctl, base packages |
| `scripts/02-containerd.sh` | containerd + `SystemdCgroup = true` |
| `scripts/03-kubernetes.sh` | k8s repo, kubelet/kubeadm/kubectl, pre-pull control plane images |
| `scripts/04-calico.sh` | stage Calico manifests, pre-pull operator + Calico images |
| `scripts/05-cleanup.sh` | clean caches, reset machine-id/ssh keys, cloud-init clean |
| `files/kubernetes.repo` | pkgs.k8s.io repo template (`__KUBERNETES_MINOR__` substituted) |
| `files/calico/custom-resources.yaml` | Calico `Installation` (VXLAN) + `APIServer` CRs |

## Prerequisites

- Packer >= 1.14 (so `packer init` can install the current `amazon` plugin)
- AWS credentials for the profile in `variables.pkr.hcl` with permissions to run instances, create images, tags, security groups and key pairs, and read AMIs (`ec2:DescribeImages`) or the SSM public parameter (`ssm:GetParameter`)
- The build instance needs outbound internet access (it uses a default-VPC public subnet)

## Build

Run from the repository root (`image` uses paths relative to its own directory):

```bash
packer init image
packer fmt -check image
packer validate image
packer build image
```

Override versions at build time:

```bash
packer build -var 'kubernetes_version=1.36' -var 'calico_version=v3.33.0' image
```

The build writes `image/manifest.json` containing the produced AMI ID.

## Use the image in Terraform

Copy the AMI ID from `manifest.json` into `sandbox.tfvars`:

```hcl
ami_id = "ami-1234566778"
```

The `modules/compute` module uses `ami_id` when set and skips the AMI lookup.

## Booting a cluster from the image

Each node already has the runtime, packages and images. On the control plane:

```bash
sudo kubeadm init --pod-network-cidr=192.168.0.0/16
kubectl apply -f /opt/calico/tigera-operator.yaml
kubectl apply -f /opt/calico/custom-resources.yaml
```

On the workers, join with the token printed by `kubeadm init`.

> Note: on Kubernetes 1.36+, Calico additionally requires the `projectcalico.org.v3`
> CRD bundle (for `MutatingAdmissionPolicy`). Apply it before the operator per the
> Calico 3.33 install docs if `kubectl apply` reports missing CRDs.
