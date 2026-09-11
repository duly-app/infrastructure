# Duly Infrastructure

Infrastructure-as-Code for the Duly note-taking app. Manages all AWS resources including EC2, networking, container registry, and DNS.

## Overview

This repository contains Terraform configurations for deploying Duly on a single EC2 instance running Kubernetes. Resources are tagged with project, environment, owner, and managed-by tags for organization and cost tracking.

## Prerequisites

- Terraform >= 1.6
- AWS CLI configured with appropriate credentials
- AWS account with permissions for EC2, VPC, IAM, ECR, and Route 53

## Usage

```bash
# Initialize Terraform (first time)
terraform init

# Preview changes
terraform plan

# Apply changes
terraform apply
```

## Structure

- `main.tf` — AWS provider and EC2 instance configuration
- `variables.tf` — Input variables and locals (tags, etc.)
- `outputs.tf` — Exported values for other systems

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

Push to main requires pull request review.
