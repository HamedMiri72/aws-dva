# ─────────────────────────────────────────────────────────────────────────────
# variables.tf
# ─────────────────────────────────────────────────────────────────────────────

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-west-2"
}

variable "project_name" {
  description = "Prefix for all resource names and tags"
  type        = string
  default     = "dva-ec2"
}

variable "instance_type" {
  description = "EC2 instance size — CPU and RAM"
  type        = string
  default     = "t3.micro"

  # t3.micro  = 2 vCPU, 1GB  RAM — learning, free tier eligible on t2
  # t3.small  = 2 vCPU, 2GB  RAM — small apps
  # t3.medium = 2 vCPU, 4GB  RAM — medium apps
  # t3 is newer generation than t2 — better performance, same price range
}

variable "my_ip" {
  description = "Your public IP for SSH access — format: x.x.x.x/32"
  type        = string
  default     = "94.175.96.115/32"

  # Find your IP: curl ifconfig.me
  # Update to: "YOUR_IP/32" e.g. "82.34.12.45/32"
  # WHY /32: exactly one IP — only your machine can SSH in
  # Leaving as 0.0.0.0/0 works but opens SSH to the whole internet
  # Always restrict in production — fails security audits if open
}