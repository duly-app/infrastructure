# Duly Infrastructure

Everything needed to run the Duly note-taking app, from a laptop to AWS. Duly's
code lives in four application repositories; this one holds only the things
that put them somewhere.

| Directory | What it is |
| --- | --- |
| `terraform/` | Terraform for AWS: EC2, VPC, security groups, remote state |
| `dev/` | Docker Compose stack for local development |
| `k8s/` | Kubernetes manifests (the production target) |

The two environments deliberately couple differently. **Compose builds from
your working tree**, so an edit in `duly-backend/src` is live immediately;
that is the whole point of it. **Kubernetes pulls tagged images** and needs no
application source at all. This is also why the app repos are not submodules
here (a submodule pins a commit).

## Local development

The compose stack runs all four services plus Postgres, embedding services,
and a Loki/Prometheus/Grafana observability stack.

- `dev/docker-compose.dev.yml` — the stack
- `dev/.env.example` — repository paths and uid/gid; copy to `dev/.env`
- `dev/nginx/` — the reverse proxy config, which stands in for an Ingress
- `dev/docker/` — Postgres first-start hooks
- `dev/loki/`, `dev/alloy/`, `dev/prometheus/`, `dev/grafana/` — observability config

### Prerequisites

- Docker with Compose v2
- The four application repositories checked out
- `.env.dev` present in `duly-backend`, `duly-chat-backend` and `embedder-qa`
  (each repo tracks its own; they are dev credentials, not secrets)

By default the repositories are expected to be siblings of this one:

```
note-taking-app/
  duly-backend/
  duly-chat-backend/
  duly-frontend/
  embedder-qa/
  duly-infra/        <- this repo
```

If yours live elsewhere, copy `dev/.env.example` to `dev/.env` and point the
`*_PATH` variables at them. Do this anyway on first checkout, to set `UID` and
`GID`: the containers write to the bind-mounted `src` directories, and without
those the files end up owned by the wrong user.

```bash
cd dev
cp .env.example .env
sed -i '' -e "s/^UID=.*/UID=$(id -u)/" -e "s/^GID=.*/GID=$(id -g)/" .env
```

### Usage

All commands run from `dev/`.

```bash
# Start everything and block until it is actually serving
docker compose -f docker-compose.dev.yml up -d --wait

# Follow one service
docker compose -f docker-compose.dev.yml logs -f duly-backend

# Rebuild after a dependency change (source alone needs no rebuild)
docker compose -f docker-compose.dev.yml up -d --build duly-backend

# Stop, keeping the database
docker compose -f docker-compose.dev.yml down
```

If no services are specified above these commands sweep over all services.

### What is exposed

Everything binds to `127.0.0.1` only. The app is reached through nginx on
port 80, which is also what the production topology looks like, so there is no
separate dev URL to remember.

`dev/nginx/nginx.conf` has no production counterpart, and should not grow one.
Routing in Kubernetes is an Ingress resource: you declare path rules and the
controller generates its own nginx config, so this file is not an input. It
exists because Compose has no Ingress primitive. The frontend's *other* nginx —
the one serving static files with an SPA fallback — lives in
`duly-frontend/nginx.conf`, because it is baked into the image.

| URL | Service |
| --- | --- |
| http://localhost | the app (nginx → frontend) |
| http://localhost/api/ | duly-backend |
| http://localhost/api/chat/ | duly-chat-backend |
| http://localhost:3000 | Grafana (login disabled, auto-admin) |
| http://localhost:9090 | Prometheus |
| http://localhost:12345 | Alloy |
| `localhost:5432` | Postgres |

The backend and embedding service are reachable only through nginx or from
inside the network. `dev-network-internal` has `internal: true`, so those
containers have no route out to the internet; only `duly-chat-backend` is on an
egress network, because it is the one that calls the Anthropic API.

### Database

```bash
docker exec -it dev-duly-postgres psql -U admin -d duly_postgres
```

Two databases exist. `duly_postgres` is the real one. `duly_test` is created by
`dev/docker/init-test-db.sh` and is what `duly-backend`'s Postgres integration
tests connect to via `TEST_DATABASE_URL` — it exists so those tests never touch
your notes. The script is a `docker-entrypoint-initdb.d` hook, so it runs only
when the data directory is empty, i.e. on the very first start.

Migrations are not run by the backend. `duly-migrate` is a one-shot container
that runs `alembic upgrade head` and exits, and `duly-backend` waits on
`service_completed_successfully` before starting. One container applies them
once, no matter how many backend replicas there are — the same shape as a
Kubernetes Job.

> **There are no backups.** The dev database holds real notes. `docker compose
> down` is safe; `down -v` destroys them. To test a cold start, compose with a throwaway
> project name so it gets its own volumes.

## Terraform

Deploys Duly on a single EC2 instance running Kubernetes. Resources are tagged
with project, environment, owner, and managed-by tags for organization and cost
tracking.

All commands in this section run from `terraform/`.

### Prerequisites

- Terraform >= 1.6
- AWS CLI configured with appropriate credentials
- AWS account with permissions for EC2, VPC, IAM, ECR, and Route 53

### Remote State Backend

This project uses a remote S3 backend with DynamoDB-based locking for state management:
- **State bucket**: S3 (encrypted, versioned, public access blocked)
- **Locks**: DynamoDB (prevents concurrent applies, prevents destroy)
- **Benefits**: Reproducible infrastructure, team-safe state, audit trail

### Setup

#### First Time (Bootstrap)

The S3 bucket and DynamoDB table are managed by Terraform but create a bootstrap dependency (chicken-and-egg problem). Follow this workflow:

1. Comment out the `backend "s3"` block in `main.tf`
2. Run `terraform init` (uses local state temporarily)
3. Run `terraform apply` (creates S3 bucket and DynamoDB table)
4. Uncomment the `backend "s3"` block in `main.tf`
5. Run `terraform init -backend-config=backend.hcl -migrate-state` (migrates state to S3)

#### Configuration

Create `terraform/terraform.tfvars` (not committed to git):
```hcl
my_ip = "YOUR_IP/32"  # Your home/office IP for SSH access
```

Create/update `terraform/backend.hcl` (not committed to git):
```hcl
bucket         = "terraform-state-duly-YOUR_ACCOUNT_ID"
key            = "terraform.tfstate"
region         = "eu-north-1"
dynamodb_table = "terraform-state-lock"
encrypt        = true
```

### Usage

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

### Structure

- `main.tf` — Terraform and provider configuration, backend block
- `state.tf` — S3 bucket and DynamoDB table (remote backend)
- `vpc.tf` — VPC, subnets, and networking
- `security_group.tf` — Security groups with rules
- `ec2.tf` — EC2 instance configuration
- `variables.tf` — Input variables and shared locals
- `outputs.tf` — Exported values for other systems
- `session_manager.tf` — SSM Session Manager access to the instance
- `backend.hcl` — Backend configuration (not in git, see `.gitignore`)

### Cost Management

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

### Tagging Strategy

All resources are tagged with:
- `Project` — project name (duly)
- `Environment` — deployment environment (production)
- `Owner` — resource owner
- `ManagedBy` — "terraform" (indicates IaC management)
- `CostCenter` — "portfolio"

## CI/CD

GitHub Actions validates Terraform on pull requests.
- `terraform fmt -check` — formatting
- `terraform validate` — syntax
- `tflint` — best practices and style
