output "instance_public_ip" {
	description = "Public IP address of the lab EC2 instance"
	value       = aws_instance.lab_vm.public_ip
}

output "instance_id" {
	description = "ID of the lab EC2 instance"
	value       = aws_instance.lab_vm.id
}

output "vpc_id" {
	description = "ID of the lab VPC"
	value       = aws_vpc.lab_vpc.id
}

output "subnet_id" {
	description = "ID of the lab subnet"
	value       = aws_subnet.lab_subnet.id
}
