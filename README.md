# terraform-aws-3tier-app

Terraform module set for a secure, multi-AZ 3-tier AWS network: public/private/isolated subnet tiers, a bastion for administrative access, an internet-facing ALB, and a PostgreSQL RDS instance with no direct internet exposure.

## Overview

This repository provisions the networking and compute foundation for a typical web application, the layer that sits below your actual app code. It is not an application; it's the infrastructure an application would run on.

Everything is built as reusable Terraform modules, composed in an `environments/dev` root module. The design favors explicitness over abstraction: no third-party module registries, no magic, every resource is declared so the VPC design decisions (subnetting, routing, security group chaining) are visible and auditable in the code itself.

## Design decisions

**Three subnet tiers, not two.** Public/private is the common minimum, but putting RDS in the same private subnet as the app servers means a compromised app server has network-level reach to the database with nothing but a security group in between. A dedicated, non-routable DB subnet tier removes that path entirely, the DB subnet's route table has no route to the NAT Gateway or IGW, so even a misconfigured security group can't expose it to the internet.

**Bastion over SSM.** AWS Systems Manager Session Manager is the more modern approach to admin access (no open SSH port, no key management, full audit logging via CloudTrail). A bastion was chosen deliberately here because the pattern, jump host, chained security groups, SSH key management, is still the one most engineering orgs run in practice, and it exercises exactly the concepts (security group chaining, subnet isolation) this repo is meant to demonstrate.

**Single NAT Gateway, not one per AZ.** A NAT Gateway per AZ is the resilient production pattern (an AZ outage doesn't take down egress for the other AZ), but it doubles NAT cost for a lab/demo environment. This repo uses one NAT Gateway in a single public subnet, a documented tradeoff, not an oversight. Flip to per-AZ NAT for a production deployment.

**Local state for v1.** State is currently local (`terraform.tfstate` in `environments/dev`). Remote state (S3 backend + DynamoDB locking) is a natural next step, kept separate so the state-locking mechanics can be introduced as their own reviewable change rather than baked in from the start.

**Secrets via environment variable, not `.tfvars`.** `db_password` is passed as `TF_VAR_db_password` at apply time and is never written to a tracked file. `terraform.tfvars` is committed since it contains no secrets, only region, sizing, and naming values (with `my_ip` and `key_name` left as placeholders, see Usage).

## Repository structure

```
terraform-aws-3tier-app/
├── modules/
│   ├── vpc/          # VPC, 6 subnets across 2 AZs, IGW, NAT, route tables
│   ├── security/     # Security groups: bastion, ALB, app, RDS, chained least-privilege
│   ├── ec2/          # Bastion + app servers, latest AL2023 AMI via data source
│   ├── alb/          # Load balancer, target group, health-checked listener
│   └── rds/          # PostgreSQL instance, dedicated subnet group
└── environments/
    └── dev/          # Root module: composes the above, environment-specific sizing
```

Each module exposes only what downstream modules or the root need via `outputs.tf`, no module reaches into another module's internals.

## Usage

Before applying, set two values in `environments/dev/terraform.tfvars`:

```hcl
key_name = "your-ec2-keypair-name"   # an existing EC2 key pair in your target region
my_ip    = "x.x.x.x/32"               # your public IP, find it with: curl -s https://checkip.amazonaws.com
```

```bash
cd environments/dev
export TF_VAR_db_password='<strong-password>'
terraform init
terraform plan
terraform apply
```

```bash
terraform destroy
```

Requires Terraform ≥ 1.12, AWS credentials with EC2/VPC/RDS/ELB permissions, and an existing EC2 key pair in the target region.

**Cost:** NAT Gateway and ALB are not free-tier eligible regardless of account age. EC2 t3.micro and RDS db.t3.micro are free-tier eligible on AWS accounts criteria. A short apply → test → destroy cycle costs single-digit cents. Nothing in this repo is designed to run unattended, destroy it when you're done.

## Security model

Security groups are chained, not opened broadly, each tier accepts traffic only from the specific security group in front of it, never from a CIDR range beyond what's strictly necessary:

| Resource | Inbound | Source |
|---|---|---|
| Bastion | 22 | single whitelisted IP (`/32`) |
| ALB | 80 | `0.0.0.0/0` |
| App servers | 80 | ALB security group |
| App servers | 22 | Bastion security group |
| RDS | 5432 | App server security group |

No resource other than the ALB and bastion has a route to the internet. The DB subnet's route table has no default route at all.

## Known limitations

- **Live traffic path unverified.** `terraform apply` has succeeded end-to-end (33/33 resources), and `terraform destroy` tears down cleanly. SSH connectivity through the bastion, ALB → app server response, and app server → RDS connectivity have not yet been tested live, infrastructure exists correctly per AWS, but request-level behavior hasn't been confirmed.
- Single NAT Gateway is a cost/resilience tradeoff, not a production recommendation (see Design decisions).
- `environments/prod` does not yet exist, sizing, Multi-AZ RDS, and deletion protection are dev-only right now.

## License

MIT
