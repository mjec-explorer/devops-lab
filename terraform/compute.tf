resource "aws_instance" "jenkins" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private_1.id
  vpc_security_group_ids = [aws_security_group.jenkins.id]
  iam_instance_profile   = aws_iam_instance_profile.jenkins.name


  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y docker.io openjdk-17-jdk curl

    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    usermod -aG docker ubuntu

    # Install Jenkins
    curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | tee \
      /usr/share/keyrings/jenkins-keyring.asc > /dev/null
    echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
      https://pkg.jenkins.io/debian-stable binary/ | tee \
      /etc/apt/sources.list.d/jenkins.list > /dev/null
    apt-get update -y
    apt-get install -y jenkins

    # Start Jenkins
    systemctl start jenkins
    systemctl enable jenkins

    # Install AWS CLI
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    apt-get install -y unzip
    unzip awscliv2.zip
    ./aws/install
  EOF

  tags = {
    Name        = "${var.project_name}-jenkins"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_instance" "monitoring" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private_1.id
  vpc_security_group_ids = [aws_security_group.monitoring.id]
  iam_instance_profile   = aws_iam_instance_profile.monitoring.name


  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y docker.io docker-compose-plugin

    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    usermod -aG docker ubuntu
  EOF

  tags = {
    Name        = "${var.project_name}-monitoring"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}