# k8s-network-calico


## Architecture

- VPC: `10.0.0.0/24` (configurable via `vpc_cidr`).
- 3 private subnets carved with `cidrsubnet()` across 3 AZs (`subnet_newbits`, default `3`).
- 1 public subnet hosting a single NAT gateway, giving the private subnets outbound-only internet access (e.g. to pull container images). Private subnets have no direct Internet Gateway route.
- Default security group adopted and stripped of all rules (`manage_default_security_group = true` with empty rule lists).
- Workspace-driven environment isolation: tags (`Environment`) and naming derive from the active Terraform workspace (see `locals.environment` in `main.tf`).
- `modules/compute` provisions two EC2 nodes (ARM64 `t4g`) and a Kubernetes intra-cluster security group (API server, etcd, kubelet, controller-manager, scheduler, Calico BGP/VXLAN) with outbound egress for image pulls.

## Prerequisites

- Terraform `>= 1.14`
- AWS CLI with a named profile (e.g. `default`)
- An S3 bucket for remote state (AES256 server-side encryption, native locking)

## Required IAM permissions

The AWS principal running this project needs the policy in [`iam/terraform-apply-policy.json`](iam/terraform-apply-policy.json). It covers the VPC/NAT module, the `compute` module (instances, security groups, IAM role/instance profile), the SSM AMI lookup, `sts:GetCallerIdentity`, and S3 state access.

```bash
aws iam put-role-policy \
  --role-name <your-role> \
  --policy-name k8s-network-calico \
  --policy-document file://iam/terraform-apply-policy.json
```

Before applying, update in the policy file:

- Replace `xxxxxxxxxxxx` in the IAM ARNs (`role/...`, `instance-profile/...`, `PassRole`) with your AWS account ID.
- Set the `SsmAmiLookup` region (`us-west-2`) to your `aws_region`.
- Set the S3 resource ARNs to your Terraform state bucket.
- Adjust the `k8s-calico-network-*` name pattern if you change `project_name` or the workspace-derived environment.

To also build the AMI with `packer build image`, add:

```json
{ "Sid": "ImageBuild", "Effect": "Allow",
  "Action": ["ec2:CreateImage", "ec2:DeregisterImage", "ec2:CreateKeyPair", "ec2:DeleteKeyPair", "ec2:DescribeKeyPairs"],
  "Resource": "*" }
```

## Configuration

### 1. Remote state backend

`backend.tfbackend` holds backend parameters (not in `.tf` files). Fill in your bucket before initializing:

```hcl
bucket       = "REPLACE_WITH_TFSTATE_BUCKET"   # your Terraform state bucket
key          = "path/to/terraform.tfstate"
region       = "REPLACE_WITH_STATE_BUCKET_REGION"  # region of the state bucket
profile      = "REPLACE_WITH_AWS_PROFILE"
encrypt      = true
use_lockfile = true
```

### 2. Variable values

`sandbox.tfvars` injects variable values. Values shown are dummies; adjust as needed:

```hcl
aws_region     = "us-west-2"    # region for the infrastructure (needs >= 3 AZs)
aws_profile    = "default" # AWS CLI profile for credentials
project_name   = "k8s-calico-network"
vpc_cidr       = "10.0.0.0/24"
subnet_newbits = 3
single_nat_gateway = true       # one shared NAT gateway (false = one NAT per AZ)
ami_id             = "ami-0123456789abcdef0"  # from image/manifest.json (Packer-built AMI)
```

The environment value is **not** in the tfvars file — it is derived from the active Terraform workspace for environment isolation.

## Running the project

Initialize the backend with the backend config file:

```bash
terraform init -backend-config=backend.tfbackend
```

Select (or create) the environment workspace, defaulting to `dev`:

```bash
terraform workspace show
terraform workspace select dev || terraform workspace new dev
```

Validate and format:

```bash
terraform fmt -check -recursive
terraform validate
```

Generate an execution plan (always output to a file for review):

```bash
terraform plan -var-file=sandbox.tfvars -out=tfplan
terraform show tfplan   # review the plan before applying
```

Apply (creates the VPC, 3 private + 1 public subnet, route tables, IGW, NAT gateway, and a rule-free default security group):

```bash
terraform apply tfplan
```

Inspect outputs:

```bash
terraform output
```

Destroy the sandbox when finished:

```bash
terraform destroy -var-file=sandbox.tfvars
```

## Accessing nodes

Nodes are private with no public IP or SSH. Connect through **SSM Session Manager**
(the node role carries `AmazonSSMManagedInstanceCore`):

```bash
aws ssm start-session --target "$(terraform output -json node_instance_ids | jq -r '."node-1"')" \
  --profile <aws_profile>
```

The local machine needs the [Session Manager plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html).
Cluster bootstrap logs are at `/var/log/k8s-bootstrap.log` on each node.

## Notes

- Private subnets reach the internet **outbound only** via the NAT gateway; inbound exposure is unchanged (no `0.0.0.0/0` security-group ingress; nodes are reached via SSM Session Manager, not SSH).
- `us-west-1` only exposes 2 AZs, so the infrastructure region must have at least three (e.g. `us-west-2`, `us-east-1`); the state bucket region is independent.
- The AWS principal needs the permissions in `iam/terraform-apply-policy.json` to plan/apply/destroy.
- Set `ami_id` to the AMI from `image/manifest.json`; changing it replaces the nodes (they are immutable).
- `*.tfstate`, `tfplan`, and `.terraform/` are gitignored; `.terraform.lock.hcl` and `backend.tfbackend` are versioned.
