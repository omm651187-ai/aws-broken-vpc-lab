# Troubleshooting

This guide covers common Terraform and connectivity issues in the AWS Broken VPC lab. The provider is configured for `eu-north-1` and the AWS CLI profile `userdemo-terraform`.

## Check Terraform and AWS credentials

Confirm Terraform can validate the configuration and that the selected AWS profile points to the intended account:

```sh
terraform validate
aws sts get-caller-identity --profile userdemo-terraform
```

If the AWS command fails, configure or refresh the `userdemo-terraform` profile locally. Do not put access keys in Terraform files or commit them to GitHub.

To see which resources Terraform currently tracks:

```sh
terraform state list
```

If a resource exists in AWS but not in this list, check that you are using the expected Terraform workspace, state, AWS profile, and region before applying changes.

## `terraform output` shows no values

Output declarations are in `outputs.tf`, but values are written to Terraform state during an apply. Review and apply the current configuration, then check the outputs again:

```sh
terraform plan
terraform apply
terraform output
```

The public IP can be printed by itself with:

```sh
terraform output -raw instance_public_ip
```

Review the plan before confirming. Terraform may create or update resources in addition to recording outputs.

## EC2 instance creation fails

Check the full AWS error in the `terraform apply` output. For an unsupported instance configuration, verify that `t3.micro` is offered in the selected region and Availability Zone. The AMI filter in `main.tf` selects Amazon Linux 2023 x86_64, which is compatible with the x86-based `t3.micro` family. If the type is unavailable, choose an offered type compatible with the AMI, or choose a different Availability Zone.

If Terraform cannot find an AMI, confirm the AWS region and check that the Amazon Linux 2023 x86_64 AMI filter in `main.tf` is valid for that region.

## Internet connectivity and `ping`

First identify where you ran the test. A command such as:

```sh
ping -c 4 amazon.com
```

run in your Mac terminal tests your Mac's DNS and network connection; it says nothing about the EC2 instance's connectivity. Check local DNS and HTTPS separately:

```sh
nslookup amazon.com
curl -I https://amazon.com
```

Ping can also fail when ICMP traffic is filtered, even if HTTPS works. Use the output of the command, not just its exit code, to distinguish name-resolution failures from missed ping replies.

For the EC2 instance, verify in the AWS console or CLI that it is running, has a public IPv4 address, and passes its status checks. The Terraform configuration creates an internet gateway, a `0.0.0.0/0` route, and an association between the route table and the subnet. Confirm these resources were applied in the same VPC and region.

This project does not configure an SSH key pair or a custom security group, so it does not provide inbound SSH access for testing from a terminal. To connect to the instance, configure an appropriate access method in Terraform. If enabling SSH, restrict port 22 to your current public IP (`x.x.x.x/32`); do not expose it to `0.0.0.0/0`.

## Verify the subnet route

Get the subnet ID from Terraform, then inspect its associated route table:

```sh
SUBNET_ID=$(terraform output -raw subnet_id)
aws ec2 describe-route-tables \
	--region eu-north-1 \
	--profile userdemo-terraform \
	--filters "Name=association.subnet-id,Values=$SUBNET_ID" \
	--query 'RouteTables[].Routes[].[DestinationCidrBlock,GatewayId,State]' \
	--output table
```

The output should include an active `0.0.0.0/0` route whose target is the VPC's internet gateway. If the route table is missing or the route is not active, review `terraform plan` and apply the configuration after verifying the proposed changes.

## Cleanup

AWS may charge for running instances, storage, and public IPv4 addresses. When finished, review and destroy the resources:

```sh
terraform plan -destroy
terraform destroy
```

Terraform state can contain sensitive values. Keep state files local and never force-add them to Git.
