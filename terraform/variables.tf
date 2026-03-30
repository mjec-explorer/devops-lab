variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-central-1"
}
variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}
variable "public_subnet_cidr" {
  description = "public subnet cidr"
  type        = string
  default     = "10.0.1.0/24"
}
variable "availability_zone" {
  description = "availability zone"
  type        = string
  default     = "eu-central-1a"
}
variable "ami" {
  description = "AMI ID for EC2 instance"
  type        = string
  default     = "ami-0faab6bdbac9486fb"
}
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}
variable "environment" {
  description = "environment"
  type        = string
  default     = "lab"
}
variable "owner" {
  description = "owner"
  type        = string
  default     = "mjcastro"
}

variable "private_subnet_cidr" {
  description = "Private subnet CIDR block"
  type = string
  default = "10.0.2.0/24"
}
