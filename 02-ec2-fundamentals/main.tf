# ─────────────────────────────────────────────────────────────────────────────
# main.tf
# EC2 Fundamentals — matches Stephane Maarek's EC2 section
# Covers: EC2 instance, security groups, key pair, elastic IP,
#         user data web server, IAM instance role
# ─────────────────────────────────────────────────────────────────────────────

# ─────────────────────────────────────────────────────────────────────────────
# TERRAFORM BLOCK
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# PROVIDER
# ─────────────────────────────────────────────────────────────────────────────

provider "aws" {
  region = var.aws_region

  # Applied automatically to every resource Terraform creates.
  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "Terraform"
    }
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# DATA SOURCES
# Read-only — fetches existing information from AWS.
# Creates nothing.
# ─────────────────────────────────────────────────────────────────────────────

# Fetches the default VPC that exists in every AWS account.
# WHY default VPC: Stephane uses it in his hands-on videos.
# Keeps things simple — no need to create a new VPC for this section.
# Every AWS account gets a default VPC pre-created in every region.
data "aws_vpc" "default" {
  default = true
}

# Fetches available AZs dynamically for the current region.
# WHY: Avoids hardcoding "eu-west-2a" — works in any region automatically.
# Returns a list e.g. ["eu-west-2a", "eu-west-2b", "eu-west-2c"]
data "aws_availability_zones" "available" {
  state = "available"
}

# Fetches the latest Amazon Linux 2023 AMI dynamically.
# WHY not hardcode: AMI IDs change per region and update regularly.
# ami-0abc123 in eu-west-2 is completely different from ami-0abc123 in us-east-1.
data "aws_ami" "amazon_linux" {
  most_recent = true

  # Only trust AMIs published by Amazon's official AWS account.
  # WHY: Anyone can publish public AMIs — including malicious ones.
  owners = ["amazon"]

  # al2023     = Amazon Linux 2023 (not Amazon Linux 2)
  # *          = version number — most_recent picks the latest
  # x86_64     = 64-bit Intel/AMD — matches t3.micro and most types
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  # HVM = Hardware Virtual Machine — modern standard.
  # All modern instance types (t3, m5 etc.) require HVM.
  # Without this filter you might get an older PV type that won't boot.
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# KEY PAIR
# Registers your public key with AWS.
# AWS places this key on the EC2 instance at launch.
# You SSH using the matching private key on your laptop.
#
# HOW TO GENERATE:
#   ssh-keygen -t rsa -b 4096 -f ~/.ssh/aws-dva-key
#   (press Enter twice for no passphrase)
#
# HOW TO SSH AFTER DEPLOY:
#   ssh -i ~/.ssh/aws-dva-key ec2-user@<public-ip>
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_key_pair" "main" {
  key_name = "${var.project_name}-key"

  # file() reads the public key from your local filesystem.
  # WHY file(): key never hardcoded in code — cleaner and safer.
  # The public key is safe to read — NEVER commit the private key.
  # Private key lives at: ~/.ssh/aws-dva-key (no .pub extension)
  public_key = file("~/.ssh/aws-dva-key.pub")
}

# ─────────────────────────────────────────────────────────────────────────────
# SECURITY GROUP
# Firewall rules for the EC2 instance.
# Security groups are STATEFUL — inbound response traffic is automatic.
# Default AWS behaviour: all inbound BLOCKED, all outbound ALLOWED.
#
# Classic ports to know for the exam:
#   22    → SSH  (Linux remote access)
#   80    → HTTP (web traffic)
#   443   → HTTPS (secure web traffic)
#   3389  → RDP (Windows remote access)
#   3306  → MySQL / Aurora
#   5432  → PostgreSQL
#   6379  → Redis
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-sg"
  description = "Allow SSH from my IP and HTTP from anywhere"

  # Attach to the default VPC.
  vpc_id = data.aws_vpc.default.id

  # ── INBOUND: SSH ──────────────────────────────────────────────────────────
  # Port 22 — restricted to YOUR IP only.
  # WHY not 0.0.0.0/0: opening SSH to the world means bots start
  # hammering your instance within minutes trying to brute force access.
  # Even with key pairs this is bad practice — fails security audits.
  # /32 = exactly one IP address — only your machine can connect.
  # Find your IP: curl ifconfig.me
  ingress {
    description = "SSH from my IP only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  # ── INBOUND: HTTP ─────────────────────────────────────────────────────────
  # Port 80 — open to the whole internet.
  # WHY 0.0.0.0/0: the web server should be accessible by anyone.
  # This is what allows browsers to reach the Apache web server.
  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ── OUTBOUND: ALL ─────────────────────────────────────────────────────────
  # Allow all outbound traffic.
  # WHY: Instance needs internet access for yum updates and
  # package installs during user_data execution.
  # protocol "-1" = all protocols. from/to 0 = all ports.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# IAM ROLE + INSTANCE PROFILE
# Allows the EC2 instance to call AWS services without access keys.
# Covers Stephane's "EC2 Instance Roles Demo" video.
#
# WHY a role instead of access keys:
#   Access keys on EC2 = credentials that can be stolen from the server
#   IAM role = temporary credentials auto-rotated by AWS — much safer
#
# This role gives the EC2 read-only access to SSM Parameter Store.
# WHY SSM: useful for fetching config/secrets at runtime.
# A realistic, common real-world use case for EC2 roles.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "ec2_role" {
  name        = "${var.project_name}-role"
  description = "Role for EC2 instance - SSM and CloudWatch access"

  # TRUST POLICY — who can assume this role.
  # Service = "ec2.amazonaws.com" means the EC2 service can assume it.
  # WHY sts:AssumeRole: STS (Security Token Service) issues the
  # temporary credentials when EC2 assumes the role.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEC2Assume"
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-role"
  }
}

# Attach SSM read access to the role.
# AmazonSSMManagedInstanceCore = allows EC2 Instance Connect
# and Systems Manager access — useful for connecting without SSH.
# This is what Stephane uses in his EC2 Instance Connect demo.
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach CloudWatch agent policy — allows EC2 to send logs and metrics.
# WHY: In production you always want EC2 logs going to CloudWatch.
# Covers the monitoring concepts from Stephane's section.
resource "aws_iam_role_policy_attachment" "cloudwatch_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Instance profile — the container that lets EC2 use the IAM role.
# EC2 cannot use a role directly — needs this wrapper.
# WHY: In the console AWS creates this automatically when you
# attach a role to EC2. In Terraform you must do it explicitly.
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-profile"
  role = aws_iam_role.ec2_role.name
}

# ─────────────────────────────────────────────────────────────────────────────
# EC2 INSTANCE
# The main resource — a virtual server running Apache web server.
# Covers: EC2 Basics, User Data Hands On, Instance Roles Demo.
#
# Purchasing option: On-Demand (default)
# WHY On-Demand for learning: no commitment, pay per second,
# terminate when done and pay nothing more.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_instance" "web" {
  # Which OS to boot — from our AMI data source above.
  # Dynamically fetched — always the latest Amazon Linux 2023.
  ami = data.aws_ami.amazon_linux.id

  # Server size — from var.instance_type (default t3.micro).
  # t3.micro = 2 vCPU, 1GB RAM — good for learning.
  # To change: terraform apply -var="instance_type=t3.small"
  instance_type = var.instance_type

  # Which key pair to use for SSH access.
  # References the key pair we registered above.
  # Without this you cannot SSH into the instance.
  key_name = aws_key_pair.main.key_name

  # Attach the security group — controls inbound/outbound traffic.
  # List because an EC2 can have multiple security groups.
  vpc_security_group_ids = [aws_security_group.ec2.id]

  # Attach the IAM instance profile — gives EC2 its role permissions.
  # This is what Stephane demonstrates in "EC2 Instance Roles Demo".
  # Without this the EC2 has no AWS permissions at all.
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  # Which AZ to launch in — first available AZ in the region.
  # data.aws_availability_zones.available.names[0] = "eu-west-2a"
  availability_zone = data.aws_availability_zones.available.names[0]

  # USER DATA — bash script that runs ONCE on first boot.
  # Covers "Create an EC2 Instance with EC2 User Data" hands-on video.
  # Installs and starts Apache web server automatically.
  # WHY Apache: gives us something to test — proves the instance
  # is running and the security group is configured correctly.
  user_data = <<-EOF
              #!/bin/bash
              # Update all packages — security best practice
              yum update -y
              # Install Apache web server
              yum install -y httpd
              # Start Apache immediately
              systemctl start httpd
              # Enable Apache to start automatically on reboot
              systemctl enable httpd
              # Write a simple webpage showing instance details
              # $(hostname -f) = the EC2's own DNS name at runtime
              # $(curl -s http://169.254.169.254/latest/meta-data/instance-id)
              # = fetches instance ID from the metadata service
              # 169.254.169.254 = EC2 metadata service IP — exam favourite
              echo "<h1>Hello from EC2</h1>
              <p>Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)</p>
              <p>Hostname: $(hostname -f)</p>
              <p>AZ: $(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)</p>" \
              > /var/www/html/index.html
              EOF

  # user_data_replace_on_change = true means if you change the
  # user_data script Terraform will terminate and recreate the instance.
  # WHY: user_data only runs on first boot — changing it on a running
  # instance has no effect without this setting.
  user_data_replace_on_change = true

  # Root EBS volume configuration.
  root_block_device {
    # Volume type — gp3 is newer and better than gp2.
    # gp3 = general purpose SSD — good for most workloads.
    volume_type = "gp3"

    # Root volume size in GB.
    # 8GB is the Amazon Linux 2023 minimum — enough for learning.
    volume_size = 30

    # Encrypt the root volume — security best practice.
    # WHY: Required for hibernate. Also good practice in general.
    # Uses the default AWS managed key — no extra cost.
    encrypted = true

    # false = keep the EBS volume when the instance is terminated.
    # true  = delete the EBS volume when terminated (default).
    # WHY true for learning: cleans up automatically — no orphaned
    # volumes sitting around costing money after terraform destroy.
    delete_on_termination = true
  }

  tags = {
    Name = "${var.project_name}-web"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# ELASTIC IP
# A static public IP that never changes — even after stop/start.
# WHY: Default EC2 public IP changes every time you stop and start.
# Elastic IP stays fixed — your application URLs never break.
#
# EXAM NOTE: Elastic IP is FREE only when attached to a RUNNING instance.
# Stopped instance + attached EIP = charged.
# Unattached EIP = charged.
# AWS charges to discourage hoarding of public IPs.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_eip" "web" {
  # Attach this Elastic IP to our EC2 instance.
  instance = aws_instance.web.id

  # domain = "vpc" is required for all modern EIPs.
  # WHY: The old EC2-Classic network is retired — all EIPs now live in VPC.
  domain = "vpc"

  # depends_on ensures the internet gateway exists before
  # the EIP is created — EIPs need an IGW to route traffic.
  # WHY explicit depends_on: Terraform can't infer this dependency
  # automatically because there's no direct reference between them.
  depends_on = [data.aws_vpc.default]

  tags = {
    Name = "${var.project_name}-eip"
  }
}