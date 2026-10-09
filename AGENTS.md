## Infrastructure & Terraform Guidelines

### 🛠️ Core Tech Stack
- **IaC Tool:** Terraform (v1.5+)
- **Cloud Provider:** AWS (using the latest hashicorp/aws provider)
- **State Management:** Remote state backend (S3 native locking)


#### State Configuration Template
Every root module must declare the standard backend boilerplate in a `provider.tf` or `main.tf` file exactly like this:
```terraform
terraform {
  required_version = ">= 1.5.0"
  
  backend "s3" {
    # Leave bucket, key, region, and dynamodb_table blank.
    # These parameters must be injected dynamically via a backend config file (.tfbackend).
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```



### 🟢 ALWAYS
- **Modular Design:** Use verified registry modules (like `terraform-aws-modules/vpc/aws`) for standard infrastructure rather than writing resources from scratch.
- **Strict Network Isolation:** Deploy resources across distinct **Public**, **Private**, **and Database/Isolated** subnet tiers.
- **Automate Subnet Math:** Use the `cidrsubnet()` function to dynamically carve up the VPC CIDR block into subnets instead of hardcoding static IP ranges (e.g., `cidrsubnet(var.vpc_cidr, 4, local.index)`).
- **Multi-AZ Architecture:** Distribute subnets evenly across a minimum of 3 Availability Zones (AZs) for high availability.
- **Resource Tagging:** Apply standard tags to every resource using the `default_tags` block in the AWS provider (`Environment`, `Project`, `ManagedBy = "Terraform"`).
- **Enforce State Encryption:** Ensure the remote S3 bucket parameter used in initialization specifies or relies on AES256 server-side encryption.
- **Use Partial Backend Initialization:** Keep the `backend "s3" {}` block empty of configuration data. Define parameters inside an environment-specific file named `backend.tfbackend` (e.g., `bucket = "my-company-tfstate"`). And
configure backend with environment-aware.


### 🔴 NEVER
- **No Insecure Ingress:** Never open Security Group ingress rules to `0.0.0.0/0` except for public Load Balancers on ports 80/443.
- **No Hardcoded Values:** Do not hardcode CIDR blocks, region names, or environment strings. Use variables (`variables.tf`) or local values (`locals.tf`).
- **No Secrets in Code:** Never commit AWS access keys, passwords, or sensitive tokens. Use AWS Secrets Manager or variable files (`*.tfvars`) marked as sensitive.
- **No Default Routing to Internet:** Private subnets must never have a direct route to an Internet Gateway (IGW). They must route through a NAT Gateway.
- **No Hardcoded Backend Values:** Never hardcode specific S3 bucket names, state file keys, or DynamoDB tables inside the `.tf` files.
- **No Local State Files:** Do not run operations using default local backend storage. Never commit `.tfstate` or `.tfstate.backup` files to version control.


## 🌐 Workspace & Environment Isolation Rules

### 🟢 ALWAYS
- **Check the Active Workspace First:** Before generating plans or suggesting modifications, check the currently active workspace using `terraform workspace show`.
- **Target the Safe Default:** Always default to the `staging` workspace when executing exploratory commands or validation plans. 
- **Use Local State Mirages for Quick Validation:** If validating structural syntax without affecting remote cloud state, use a temporary local override or stick to isolated test workspaces.

### 🔴 NEVER
- **Never Run Blind Switches:** Do not run `terraform workspace select` or `terraform workspace new` without verifying if the workspace already exists or if it matches the current user's target environment intent.
- **Never Run `terraform apply` Automatically:** The agent is strictly prohibited from executing `terraform apply` or altering real-world infrastructure state. The agent's boundary ends at generating and verifying a `terraform plan`.
- **No Workspace Contamination:** Do not use environment-specific values inside shared resource configurations. All environment variation must be handled via `terraform.workspace` interpolations (e.g., `tags = { Environment = terraform.workspace }`) or cleanly mapped local lookups.

### 🔄 Updated Definition of Done & Validation
When validating workspaces alongside partial S3 backend configuration, you must follow this exact sequence:

1. **Initialize the Backend Safely:**
   ```bash
   terraform init -backend-config=backend.tfbackend
   ```
2. **Select/Verify Environment Workspace:**
   ```bash
   # Select the development/target workspace safely
   terraform workspace select dev || terraform workspace new dev
   ```
3. **Validate Code Isolation:**
   ```bash
   terraform fmt
   terraform validate
   ```
4. **Generate the Execution Plan:**
   ```bash
   # Always output the plan to a file to verify changes statically
   terraform plan -out=tfplan
   ```
