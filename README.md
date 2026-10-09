# k8s-network-calico


## Architecture

- VPC: `10.0.0.0/24` (configurable via `vpc_cidr`).
- 3 private subnets carved with `cidrsubnet()` across 3 AZs (`subnet_newbits`, default `2`).
- Private-only routing: `create_igw = false`, `enable_nat_gateway = false`.
- Default security group adopted and stripped of all rules (`manage_default_security_group = true` with empty rule lists).
- Workspace-driven environment isolation: tags (`Environment`) and naming derive from the active Terraform workspace (see `locals.environment` in `main.tf`).

## Prerequisites

- Terraform `>= 1.14`
- AWS CLI with a named profile (e.g. `default`)
- An S3 bucket for remote state (AES256 server-side encryption, native locking)

## Configuration

### 1. Remote state backend

`backend.tfbackend` holds backend parameters (not in `.tf` files). Fill in your bucket before initializing:

```hcl
bucket       = "REPLACE_WITH_TFSTATE_BUCKET"   # or your real bucket, e.g. labs
key          = "lab/terraform.tfstate"
region       = "us-west-1"                     # region of the state bucket
profile      = "default"
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

Apply (creates the VPC, 3 subnets, route tables, and a rule-free default security group):

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

## Notes
