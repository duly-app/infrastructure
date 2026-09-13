# Duly Infrastructure

Infrastructure-as-Code for the Duly note-taking app. Manages all AWS resources including EC2, networking, container registry, and DNS.

## Overview

This repository contains Terraform configurations for deploying Duly on a single EC2 instance running Kubernetes. Resources are tagged with project, environment, owner, and managed-by tags for organization and cost tracking.

## Prerequisites

- Terraform >= 1.6
- AWS CLI configured with appropriate credentials
- AWS account with permissions for EC2, VPC, IAM, ECR, and Route 53

## Remote State Backend

This project uses a remote S3 backend with DynamoDB-based locking for state management:
- **State bucket**: S3 (encrypted, versioned, public access blocked)
- **Locks**: DynamoDB (prevents concurrent applies, prevents destroy)
- **Benefits**: Reproducible infrastructure, team-safe state, audit trail

## Setup

### First Time (Bootstrap)

The S3 bucket and DynamoDB table are managed by Terraform but create a bootstrap dependency (chicken-and-egg problem). Follow this workflow:

1. Comment out the `backend "s3"` block in `main.tf`
2. Run `terraform init` (uses local state temporarily)
3. Run `terraform apply` (creates S3 bucket and DynamoDB table)
4. Uncomment the `backend "s3"` block in `main.tf`
5. Run `terraform init -backend-config=backend.hcl -migrate-state` (migrates state to S3)

### Configuration

Create `terraform.tfvars` (not committed to git):
```hcl
my_ip = "YOUR_IP/32"  # Your home/office IP for SSH access
```

Create/update `backend.hcl` (not committed to git):
```hcl
bucket         = "terraform-state-duly-YOUR_ACCOUNT_ID"
key            = "terraform.tfstate"
region         = "eu-north-1"
dynamodb_table = "terraform-state-lock"
encrypt        = true
```

## Usage

```bash
# Initialize with backend config
terraform init -backend-config=backend.hcl

# Preview changes
terraform plan

# Apply changes
terraform apply

# Destroy EC2 to save money (keep state infrastructure)
terraform destroy -target=aws_instance.main

# Later: recreate EC2 from state
terraform apply
```

## Structure

- `main.tf` — Terraform and provider configuration, backend block
- `state.tf` — S3 bucket and DynamoDB table (remote backend)
- `vpc.tf` — VPC, subnets, and networking
- `security_group.tf` — Security groups with rules
- `ec2.tf` — EC2 instance configuration
- `variables.tf` — Input variables and shared locals
- `outputs.tf` — Exported values for other systems
- `backend.hcl` — Backend configuration (not in git, see `.gitignore`)

## Cost Management

**Strategy**: Destroy the EC2 instance when not actively developing:
```bash
terraform destroy -target=aws_instance.main
```

Recreate it anytime with:
```bash
terraform apply
```

The S3 state persists, so the recreated instance will have the same configuration.

**Note**: Destroying the EC2 instance also destroys the associated EIP. This means a new EIP will be associated with the EC2 instance when you create it again.

However, note that the next time you spin it up your instance will be assigned a new public IP.

## Tagging Strategy

All resources are tagged with:
- `Project` — project name (duly)
- `Environment` — deployment environment (production)
- `Owner` — resource owner
- `ManagedBy` — "terraform" (indicates IaC management)
- `CostCenter` — "portfolio"

## CI/CD

GitHub Actions automatically validates Terraform on pull requests:
- `terraform fmt -check` — formatting
- `terraform validate` — syntax
- `tflint` — best practices and style
