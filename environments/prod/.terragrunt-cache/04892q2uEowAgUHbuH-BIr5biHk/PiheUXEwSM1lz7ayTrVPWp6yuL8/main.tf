terraform {
  backend "s3" {}
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true

  tags = {
    Name    = "${var.vpc_name}-${var.environment}-vpc"
    Project = "SPSkills"
    Environment = var.environment
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name    = "${var.vpc_name}-${var.environment}-igw"
    Project = "SPSkills"
    Environment = var.environment
  }

  depends_on = [aws_vpc.this]
}

resource "aws_subnet" "pub_a" {
  cidr_block              = var.pub_a_cidr
  availability_zone       = var.az_a
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.this.id

  tags = {
    Name    = "${var.vpc_name}-${var.environment}-public-subnet-a"
    Project = "SPSkills"
    Environment = var.environment
  }

  depends_on = [aws_vpc.this]
}

resource "aws_subnet" "priv_a" {
  cidr_block        = var.priv_a_cidr
  availability_zone = var.az_a
  vpc_id            = aws_vpc.this.id

  tags = {
    Name    = "${var.vpc_name}-${var.environment}-private-subnet-a"
    Project = "SPSkills"
    Environment = var.environment
  }

  depends_on = [aws_vpc.this]
}

resource "aws_subnet" "pub_b" {
  cidr_block              = var.pub_b_cidr
  availability_zone       = var.az_b
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.this.id

  tags = {
    Name    = "${var.vpc_name}-${var.environment}-public-subnet-b"
    Project = "SPSkills"
    Environment = var.environment
  }

  depends_on = [aws_vpc.this]
}

resource "aws_subnet" "priv_b" {
  cidr_block        = var.priv_b_cidr
  availability_zone = var.az_b
  vpc_id            = aws_vpc.this.id

  tags = {
    Name    = "${var.vpc_name}-${var.environment}-private-subnet-b"
    Project = "SPSkills"
    Environment = var.environment
  }

  depends_on = [aws_vpc.this]
}

resource "aws_eip" "eip_a" {
  domain = "vpc"

  tags = {
    Project = "SPSkills"
    Environment = var.environment
  }
}

resource "aws_nat_gateway" "nat_a" {
  subnet_id     = aws_subnet.pub_a.id
  allocation_id = aws_eip.eip_a.id

  tags = {
    Name    = "${var.vpc_name}-${var.environment}-nat-a"
    Project = "SPSkills"
    Environment = var.environment
  }

  depends_on = [aws_internet_gateway.this, aws_subnet.pub_a, aws_eip.eip_a]
}

resource "aws_eip" "eip_b" {
  domain = "vpc"

  tags = {
    Project = "SPSkills"
    Environment = var.environment
  }
}

resource "aws_nat_gateway" "nat_b" {
  subnet_id     = aws_subnet.pub_b.id
  allocation_id = aws_eip.eip_b.id

  tags = {
    Name    = "${var.vpc_name}-${var.environment}-nat-b"
    Project = "SPSkills"
    Environment = var.environment
  }

  depends_on = [aws_internet_gateway.this, aws_subnet.pub_b, aws_eip.eip_b]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    gateway_id = aws_internet_gateway.this.id
    cidr_block = "0.0.0.0/0"
  }

  tags = {
    Name    = "${var.vpc_name}-${var.environment}-public-rtb"
    Project = "SPSkills"
    Environment = var.environment
  }

  depends_on = [aws_vpc.this, aws_internet_gateway.this]
}

resource "aws_route_table" "private_a" {
  vpc_id = aws_vpc.this.id

  route {
    nat_gateway_id = aws_nat_gateway.nat_a.id
    cidr_block     = "0.0.0.0/0"
  }

  tags = {
    Name    = "${var.vpc_name}-${var.environment}-private-rtb-a"
    Project = "SPSkills"
    Environment = var.environment
  }

  depends_on = [aws_vpc.this, aws_nat_gateway.nat_a]
}

resource "aws_route_table" "private_b" {
  vpc_id = aws_vpc.this.id

  route {
    nat_gateway_id = aws_nat_gateway.nat_b.id
    cidr_block     = "0.0.0.0/0"
  }

  tags = {
    Name    = "${var.vpc_name}-${var.environment}-private-rtb-b"
    Project = "SPSkills"
    Environment = var.environment
  }

  depends_on = [aws_vpc.this, aws_nat_gateway.nat_b]
}

resource "aws_route_table_association" "public_a" {
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.pub_a.id
}

resource "aws_route_table_association" "private_a" {
  route_table_id = aws_route_table.private_a.id
  subnet_id      = aws_subnet.priv_a.id
}

resource "aws_route_table_association" "public_b" {
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.pub_b.id
}

resource "aws_route_table_association" "private_b" {
  route_table_id = aws_route_table.private_b.id
  subnet_id      = aws_subnet.priv_b.id
}

resource "aws_security_group" "bastion_sg" {
  vpc_id = aws_vpc.this.id

  ingress {
    from_port   = 22
    to_port     = 22
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
    Name    = "bastion-${var.environment}-sg"
    Project = "SPSkills"
    Environment = var.environment
  }
}

resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "local_file" "this" {
  content         = tls_private_key.this.private_key_openssh
  filename        = "bastion-key.pem"
  file_permission = "400"
}

resource "aws_key_pair" "this" {
  key_name   = "bastion-${var.environment}-key"
  public_key = tls_private_key.this.public_key_openssh
  tags = {
    Project = "SPSkills"
    Environment = var.environment
  }
}

resource "aws_iam_role" "this" {
  name = "EC2BastionRole${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Project = "SPSkills"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_instance_profile" "this" {
  role = aws_iam_role.this.name

  tags = {
    Project = "SPSkills"
    Environment = var.environment
  }
}

resource "aws_instance" "bastion" {
  subnet_id            = aws_subnet.pub_a.id
  ami                  = var.amazon_linux_2023_ami
  security_groups      = [aws_security_group.bastion_sg.id]
  instance_type        = "t3.micro"
  key_name             = aws_key_pair.this.key_name
  iam_instance_profile = aws_iam_instance_profile.this.name

  tags = {
    Name    = "iac-bastion-${var.environment}"
    Project = "SPSkills"
    Environment = var.environment
  }

  user_data = <<-EOF
  #!/bin/bash
  sudo yum update -y 
  sudo dnf install -y dnf-plugins-core
  sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
  sudo dnf -y install terraform
  wget https://github.com/gruntwork-io/terragrunt/releases/download/v0.90.0/terragrunt_linux_amd64
  mv terragrunt_linux_amd64 terragrunt
  chmod +x terragrunt 
  sudo mv terragrunt /usr/local/bin
  EOF
}

resource "aws_security_group" "alb" {
  vpc_id = aws_vpc.this.id

  ingress {
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "tcp"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "alb-${var.environment}sg"
    Project = "SPSkills"
    Environment = var.environment
  }
}

resource "aws_security_group" "webserver" {
  vpc_id = aws_vpc.this.id

  ingress {
    from_port       = 80
    to_port         = 80
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
    Name    = "webserver-${var.environment}-sg"
    Project = "SPSkills"
    Environment = var.environment
  }
}

resource "aws_security_group" "rds" {
  vpc_id = aws_vpc.this.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.webserver.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "db-${var.environment}-sg"
    Project = "SPSkills"
    Environment = var.environment
  }
}

resource "aws_launch_template" "this" {
  image_id               = var.amazon_linux_2023_ami
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.webserver.id]
  user_data              = base64encode(<<-EOF
          #!/bin/bash
          sudo yum update -y
          sudo yum install -y nginx
          sudo systemctl start nginx
          sudo systemctl enable nginx
          EOF
  )
  tags = {
    Name    = "webserver-${var.environment}-lt"
    Project = "SPSkills"
    Environment = var.environment
  }
}

resource "aws_autoscaling_group" "this" {
  vpc_zone_identifier = [aws_subnet.priv_a.id, aws_subnet.priv_b.id]
  desired_capacity    = var.instance_count
  max_size            = var.instance_count
  min_size            = var.instance_count
  target_group_arns   = [aws_lb_target_group.this.arn]

  launch_template {
    id = aws_launch_template.this.id
  }
}

resource "aws_lb" "this" {
  name = "ws-${var.environment}-lb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.pub_a.id, aws_subnet.pub_b.id]
  tags = {
    Name    = "ws-alb"
    Project = "SPSkills"
    Environment = var.environment
  }
}

resource "aws_lb_target_group" "this" {
  target_type = "instance"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name    = "ws-${var.environment}-tg"
    Project = "SPSkills"
    Environment = var.environment
  }
}

resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
  tags = {
    Name    = "ws-${var.environment}-listener"
    Project = "SPSkills"
    Environment = var.environment
  }
}

resource "aws_db_subnet_group" "this" {
  subnet_ids = [aws_subnet.priv_a.id, aws_subnet.priv_b.id]

  tags = {
    Name    = "ws-db-${var.environment}-subnet-group"
    Project = "SPSkills"
    Environment = var.environment
  }
}

resource "aws_db_instance" "this" {
  allocated_storage      = 10
  engine                 = "postgres"
  db_name                = var.environment
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  instance_class         = "db.t3.micro"
  db_subnet_group_name   = aws_db_subnet_group.this.name
  username               = "master"
  password               = "Skill53scs"

  tags = {
    Name = "db-${var.environment}"
    Project = "SPSkills"
    Environment = var.environment
  }
}