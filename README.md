# IaC Full Infra - Terraform (Portfolio)

Terraform project with VPC module + example dev environment.

## Quickstart (dev)
1. Configure AWS CLI: `aws configure`
2. cd environments/dev
3. terraform init
4. terraform plan -out=tfplan
5. terraform apply tfplan

Destroy resources after test:
`terraform destroy -auto-approve`
