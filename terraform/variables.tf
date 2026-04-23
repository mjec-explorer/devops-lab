variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Project name used as prefix for all resources"
  type        = string
  default     = "devopslab"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "lab"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "my_ip" {
  description = "Your home IP for admin access"
  type        = string
  default     = "104.151.92.154/32"
}

variable "private_subnet_1_cidr" {
  description = "Private subnet 1 CIDR block"
  type        = string
  default     = "10.0.10.0/24"
}

variable "private_subnet_2_cidr" {
  description = "Private subnet 2 CIDR block"
  type        = string
  default     = "10.0.20.0/24"
}

variable "public_subnet_1_cidr" {
  description = "Public subnet 1 CIDR block"
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet_2_cidr" {
  description = "Public subnet 2 CIDR block"
  type        = string
  default     = "10.0.2.0/24"
}

variable "az_1" {
  description = "Primary availability zone"
  type        = string
  default     = "eu-central-1a"
}

variable "az_2" {
  description = "Secondary availability zone"
  type        = string
  default     = "eu-central-1b"
}