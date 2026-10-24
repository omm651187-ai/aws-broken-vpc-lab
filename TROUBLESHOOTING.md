# Incident Response & Troubleshooting Runbook: Broken VPC Lab

This runbook describes a systematic workflow for diagnosing VPC routing and EC2 connectivity issues in the AWS Broken VPC Terraform Lab. The configured AWS region is `eu-north-1` (Europe/Stockholm).

---

## Incident Summary

| Incident attribute | Details |
| :--- | :--- |
| **Symptoms** | SSH may time out or reject the key; the instance may be unable to reach the internet. |
| **Affected environment** | AWS `eu-north-1`; VPC `10.0.0.0/16`; public subnet `10.0.1.0/24`. |
| **Primary tools** | Terraform, AWS CLI, OpenSSH, terminal. |
| **Potential root causes** | Missing default route to the internet gateway; missing inbound TCP port 22 rule; wrong AWS account, region, key pair, or AMI username. |

**Current configuration:** `main.tf` includes the default internet gateway route and an inbound SSH rule. The SSH rule currently allows `0.0.0.0/0`; restrict it to a trusted source IP for normal use. Remove either fix only in a disposable environment when reproducing the original ticket.

---

## Step-by-Step Diagnostic Workflow

### Step 1: Verify the AWS account and region

Confirm the CLI is authenticated to the account where the lab was deployed:

```bash
aws sts get-caller-identity
aws configure list
```

The provider region in `main.tf` is `eu-north-1`. If using a named profile, select it in the same shell before running AWS CLI or Terraform commands:

```bash
export AWS_PROFILE=your-profile-name
aws sts get-caller-identity
```

An instance visible under a different account or region will not appear in the current console view or CLI query.

### Step 2: Verify the instance and retrieve its current public IP

Get the IP recorded in the active Terraform state:

```bash
terraform output -raw ec2_public_ip
```

Then confirm the instance state, IP, and assigned key pair in AWS:

```bash
aws ec2 describe-instances \
	--region eu-north-1 \
	--filters "Name=tag:Name,Values=Broken-Web-Instance" \
	--query 'Reservations[].Instances[].[InstanceId,State.Name,PublicIpAddress,KeyName]' \
	--output table
```

If no instance is returned, check the active account and region, then review `terraform plan`. A successful plan only previews changes; `terraform apply` provisions them. Review the plan before approving an apply.

### Step 3: Classify the SSH error

Use the current public IP from Step 2:

```bash
ssh -o ConnectTimeout=10 -o IdentitiesOnly=yes \
	-i ~/.ssh/demokey.pem ec2-user@PUBLIC_IP
```

Replace `PUBLIC_IP` with the instance's current address. Interpret the result:

- **Operation timed out:** investigate routing, public IP assignment, security group rules, network ACLs, and local network restrictions.
- **Permission denied (publickey):** SSH reached the host, but the key or username was rejected.
- **Successful Amazon Linux banner:** SSH authentication worked.

The AMI is Amazon Linux 2023, whose default SSH username is `ec2-user`.

### Step 4: Check the internet gateway route

Find the lab route table and inspect its routes:

```bash
aws ec2 describe-route-tables \
	--region eu-north-1 \
	--filters "Name=tag:Name,Values=Broken-Public-RT" \
	--query 'RouteTables[].Routes[].[DestinationCidrBlock,GatewayId,State]' \
	--output table
```

The subnet's associated route table needs an active `0.0.0.0/0` route whose target is the attached internet gateway. In Terraform, the lab defines this with `aws_route.public_internet_access`. If reproducing the missing-route incident, remove that resource only in a disposable lab; restore it and review `terraform plan` to fix the issue.

### Step 5: Check the security group

Inspect the security group ingress rules:

```bash
aws ec2 describe-security-groups \
	--region eu-north-1 \
	--filters "Name=group-name,Values=web-sg" \
	--query 'SecurityGroups[].[GroupId,IpPermissions]' \
	--output json
```

For SSH, confirm there is an inbound TCP port 22 rule from your current public IP in CIDR form (`x.x.x.x/32`). The current Terraform rule allows `0.0.0.0/0` for testing; narrow it before normal use. Manage the fix in Terraform so the configuration and deployed infrastructure stay in sync.

### Step 6: Verify the EC2 key pair and local private key

The AWS key pair name configured in `main.tf` is `demokey`. Verify it exists in the same account and region:

```bash
aws ec2 describe-key-pairs \
	--region eu-north-1 \
	--key-names demokey \
	--output table
```

The local private key must be the matching key material. Check its permissions and that OpenSSH can read it:

```bash
chmod 400 ~/.ssh/demokey.pem
ssh-keygen -y -f ~/.ssh/demokey.pem >/dev/null
```

The key pair name in AWS does not have to match the `.pem` filename. AWS does not let you download an existing private key again. Never paste or commit a private key.

### Step 7: Apply and verify the fix

Make route or security group changes in Terraform, then check the proposed changes before applying:

```bash
terraform validate
terraform plan
terraform apply
```

After apply, retrieve the current public IP again and retry SSH. An instance replacement can change its public IP, so do not rely on a previously copied address.

---

## Terraform Provider Startup Timeout

If Terraform times out while starting the AWS provider, reinitialize the provider plugins:

```bash
terraform init -reconfigure
```

If the issue persists, refresh only the downloaded provider files:

```bash
rm -rf .terraform/providers
terraform init
```

Do not delete `.terraform.lock.hcl` or Terraform state as a provider-startup fix. Check Terraform installation compatibility and network access to the Terraform Registry.

---

## State, Security, and Cleanup

This project uses local Terraform state. State can contain sensitive values, so it is excluded from Git by `.gitignore`; do not delete it to troubleshoot account or profile mismatches, and do not commit it. Use separate workspaces or separate copies of the project when managing different AWS accounts.

AWS charges may apply while the EC2 instance, storage, or public IPv4 address exists. When finished, review and run:

```bash
terraform destroy
```

Never share AWS access keys, session tokens, private keys, or unredacted Terraform state in a support request.
