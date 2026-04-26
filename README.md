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
| Compute | Auto Scaling Group, Launch Template, EC2 | Highly available app instances |
| App runtime | Nginx, Gunicorn, Flask | Web application stack |
| Data | RDS MySQL | Private relational database |
| Secrets | AWS Secrets Manager | Database credential storage |
| Identity | IAM role and instance profile | EC2 permissions for AWS APIs |
| Observability | CloudWatch Agent, logs, metrics, alarm | Basic monitoring and scale-out |

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
|   `-- bootstrap.sh
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

- Terraform `>= 1.5`
- AWS CLI
- AWS credentials configured locally
- An AWS account with permissions to create VPC, EC2, ALB, ASG, RDS, IAM, Secrets Manager, and CloudWatch resources

Check authentication:

```powershell
aws sts get-caller-identity
```

## Quick Start

```powershell
cd C:\iac-full-infra-terraform\environments\dev

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

app_ingress_cidr_blocks = ["YOUR_PUBLIC_IP/32"]

db_name        = "appdb"
db_username    = "appuser"
db_password    = "change-me"
db_secret_name = "dev-db-credentials"
```

For a public repository, do not commit real secrets. Prefer:

- `terraform.tfvars.example` for sample values
- `.gitignore` for real `terraform.tfvars`
- AWS Secrets Manager, SSM Parameter Store, or CI/CD secrets for sensitive values

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

They are designed for AWS OIDC authentication. Before using them in another AWS account or GitHub repository, update:

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

Destroy resources after demos if you do not need them running.

## Cleanup

```powershell
cd C:\iac-full-infra-terraform\environments\dev
terraform destroy -var-file="terraform.tfvars"
```

More detailed presentation and cleanup commands are available in [script.md](script.md).

## Portfolio Talking Points

Use this project to explain:

- Why the Terraform code is modular.
- How ALB health checks protect traffic flow.
- How ASG rolling refresh updates instances safely.
- Why RDS is placed privately.
- How EC2 retrieves DB credentials through IAM and Secrets Manager.
- How bootstrap converts a plain Ubuntu instance into a working application server.
- How to validate infrastructure using Terraform outputs, AWS CLI, and app endpoints.
