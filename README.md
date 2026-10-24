# AWS Broken VPC Lab

A small Terraform lab for deploying an AWS VPC, public subnet, internet gateway, route table, and Amazon Linux 2023 EC2 instance. It is intended for practicing basic AWS networking and Terraform workflows.

## What it creates

- A VPC with CIDR `10.0.0.0/16`
- A subnet with CIDR `10.0.1.0/24` and public IPv4 address assignment enabled
- An internet gateway attached to the VPC
- A route table with a default route (`0.0.0.0/0`) to the internet gateway, associated with the subnet
- An Amazon Linux 2023 x86_64 EC2 instance of type `t3.micro`

The routing configuration is present in the current Terraform files. The instance does not configure an SSH key pair or a custom security group, so inbound SSH access is not set up by this project.

## Prerequisites

- Terraform 1.x
- AWS CLI credentials with permission to create and delete the resources above
- AWS account access in `eu-north-1`

The AWS provider in `main.tf` currently selects the AWS CLI profile `userdemo-terraform`. Configure that profile locally, or change the provider configuration to use the profile or credential method you prefer. Keep credentials and private keys out of this repository.

Verify the active identity before creating resources:

```sh
aws sts get-caller-identity --profile userdemo-terraform
```

## Deploy

From the project directory, initialize Terraform, validate the configuration, and review the plan:

```sh
terraform init
terraform validate
terraform plan
```

Create the resources only after reviewing the plan:

```sh
terraform apply
```

Terraform will ask for confirmation. After a successful apply, inspect the outputs:

```sh
terraform output
terraform output -raw instance_public_ip
```

The available outputs are the instance public IP, instance ID, VPC ID, and subnet ID. Outputs become available in state after Terraform applies the configuration.

## Connectivity notes

The subnet has a public IP assignment setting and a default route through the internet gateway. That provides the network path for internet access, but does not configure inbound SSH. To enable SSH for a lab, add an EC2 key pair and a security group rule restricted to your current public IP (`x.x.x.x/32`). Avoid opening SSH to `0.0.0.0/0`.

If the instance cannot reach the internet, check that it is running, has a public IP, and that the subnet's associated route table has an active `0.0.0.0/0` route targeting the attached internet gateway. Also verify that the AWS account and region match the Terraform provider configuration.

## Cleanup

EC2 instances, storage, and public IPv4 addresses may incur AWS charges. When finished, review the destroy plan and remove the lab resources:

```sh
terraform plan -destroy
terraform destroy
```

Terraform state can contain sensitive information. The repository's `.gitignore` excludes local state, downloaded providers, variable files, and common local secrets; do not force-add these files to Git.
