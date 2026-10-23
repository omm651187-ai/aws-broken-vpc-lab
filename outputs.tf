output "ec2_public_ip" {
  description = "Public IP address of the broken web server instance"
  value       = aws_instance.web.public_ip
}