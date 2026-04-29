# IaC Full Infra - Terraform AWS Portfolio

Infrastructure as Code portfolio project that provisions a full AWS application stack with Terraform. The project demonstrates modular Terraform design, load balancing, autoscaling, private database access, secrets management, IAM instance profiles, automated EC2 bootstrap, and operational validation.

## What This Project Deploys

```text
User
  -> Application Load Balancer :80
  -> Auto Scaling Group across 2 public subnets
  -> EC2 Ubuntu 22.04 instances
  -> Nginx reverse proxy
  -> Gunicorn
  -> Flask application
  -> AWS Secrets Manager for DB credentials
  -> Private RDS MySQL
```

Default deployment target:

- Region: `ap-southeast-3`
- Environment: `dev`
- Compute: ASG with `t3.micro`, desired `2`, min `2`, max `4`
- Database: RDS MySQL `db.t3.micro`
- App runtime: Python Flask behind Gunicorn and Nginx
- Monitoring: CloudWatch Agent config and CPU scale-out alarm

## Verified Runtime Result

The deployed application has been validated through the ALB:

```json
{
  "app": "iac-full-infra",
  "az": "ap-southeast-3a",
  "db": {
    "connected": true,
    "error": "",
    "host": "app-db.cjwc6uy8qcqm.ap-southeast-3.rds.amazonaws.com"
  },
  "instance": "i-0cff5741779a59779",
  "region": "ap-southeast-3"
}
```

This proves the main flow works end to end:

```text
ALB -> ASG/EC2 -> Nginx -> Gunicorn -> Flask -> Secrets Manager -> RDS
```

## Architecture Components

| Layer | AWS resource | Purpose |
| --- | --- | --- |
| Network | VPC, public/private subnets, IGW, optional NAT | Isolated network foundation |
| Entry point | Application Load Balancer | Public HTTP access and health checks |
| Compute | Auto Scaling Group, Launch Template, EC2 / Docker | Highly available app instances |
| App runtime | Gunicorn, Flask (containerized) | Web application stack |
| Data | RDS MySQL | Private relational database |
| Secrets | AWS Secrets Manager | Database credential storage |
| Identity | IAM role and instance profile | EC2 permissions for AWS APIs |
| Observability | CloudWatch Agent, logs, metrics, alarm | Basic monitoring and scale-out |

## Docker Support

The application has been containerized with Docker. This is the first step toward Kubernetes (EKS) migration while keeping the existing Terraform infrastructure intact.

### Project Files for Docker

| File | Purpose |
| --- | --- |
| `Dockerfile` | Multi-stage build: installs dependencies (builder stage) then runs the Flask app with Gunicorn (runtime stage) |
| `.dockerignore` | Excludes Terraform configs, git files, Python cache from the Docker build context |
| `requirements.txt` | Python dependencies (flask, gunicorn, pymysql) |
| `docker-compose.yml` | Local development with environment variable support |

### Build & Run Locally

```bash
# Build the image
docker build -t iac-full-infra-app:latest .

# Run with docker-compose (recommended for local testing)
docker-compose up --build

# Or run directly with Docker
docker run -d \
  --name iac-full-infra-app \
  -p 5000:5000 \
  -e AWS_REGION=ap-southeast-3 \
  -e DB_HOST=your-rds-endpoint \
  -e DB_SECRET_NAME=dev-db-credentials \
  -e AWS_ACCESS_KEY_ID=your-key \
  -e AWS_SECRET_ACCESS_KEY=your-secret \
  iac-full-infra-app:latest

# Test the container
curl http://localhost:5000/health
curl http://localhost:5000/api/info
```

### Environment Variables

| Variable | Default | Description |
| --- | --- | --- |
| `APP_NAME` | `iac-full-infra` | Application name displayed on dashboard |
| `AWS_REGION` | `ap-southeast-3` | AWS region |
| `DB_HOST` | *(empty)* | RDS endpoint (must be set for DB connection) |
| `DB_NAME` | `appdb` | Database name |
| `DB_SECRET_NAME` | `dev-db-credentials` | Secrets Manager secret name |
| `ENVIRONMENT` | `dev` | Deployment environment |
| `PROJECT_NAME` | `iac-full-infra` | Project name for resource tagging |

### What Changed When Containerizing

- **app.py** now auto-detects if running inside a container (`/.dockerenv` or cgroup check)
- Container-specific startup info is shown on the dashboard instead of EC2 bootstrap logs
- **Nginx is removed** — Gunicorn binds directly to `0.0.0.0:5000` (load balancing is handled by the ALB/Kubernetes Ingress in production)
- **CloudWatch Agent is removed** — container logs go to stdout/stderr (captured by Docker/Kubernetes logging)
- **Systemd service is removed** — Gunicorn is the container entrypoint (managed by Docker/Kubernetes)

## Repository Structure

```text
.
|-- environments/
|   `-- dev/
|       |-- main.tf
|       |-- variables.tf
|       |-- outputs.tf
|       `-- terraform.tfvars
|-- modules/
|   |-- alb/
|   |-- asg/
|   |-- db/
|   |-- ec2/
|   |-- iam/
|   |-- secrets/
|   `-- vpc/
|-- scripts/
|   |-- app.py
|   |-- bootstrap.sh
|   `-- setup-backend.sh
|-- .github/
|   `-- workflows/
|       |-- terraform-plan.yml
|       `-- terraform-apply.yml
|-- README.md
`-- script.md
```

## Terraform Modules

| Module | Responsibility |
| --- | --- |
| `modules/vpc` | VPC, public/private subnets, internet gateway, route tables, optional NAT gateway |
| `modules/alb` | ALB, ALB security group, listener, target group |
| `modules/asg` | Launch template, Auto Scaling Group, rolling instance refresh |
| `modules/ec2` | Standalone EC2 mode when ASG is disabled |
| `modules/db` | RDS MySQL instance and DB subnet group |
| `modules/secrets` | Secrets Manager secret and version |
| `modules/iam` | EC2 IAM role, policy, instance profile, SSM attachment |

## Application Bootstrap

EC2 instances run [scripts/bootstrap.sh](scripts/bootstrap.sh) as user data. The bootstrap process:

1. Installs system dependencies.
2. Creates a Python virtual environment.
3. Downloads the full Flask app from GitHub: [scripts/app.py](scripts/app.py).
4. Falls back to an embedded minimal Flask app if GitHub download fails.
5. Creates a Gunicorn `systemd` service.
6. Configures Nginx as a reverse proxy.
7. Installs/configures CloudWatch Agent on a best-effort basis.
8. Configures log rotation.

The app exposes:

| Endpoint | Purpose |
| --- | --- |
| `/` | Dashboard page |
| `/health` | ALB health check |
| `/api/info` | Runtime metadata and DB connection status |

## Prerequisites

- Terraform `>= 1.10` recommended for the S3 backend `use_lockfile` setting; GitHub Actions currently uses Terraform `1.11.4`
- AWS CLI
- AWS credentials configured locally
- An AWS account with permissions to create VPC, EC2, ALB, ASG, RDS, IAM, Secrets Manager, and CloudWatch resources

Check authentication:

```powershell
aws sts get-caller-identity
```

## Remote State Backend

The dev environment is configured to store Terraform state in S3:

```hcl
bucket       = "iac-tfstate-407772390483"
key          = "dev/terraform.tfstate"
region       = "ap-southeast-3"
use_lockfile = true
encrypt      = true
```

Create the backend resources once before the first `terraform init`:

```bash
chmod +x scripts/setup-backend.sh
./scripts/setup-backend.sh
```

The script creates the S3 state bucket with versioning, encryption, and public access blocked. It also creates a DynamoDB lock table for compatibility, although the active backend configuration currently uses Terraform's native S3 lockfile setting.

## Quick Start

```powershell
cd C:\iac-full-infra-terraform\environments\dev

$env:TF_VAR_db_password = "replace-with-a-strong-password"

terraform init
terraform fmt -check -recursive ..\..
terraform validate
terraform plan -var-file="terraform.tfvars" -out="tfplan"
terraform apply "tfplan"
```

Get the ALB DNS:

```powershell
terraform output -raw alb_dns_name
```

Test the app:

```powershell
$ALB = terraform output -raw alb_dns_name
curl.exe "http://$ALB/health"
curl.exe "http://$ALB/api/info"
```

Expected DB result:

```json
"db": {
  "connected": true
}
```

## Important Variables

Edit [environments/dev/terraform.tfvars](environments/dev/terraform.tfvars):

```hcl
aws_region = "ap-southeast-3"

vpc_cidr = "10.0.0.0/16"
azs      = ["ap-southeast-3a", "ap-southeast-3b"]

enable_asg           = true
asg_desired_capacity = 2
asg_min_size         = 2
asg_max_size         = 4
asg_app_name         = "app"

scale_out_adjustment        = 1
scale_out_cooldown          = 60
cpu_high_threshold          = 70
cpu_high_evaluation_periods = 2
cpu_high_period             = 60

app_ingress_cidr_blocks = ["YOUR_PUBLIC_IP/32"]

db_name        = "appdb"
db_username    = "appuser"
db_secret_name = "dev-db-credentials"

environment  = "dev"
project_name = "iac-full-infra"
```

For a public repository, do not commit real secrets. Prefer:

- `terraform.tfvars.example` for sample values
- `.gitignore` for real `terraform.tfvars`
- AWS Secrets Manager, SSM Parameter Store, or CI/CD secrets for sensitive values

For local runs, provide the DB password through an environment variable instead of committing it:

```powershell
$env:TF_VAR_db_password = "replace-with-a-strong-password"
```

## Operational Validation

Run these after deployment:

```powershell
$ALB = terraform output -raw alb_dns_name
$TG  = terraform output -raw alb_target_group_arn

curl.exe "http://$ALB/health"
curl.exe "http://$ALB/api/info"

aws elbv2 describe-target-health `
  --target-group-arn $TG `
  --region ap-southeast-3

aws autoscaling describe-auto-scaling-groups `
  --auto-scaling-group-names app-asg `
  --region ap-southeast-3
```

Healthy target group output should show each target with:

```json
"State": "healthy"
```

The `/api/info` endpoint should show:

- EC2 instance id
- Availability Zone
- Region
- Hostname
- DB connection status
- RDS host

## CI/CD

GitHub Actions workflows are included:

- `.github/workflows/terraform-plan.yml`
- `.github/workflows/terraform-apply.yml`

They are designed for AWS OIDC authentication and run Terraform against `environments/dev`.

Required GitHub configuration:

| Type | Name | Purpose |
| --- | --- | --- |
| Secret | `AWS_ROLE_TO_ASSUME` | IAM role assumed through GitHub OIDC |
| Secret | `DB_PASSWORD` | Injected as `TF_VAR_db_password` |
| Variable | `APP_INGRESS_CIDR_BLOCKS` | Injected as `TF_VAR_app_ingress_cidr_blocks` |

Workflow behavior:

| Workflow | Trigger | Notes |
| --- | --- | --- |
| `Terraform Plan` | Pull requests that touch Terraform/workflow files, or manual dispatch | Runs fmt, init, validate, plan, and comments on PRs |
| `Terraform Apply` | Manual dispatch | Runs only on `refs/heads/master` and targets the `dev` environment |

Before using these workflows in another AWS account or GitHub repository, update:

- `role-to-assume`
- AWS region if needed
- IAM trust policy for the repository

## Security Notes

- RDS is private and not publicly accessible.
- App instances access RDS through security groups.
- DB credentials are stored in Secrets Manager.
- EC2 uses an IAM instance profile rather than static AWS keys.
- ALB exposes HTTP port `80` publicly.
- Direct app ingress is restricted by `app_ingress_cidr_blocks`.

## Cost Notes

This project can create billable AWS resources:

- ALB
- EC2 instances
- RDS instance
- NAT Gateway if enabled
- CloudWatch logs/metrics
- Secrets Manager

## Cleanup

You can destroy all resources if you do not need them running.

```powershell
cd C:\iac-full-infra-terraform\environments\dev
terraform destroy -var-file="terraform.tfvars"
```
