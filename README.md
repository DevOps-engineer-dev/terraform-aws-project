# Terraform + GitHub Actions CI/CD — Web App VPC

Single-environment AWS infrastructure: a VPC with 2 public + 2 private
subnets across 2 AZs, a NAT Gateway per AZ, two EC2 web servers in the
private subnets, and an internet-facing Application Load Balancer (HTTP
only) distributing traffic to them.

Everything is written as plain Terraform resources (no modules, no Auto
Scaling Group) to keep it easy to read while you're learning. You can
introduce modules, ASGs, multiple environments, and TLS later.

## File overview

| File | What it defines |
|---|---|
| `providers.tf` | Terraform/provider config, commented-out S3 backend |
| `variables.tf` | All input variables and their defaults |
| `network.tf` | VPC, subnets, IGW, NAT Gateways, route tables |
| `security_groups.tf` | ALB and EC2 security groups |
| `ec2.tf` | AMI lookup, IAM role for SSM, the two EC2 instances |
| `alb.tf` | Load balancer, target group, HTTP listener |
| `user_data.sh` | Bootstrap script that installs and starts httpd |
| `outputs.tf` | Values printed after apply (e.g. the ALB URL) |
| `.github/workflows/terraform-plan.yml` | Runs on every PR |
| `.github/workflows/terraform-apply.yml` | Runs on merge to `main` |

## One-time bootstrap (do this before any pipeline runs)

You need three things that Terraform itself can't create for you,
because they're what Terraform depends on to run safely: a place to
store state, a way to lock it, and a way for GitHub to authenticate to
AWS without long-lived keys.

### 1. Create the S3 bucket + DynamoDB lock table

Run this once, locally, with your own AWS credentials:

```bash
aws s3api create-bucket \
  --bucket YOUR-UNIQUE-BUCKET-NAME \
  --region us-east-1

aws s3api put-bucket-versioning \
  --bucket YOUR-UNIQUE-BUCKET-NAME \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket YOUR-UNIQUE-BUCKET-NAME \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

Then edit the `backend "s3" {}` block in `providers.tf`: uncomment it and
fill in your bucket name. Run `terraform init -migrate-state` once
locally to move state into S3.

### 2. Set up GitHub OIDC → AWS IAM (no stored AWS keys)

Create an IAM OIDC identity provider for GitHub (one-time, per AWS
account):

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

Create an IAM role GitHub Actions will assume. Trust policy
(`trust-policy.json`) — replace `ACCOUNT_ID`, `YOUR_GH_ORG`, `YOUR_REPO`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GH_ORG/YOUR_REPO:*"
        }
      }
    }
  ]
}
```

```bash
aws iam create-role \
  --role-name github-actions-terraform-role \
  --assume-role-policy-document file://trust-policy.json

# Start broad while you're learning, then scope this down to just the
# services this project touches (ec2, elasticloadbalancing, iam PassRole
# for the instance profile, and s3/dynamodb for the backend).
aws iam attach-role-policy \
  --role-name github-actions-terraform-role \
  --policy-arn arn:aws:iam::aws:policy/PowerUserAccess
```

Copy the resulting role ARN into a GitHub repo secret named
`AWS_ROLE_ARN` (Settings → Secrets and variables → Actions).

### 3. Create a GitHub Environment for apply approvals (optional but recommended)

In your repo: Settings → Environments → New environment → name it
`production` (this matches `environment: production` in
`terraform-apply.yml`). Add yourself as a required reviewer if you want
a manual "approve" click before every real apply.

## Running it locally first (recommended before wiring up CI)

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply
```

Once you're happy with the plan output, open the `alb_dns_name` output
in a browser — you should see the "Hello from ..." page, and refreshing
should occasionally show a different availability zone as the ALB load
balances between the two instances.

```bash
terraform destroy   # tear it all down when you're done experimenting
```

## How the pipeline works

1. Open a PR that touches any `.tf` file → `terraform-plan.yml` runs
   `fmt`, `init`, `validate`, and `plan`, then posts the plan as a PR
   comment so you can review the diff before merging.
2. Merge the PR to `main` → `terraform-apply.yml` runs `init`, `plan`,
   and `apply -auto-approve`. If you configured the `production`
   environment with required reviewers, the job pauses for approval
   before applying.

## What's intentionally left out for now (add later as you grow)

- **TLS/HTTPS** — add an `aws_lb_listener` on 443 with an ACM
  certificate, and redirect 80 → 443.
- **Auto Scaling Group** — replace the two static `aws_instance`
  resources with a launch template + ASG for self-healing and scaling.
- **Modules** — once the resource files feel repetitive, factor
  `network.tf` into a reusable `modules/vpc` module.
- **Multiple environments** — duplicate the working directory per
  environment (`envs/dev`, `envs/prod`) with separate state files and
  tfvars once you need more than one.
