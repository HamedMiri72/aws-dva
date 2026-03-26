# ─────────────────────────────────────────────────────────────────────────────
# outputs.tf
# Values printed after terraform apply — tells you where everything is.
# ─────────────────────────────────────────────────────────────────────────────

# ── INSTANCE DETAILS ──────────────────────────────────────────────────────────

output "instance_id" {
  description = "EC2 instance ID — use this in AWS console to find your instance"
  value       = aws_instance.web.id
}

output "instance_type" {
  description = "EC2 instance type that was launched"
  value       = aws_instance.web.instance_type
}

output "availability_zone" {
  description = "Which AZ the instance launched in"
  value       = aws_instance.web.availability_zone
}

output "ami_id" {
  description = "AMI ID that was used — confirms which Amazon Linux version"
  value       = aws_instance.web.ami
}

# ── NETWORKING ────────────────────────────────────────────────────────────────

output "elastic_ip" {
  description = "Static public IP — use this to access the web server and SSH"
  value       = aws_eip.web.public_ip
}

output "website_url" {
  description = "Paste this in your browser to see the Apache web server"
  value       = "http://${aws_eip.web.public_ip}"
}

output "ssh_command" {
  description = "Run this command to SSH into the instance"
  value       = "ssh -i ~/.ssh/aws-dva-key ec2-user@${aws_eip.web.public_ip}"
}

# ── IAM ───────────────────────────────────────────────────────────────────────

output "iam_role_arn" {
  description = "IAM role ARN attached to the EC2 instance"
  value       = aws_iam_role.ec2_role.arn
}

output "instance_profile_name" {
  description = "Instance profile name — visible in EC2 console under Security"
  value       = aws_iam_instance_profile.ec2_profile.name
}

# ── KEY PAIR ──────────────────────────────────────────────────────────────────

output "key_pair_name" {
  description = "Key pair name registered in AWS"
  value       = aws_key_pair.main.key_name
}