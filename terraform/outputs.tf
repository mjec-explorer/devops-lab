output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "Public subnet ID"
  value       = aws_subnet.public.id
}

output "ec2_public_ip" {
  description = "EC2 instance public IP"
  value       = aws_instance.web.public_ip
}

output "ec2_instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.web.id
}

output "ssh_command" {
  description = "SSH command to connect"
  value       = "ssh -i ~/.ssh/devopslab ubuntu@${aws_instance.web.public_ip}"
}

output "ecr_repository_url" {
  description = "ECR repository URL for pushing and pulling images"
  value       = aws_ecr_repository.app.repository_url
}
