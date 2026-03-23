# ── LOGIN URL ─────────────────────────────────────────────────────────────────
output "console_login_url" {
  description = "Custom console login URL using account alias"
  value       = "https://${var.account_alias}.signin.aws.amazon.com/console"
}

# ── ACCOUNT ID ────────────────────────────────────────────────────────────────
output "account_id" {
  description = "AWS account ID"
  value       = data.aws_caller_identity.current.account_id
}

# ── USER PASSWORDS ────────────────────────────────────────────────────────────
# sensitive = true — won't print in terminal during apply.
# Run: terraform output alice_password to see it.

output "alice_password" {
  description = "Alice's initial console password — must change on first login"
  value       = aws_iam_user_login_profile.alice.password
  sensitive   = true
}

output "bob_password" {
  description = "Bob's initial console password — must change on first login"
  value       = aws_iam_user_login_profile.bob.password
  sensitive   = true
}

output "carol_password" {
  description = "Carol's initial console password — must change on first login"
  value       = aws_iam_user_login_profile.carol.password
  sensitive   = true
}

# ── ROLE ARN ──────────────────────────────────────────────────────────────────
output "ec2_role_arn" {
  description = "EC2 S3 role ARN — attach to EC2 instances that need S3 access"
  value       = aws_iam_role.ec2_s3_role.arn
}

# ── INSTANCE PROFILE ──────────────────────────────────────────────────────────
output "instance_profile_name" {
  description = "Instance profile name — use this when launching EC2 instances"
  value       = aws_iam_instance_profile.ec2_s3_profile.name
}