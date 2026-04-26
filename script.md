# Portfolio Presentation Script

This runbook is a step-by-step command guide for presenting the project from Terraform validation through deployment testing and final destroy.

Commands use PowerShell and assume the repo is located at:

```powershell
C:\iac-full-infra-terraform
```

## 1. Move To The Environment Directory

```powershell
cd C:\iac-full-infra-terraform\environments\dev
```

Talking point:

```text
This folder is the root Terraform environment for dev. It composes reusable modules from the modules directory.
```

## 2. Confirm AWS Authentication

```powershell
aws sts get-caller-identity
```

Expected:

```text
Returns Account, UserId, and Arn.
```

If it fails:

```powershell
aws configure
```

Or, if using SSO:

```powershell
aws sso login
```

## 3. Initialize Terraform

```powershell
terraform init
```

Talking point:

```text
Terraform downloads the AWS provider and prepares the backend/state for this environment.
```

## 4. Format Check

```powershell
terraform fmt -check -recursive ..\..
```

Expected:

```text
No output means formatting is already correct.
```

If formatting is needed:

```powershell
terraform fmt -recursive ..\..
```

## 5. Validate Terraform

```powershell
terraform validate
```

Expected:

```text
Success! The configuration is valid.
```

Talking point:

```text
This checks syntax, module references, variable usage, and provider-level configuration structure.
```

## 6. Review Variables

```powershell
Get-Content .\terraform.tfvars
```

Key values to explain:

```text
aws_region
vpc_cidr
azs
enable_asg
asg_desired_capacity
app_ingress_cidr_blocks
db_name
db_secret_name
```

Security note:

```text
For public repositories, real secrets should not be committed. Use tfvars examples and external secret storage.
```

## 7. Create A Terraform Plan

```powershell
terraform plan -var-file="terraform.tfvars" -out="tfplan"
```

Expected:

```text
Terraform shows resources to create, update, or destroy.
```

Talking point:

```text
Plan is the review step before changing AWS. It prevents blind apply.
```

## 8. Apply The Plan

```powershell
terraform apply "tfplan"
```

Expected:

```text
Apply complete.
```

Important:

```text
RDS and ASG can take several minutes. Wait until Terraform completes.
```

## 9. Show Terraform Outputs

```powershell
terraform output
```

Store useful outputs:

```powershell
$ALB = terraform output -raw alb_dns_name
$TG  = terraform output -raw alb_target_group_arn
$DB  = terraform output -raw db_endpoint
```

Show them:

```powershell
$ALB
$TG
$DB
```

Talking point:

```text
Outputs are the handoff from infrastructure provisioning to operational validation.
```

## 10. Test ALB Health Endpoint

```powershell
curl.exe "http://$ALB/health"
```

Expected:

```json
{
  "status": "healthy",
  "instance": "i-xxxxxxxxxxxxxxxxx",
  "az": "ap-southeast-3a",
  "region": "ap-southeast-3"
}
```

Talking point:

```text
The request is going through the public ALB to an EC2 instance running Nginx, Gunicorn, and Flask.
```

## 11. Test App And Database Connectivity

```powershell
curl.exe "http://$ALB/api/info"
```

Expected:

```json
{
  "db": {
    "connected": true,
    "error": "",
    "host": "app-db.xxxxx.ap-southeast-3.rds.amazonaws.com"
  }
}
```

Talking point:

```text
This proves the app can read credentials from Secrets Manager and connect to private RDS.
```

## 12. Test Load Balancing

Run multiple times:

```powershell
curl.exe "http://$ALB/api/info"
curl.exe "http://$ALB/api/info"
curl.exe "http://$ALB/api/info"
```

Expected:

```text
The instance id or AZ may change between responses.
```

Talking point:

```text
The ALB distributes traffic across healthy ASG instances in multiple Availability Zones.
```

## 13. Check Target Group Health

```powershell
aws elbv2 describe-target-health `
  --target-group-arn $TG `
  --region ap-southeast-3
```

Expected:

```json
"State": "healthy"
```

If a target is `initial`:

```text
Wait a few minutes. The instance is still registering or bootstrapping.
```

If a target is `draining`:

```text
ASG rolling refresh or deregistration is in progress.
```

## 14. Check Auto Scaling Group

```powershell
aws autoscaling describe-auto-scaling-groups `
  --auto-scaling-group-names app-asg `
  --region ap-southeast-3
```

Check:

```text
DesiredCapacity = 2
MinSize = 2
MaxSize = 4
Instances LifecycleState = InService
HealthStatus = Healthy
```

## 15. Check RDS

```powershell
aws rds describe-db-instances `
  --db-instance-identifier app-db `
  --region ap-southeast-3 `
  --query "DBInstances[0].{Status:DBInstanceStatus,Endpoint:Endpoint.Address,Public:PubliclyAccessible,Engine:Engine,Class:DBInstanceClass}"
```

Expected:

```text
Status = available
Public = false
Engine = mysql
```

## 16. Check Secrets Manager

```powershell
aws secretsmanager describe-secret `
  --secret-id dev-db-credentials `
  --region ap-southeast-3
```

Optional value check:

```powershell
aws secretsmanager get-secret-value `
  --secret-id dev-db-credentials `
  --region ap-southeast-3 `
  --query SecretString `
  --output text
```

Talking point:

```text
In production demos, avoid printing secret values. For portfolio evidence, describing the secret is usually enough.
```

## 17. Check CloudWatch Log Groups

```powershell
aws logs describe-log-groups `
  --log-group-name-prefix app-bootstrap `
  --region ap-southeast-3
```

Also check:

```powershell
aws logs describe-log-groups `
  --log-group-name-prefix nginx `
  --region ap-southeast-3
```

Talking point:

```text
Bootstrap and Nginx logs are configured for CloudWatch collection.
```

## 18. Check CloudWatch Alarm

```powershell
aws cloudwatch describe-alarms `
  --alarm-names cpu-high `
  --region ap-southeast-3
```

Talking point:

```text
The alarm is connected to the ASG scale-out policy. When CPU crosses the threshold, ASG can add capacity.
```

## 19. Demonstrate Rolling Update

After changing `scripts/bootstrap.sh` or `scripts/app.py`, run:

```powershell
terraform plan -var-file="terraform.tfvars" -out="tfplan"
terraform apply "tfplan"
```

Then watch target health:

```powershell
aws elbv2 describe-target-health `
  --target-group-arn $TG `
  --region ap-southeast-3
```

Expected transition:

```text
old instance -> draining
new instance -> initial
new instance -> healthy
```

Talking point:

```text
The ASG uses launch template changes and instance refresh to roll out new bootstrap/app versions.
```

## 20. Final Demo Checklist

Run these as the final proof:

```powershell
terraform validate
curl.exe "http://$ALB/health"
curl.exe "http://$ALB/api/info"
aws elbv2 describe-target-health --target-group-arn $TG --region ap-southeast-3
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names app-asg --region ap-southeast-3
```

What to say:

```text
The infrastructure is created by Terraform, the app is publicly reachable through ALB, compute is autoscaled, RDS remains private, and the app accesses the database through Secrets Manager and IAM.
```

## 21. Destroy Resources

Use this when the presentation/demo is finished:

```powershell
terraform destroy -var-file="terraform.tfvars"
```

Confirm with:

```text
yes
```

Or non-interactive:

```powershell
terraform destroy -var-file="terraform.tfvars" -auto-approve
```

Warning:

```text
Destroy removes AWS resources managed by this Terraform state. Use carefully.
```

## 22. Post-Destroy Checks

```powershell
terraform state list
```

Expected:

```text
No managed resources should remain, or the state list should be empty after a successful destroy.
```

Optional AWS checks:

```powershell
aws elbv2 describe-load-balancers --region ap-southeast-3
aws autoscaling describe-auto-scaling-groups --region ap-southeast-3
aws rds describe-db-instances --region ap-southeast-3
```

## Common Troubleshooting

### AWS credentials missing

```text
No valid credential sources found
```

Fix:

```powershell
aws configure
aws sts get-caller-identity
```

### Target group shows initial

Meaning:

```text
Instance is still registering or bootstrap is still running.
```

Fix:

```text
Wait 3-10 minutes, then check again.
```

### Target group shows draining

Meaning:

```text
ASG is replacing or removing an instance.
```

Fix:

```text
Wait until the new target is healthy.
```

### App shows DB disconnected

Check:

```powershell
curl.exe "http://$ALB/api/info"
aws secretsmanager describe-secret --secret-id dev-db-credentials --region ap-southeast-3
aws rds describe-db-instances --db-instance-identifier app-db --region ap-southeast-3
```

Common causes:

```text
EC2 IAM role missing permission
Secrets Manager secret missing or wrong
RDS not available yet
Security group between app and DB incorrect
```

### Metadata shows unknown

Meaning:

```text
The app cannot reach EC2 instance metadata, or IMDS settings/path are wrong.
```

Current bootstrap supports IMDSv2 and falls back to IMDSv1.
