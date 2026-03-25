terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "Terraform"
    }
  }
}

data "aws_caller_identity" "current" {
  
}

data "aws_availability_zones" "available" {

    state = "available"
  
}

data "aws_vpc" "default" {
    default = true
  
}

data "aws_ami" "amazon_linux" {

    most_recent = true

    owners = ["amazon"]

    filter {
      name = "name"
      values = ["al2023-ami-*-x86_64"]
    }

    filter {
        name   = "virtualization-type"
        values = ["hvm"]
    }
}

resource "aws_key_pair" "main" {
  key_name   = "${var.project_name}-key"
  public_key = file("~/.ssh/aws-dva-key.pub")
}

resource "aws_security_group" "ec2-policy" {

    name = "${var.project_name}-ec2-sg"
    description = "Ec2 security gropu allowing ssh on port 22 and http on port 80"

    vpc_id = data.aws_vpc.default.id

    ingress  {
        description = "SSH from my IP"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"

        cidr_blocks = [var.my_ip]
    }

    ingress {
        description = "HTTP from anywhere in the net"
        from_port = 80
        to_port = 80
        protocol = "tcp"

        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "${var.project_name}-sg"
    }

}



resource "aws_instance" "ec2-instance" {

    ami = data.aws_ami.amazon_linux.id
    instance_type = var.instance_type

    key_name = aws_key_pair.main.key_name

    vpc_security_group_ids = [aws_security_group.ec2-policy.id]

    associate_public_ip_address = true

    user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<h1>Hello from Terraform — $(hostname -f)</h1>" > /var/www/html/index.html
  EOF

  user_data_replace_on_change = true

  tags = {
    Name = "${var.project_name}-web"
  }
}



