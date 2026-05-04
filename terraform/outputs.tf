output "alb_dns_name" {
  description = "Application Load Balancer DNS name — open this in browser"
  value       = aws_lb.main.dns_name
}

output "ecr_repository_url" {
  description = "ECR repository URL for Jenkins to push images"
  value       = aws_ecr_repository.app.repository_url
}

output "jenkins_instance_id" {
  description = "Jenkins EC2 instance ID for SSM access"
  value       = aws_instance.jenkins.id
}

output "monitoring_instance_id" {
  description = "Monitoring EC2 instance ID for SSM access"
  value       = aws_instance.monitoring.id
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "configs_bucket_name" {
  description = "S3 bucket name for monitoring configs"
  value       = aws_s3_bucket.configs.id
}