# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "devopslab-vpc"
    Environment = var.environment
    Owner       = var.owner
  }
}

# Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name        = "devopslab-public-subnet"
    Environment = var.environment
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "devopslab-igw"
    Environment = var.environment
  }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "devopslab-public-rt"
    Environment = var.environment
  }
}

# Associate Route Table with Public Subnet
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security Group
resource "aws_security_group" "web" {
  name        = "devopslab-web-sg"
  description = "Security group for web server"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS access"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "devopslab-web-sg"
    Environment = var.environment
  }
}

resource "aws_instance" "web" {
  ami                         = var.ami
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.web.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.devopslab.key_name
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  user_data_replace_on_change = true

  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y docker.io awscli
    systemctl enable docker
    systemctl start docker
    aws ecr get-login-password --region eu-central-1 | \
      docker login --username AWS --password-stdin \
      439475769023.dkr.ecr.eu-central-1.amazonaws.com
    docker network create devops-net
    cat > /root/nginx.conf << 'NGINX'
    events {}
    http {
      server {
        listen 80;
        location / {
          proxy_pass         http://fastapi-app:8000;
          proxy_set_header   Host              $host;
          proxy_set_header   X-Real-IP         $remote_addr;
          proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        }
      }
    }
    NGINX
    docker run -d \
      --name fastapi-app \
      --network devops-net \
      --restart always \
      439475769023.dkr.ecr.eu-central-1.amazonaws.com/devopslab-app:6225f51
    docker run -d \
      --name nginx-proxy \
      --network devops-net \
      --restart always \
      -p 80:80 \
      -v /root/nginx.conf:/etc/nginx/nginx.conf:ro \
      nginx:alpine
  EOF

  tags = {
    Name        = "devopslab-web"
    Environment = var.environment
  }
}

# Key Pair
resource "aws_key_pair" "devopslab" {
  key_name   = "devopslab-key"
  public_key = file("~/.ssh/devopslab.pub")
}

# Private Subnet
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = "eu-central-1a"

  map_public_ip_on_launch = false

  tags = {
    Name = "devopslab-private-subnet"
  }
}

/*
# Elastic IP (for NAT)
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "devopslab-nat-eip"
  }
}

# NAT Gateway
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "devopslab-nat"
  }

  depends_on = [aws_internet_gateway.main]
}

# Private Route table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "devopslab-private-rt"
  }
}

# Associate private subnet
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}
*/

resource "aws_ecr_repository" "app" {
  name                 = "devopslab-app"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "devopslab-app"
    Environment = var.environment
  }
}

# Identity and Access Management Role for EC2 to pull from ECR
resource "aws_iam_role" "ec2_ecr_role" {
  name = "devopslab-ec2-ecr-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = {
    Name        = "devopslab-ec2-ecr-role"
    Environment = var.environment
  }
}

# Attach ECR read-only policy to the role
resource "aws_iam_role_policy_attachment" "ecr_read" {
  role       = aws_iam_role.ec2_ecr_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Instance Profile — wraps the role so EC2 can assume it
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "devopslab-ec2-profile"
  role = aws_iam_role.ec2_ecr_role.name
}
