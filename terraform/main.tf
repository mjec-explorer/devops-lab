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
      -e GIT_SHA=6225f51 \
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
      Action = "sts:AssumeRole"
      Effect = "Allow"
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

# ECS Execution Role — allows ECS to pull from ECR and write CloudWatch logs
resource "aws_iam_role" "ecs_execution" {
  name = "devopslab-ecs-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = {
    Name        = "devopslab-ecs-execution"
    Environment = var.environment
  }
}

# Attach AWS managed policy — covers ECR pull and CloudWatch logs
resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
# CloudWatch Log Group — stores ECS container logs
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/devopslab-app"
  retention_in_days = 7

  tags = {
    Name        = "devopslab-app-logs"
    Environment = var.environment
  }
}
# Security Group for ALB — allows internet traffic on port 80
resource "aws_security_group" "alb" {
  name        = "devopslab-alb-sg"
  description = "Allow HTTP inbound to ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
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
    Name        = "devopslab-alb-sg"
    Environment = var.environment
  }
}

# Security Group for ECS tasks — allows traffic ONLY from ALB
resource "aws_security_group" "ecs_tasks" {
  name        = "devopslab-ecs-tasks-sg"
  description = "Allow traffic from ALB only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP from ALB only"
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "devopslab-ecs-tasks-sg"
    Environment = var.environment
  }
}
# Application Load Balancer
resource "aws_lb" "main" {
  name               = "devopslab-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public.id, aws_subnet.public_2.id]

  tags = {
    Name        = "devopslab-alb"
    Environment = var.environment
  }
}

# Target Group — where ALB sends traffic
resource "aws_lb_target_group" "app" {
  name        = "devopslab-tg"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
    matcher             = "200"
  }

  tags = {
    Name        = "devopslab-tg"
    Environment = var.environment
  }
}

# Listener — rule: port 80 on ALB → forward to target group
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
# Second Public Subnet (required for ALB — different AZ)
resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr_2
  availability_zone       = "eu-central-1b"
  map_public_ip_on_launch = true

  tags = {
    Name        = "devopslab-public-subnet-2"
    Environment = var.environment
  }
}

# Associate second public subnet with public route table
resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}
# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "devopslab-cluster"

  tags = {
    Name        = "devopslab-cluster"
    Environment = var.environment
  }
}

# ECS Task Definition — blueprint for running the container
resource "aws_ecs_task_definition" "app" {
  family                   = "devopslab-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution.arn

  container_definitions = jsonencode([{
    name      = "app"
    image     = "${aws_ecr_repository.app.repository_url}:1c7cb29"
    essential = true

    portMappings = [{
      containerPort = 8000
      protocol      = "tcp"
    }]

    environment = [{
      name  = "GIT_SHA"
      value = "1c7cb29"
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/devopslab-app"
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])

  tags = {
    Name        = "devopslab-app"
    Environment = var.environment
  }
}

# ECS Service — keeps tasks running, connects to ALB
resource "aws_ecs_service" "app" {
  name            = "devopslab-app"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public.id, aws_subnet.public_2.id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = 8000
  }

  depends_on = [aws_lb_listener.http]

  tags = {
    Name        = "devopslab-app"
    Environment = var.environment
  }
}
# Auto Scaling Target — defines min and max task count
resource "aws_appautoscaling_target" "ecs" {
  max_capacity       = 4
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Auto Scaling Policy — scale out when CPU exceeds 70%
resource "aws_appautoscaling_policy" "scale_out" {
  name               = "devopslab-scale-out"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
