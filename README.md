# AWS Broken VPC & Connectivity Troubleshooting Lab

A hands-on cloud troubleshooting and infrastructure-as-code (IaC) project built with **Terraform** and **AWS**. This repository models support tickets involving network routing failures and security group rules in the `eu-north-1` region.

---

## Architecture Overview

The lab provisions a VPC, public subnet, internet gateway, route table, security group, and Amazon Linux 2023 EC2 instance.

- **Region:** `eu-north-1` (Europe/Stockholm)
- **VPC:** `10.0.0.0/16`
- **Public subnet:** `10.0.1.0/24` in `eu-north-1a`
- **Internet gateway:** attached to the VPC
- **Public route table:** associated with the subnet
- **Security group:** `web-sg`
- **EC2 instance:** `t3.micro`, Amazon Linux 2023

Terraform exports the instance's public address as `ec2_public_ip`.

---

## Support Ticket Scenarios

The lab covers two common connectivity failures:

1. **Missing internet gateway route**
	- **Symptom:** The instance cannot access the internet, and internet traffic cannot reach the subnet.
	- **Root cause:** The public route table has no default route (`0.0.0.0/0`) to the internet gateway.
	- **Fix:** Add a default route to the internet gateway.

2. **Missing security group SSH rule**
	- **Symptom:** SSH attempts time out even when the instance has a public IP and the correct key.
	- **Root cause:** The instance's security group does not allow inbound TCP port 22.
	- **Fix:** Allow SSH from the client's public IP.

**Current configuration:** Both fixes are already present in `main.tf`. A fresh `terraform apply` will create a reachable instance, assuming the AWS key pair and credentials are configured correctly. To reproduce the original failures in a disposable lab, remove `aws_route.public_internet_access` for the routing scenario, or remove the port 22 ingress rule from `aws_security_group.web_sg` for the SSH scenario.

---

## Prerequisites & Tools

- **Terraform** 1.x
- **AWS CLI** authenticated to the intended AWS account
- An EC2 key pair named `demokey` in `eu-north-1`
- The matching private key file on your machine

The AWS key pair name (`demokey`) is distinct from the local `.pem` filename. AWS only lets you download the private key when the pair is created. Never commit the private key to GitHub.

Verify the CLI identity before provisioning:

```bash
aws sts get-caller-identity
```

For a named AWS CLI profile, select it in the current shell and verify the account:

```bash
export AWS_PROFILE=your-profile-name
aws sts get-caller-identity
```

---

## Quick Start Guide

### 1. Clone the repository

```bash
git clone https://github.com/omm651187-ai/aws-broken-vpc-lab.git
cd aws-broken-vpc-lab
```

### 2. Initialize and review the plan

```bash
terraform init
terraform validate
terraform plan
```

The AWS provider region is set to `eu-north-1` in `main.tf`. Check the active AWS account and review the plan before proceeding.

### 3. Create the resources

```bash
terraform apply
```

Review the proposed changes and type `yes` only if they are expected. Get the public IP with:

```bash
terraform output -raw ec2_public_ip
```

### 4. Connect to the instance

For Amazon Linux 2023, the default SSH username is `ec2-user`:

```bash
chmod 400 ~/.ssh/demokey.pem
ssh -i ~/.ssh/demokey.pem ec2-user@$(terraform output -raw ec2_public_ip)
```

Update the key path if your private key is stored elsewhere.

---

## Security & Cleanup

The current security group allows SSH from `0.0.0.0/0`, exposing port 22 to the internet. For anything beyond a short-lived lab, restrict SSH to your current public IP using a `/32` CIDR before applying. HTTP on port 80 is also open to the internet.

AWS may charge for the EC2 instance, storage, and public IPv4 address. Destroy the resources when finished:

```bash
terraform destroy
```

Review the destroy plan before confirming.

Terraform state can contain sensitive data, so it is excluded by `.gitignore` along with `.pem` keys and variable files. Commit `.terraform.lock.hcl` to keep provider versions consistent. This project uses local Terraform state; it does not configure shared remote state.
