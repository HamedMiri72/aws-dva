# ─────────────────────────────────────────────────────────────────────────────
# TERRAFORM BLOCK
# Configures Terraform itself — version and provider requirements.
# ─────────────────────────────────────────────────────────────────────────────

terraform {

  # Minimum Terraform CLI version required.
  # WHY: Prevents someone running an old version that might
  # behave differently or not support syntax we've used.
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      # Official HashiCorp AWS provider.
      # Gives Terraform knowledge of all AWS resources.
      source  = "hashicorp/aws"

      # Lock to major version 5.x — blocks breaking changes.
      version = "~> 5.0"
    }
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# PROVIDER
# Tells Terraform which region to use and applies default tags.
# NOTE: IAM resources are GLOBAL — they don't live in a specific region.
# The region here is just for the API endpoint — use your nearest.
# ─────────────────────────────────────────────────────────────────────────────

provider "aws" {
  region = var.aws_region

  # Applied automatically to every resource Terraform creates.
  # WHY: Track ownership and management method without repeating
  # tags in every resource block.
  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "Terraform"
    }
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# DATA SOURCE — Current AWS Account Identity
# Reads information about the authenticated AWS account.
# Creates nothing — read only.
# WHY: We use the account ID in outputs to display the login URL.
# ─────────────────────────────────────────────────────────────────────────────

data "aws_caller_identity" "current" {}

# ─────────────────────────────────────────────────────────────────────────────
# IAM GROUPS
# Groups are containers for users — attach policies to groups not users.
# WHY: Add a new user → put them in a group → they inherit all permissions.
# No need to manage policies per individual user — scales cleanly.
# IAM groups are GLOBAL — not tied to any region.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_iam_group" "developers" {
  # Software developers — full AWS access except IAM and billing.
  # WHY not AdministratorAccess: developers don't need to manage
  # other users or change account-level permissions.
  name = "developers"
}

resource "aws_iam_group" "devops" {
  # Infrastructure/DevOps engineers — full administrator access.
  # WHY AdministratorAccess: DevOps needs to create roles,
  # manage users, configure billing, set up CI/CD pipelines.
  name = "devops"
}

resource "aws_iam_group" "readonly" {
  # Auditors, managers, stakeholders — view everything, change nothing.
  # WHY: Gives visibility without the ability to accidentally break things.
  name = "readonly"
}

# ─────────────────────────────────────────────────────────────────────────────
# GROUP POLICY ATTACHMENTS — AWS Managed Policies
# AWS managed policies are pre-built by Amazon and maintained by them.
# They update automatically when AWS adds new services.
# WHY managed over custom here: these are broad permission sets
# that would be tedious to write manually and maintain over time.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_iam_group_policy_attachment" "developers_policy" {
  group = aws_iam_group.developers.name

  # PowerUserAccess = everything EXCEPT IAM and AWS Organizations.
  # Developers can create EC2s, S3 buckets, Lambdas, RDS etc.
  # They cannot create users, change permissions, or modify billing.
  # arn:aws:iam::aws:policy/ = prefix for all AWS managed policies.
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

resource "aws_iam_group_policy_attachment" "devops_policy" {
  group = aws_iam_group.devops.name

  # AdministratorAccess = literally everything including IAM.
  # Effect: Allow, Action: *, Resource: * — no restrictions at all.
  # Only assign to people who absolutely need full control.
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_group_policy_attachment" "readonly_policy" {
  group = aws_iam_group.readonly.name

  # ReadOnlyAccess = view all resources across all services.
  # Zero write access — cannot create, modify, or delete anything.
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# ─────────────────────────────────────────────────────────────────────────────
# IAM USERS
# One user per job role — each placed in the appropriate group.
# In a real company you'd have many users but the pattern is identical.
# IAM users are GLOBAL — not tied to any region.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_iam_user" "alice" {
  name = "alice"

  # Allows Terraform to destroy this user even if it has
  # login profiles, access keys, or group memberships attached.
  # WHY: Without this, terraform destroy fails with a dependency
  # error if the user has anything attached — very common gotcha.
  force_destroy = true

  tags = { Role = "developer" }
}

resource "aws_iam_user" "bob" {
  name          = "bob"
  force_destroy = true
  tags          = { Role = "devops" }
}

resource "aws_iam_user" "carol" {
  name          = "carol"
  force_destroy = true
  tags          = { Role = "auditor" }
}

# ─────────────────────────────────────────────────────────────────────────────
# GROUP MEMBERSHIPS
# Explicitly adds each user to their group.
# WHY explicit: creating a user does not automatically add them to a group.
# The membership resource is the glue between user and group.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_iam_user_group_membership" "alice_membership" {
  user = aws_iam_user.alice.name

  # List — a user CAN belong to multiple groups simultaneously.
  # All group policies are merged and applied together.
  # Explicit deny in any policy overrides allow in all others.
  groups = [aws_iam_group.developers.name]
}

resource "aws_iam_user_group_membership" "bob_membership" {
  user   = aws_iam_user.bob.name
  groups = [aws_iam_group.devops.name]
}

resource "aws_iam_user_group_membership" "carol_membership" {
  user   = aws_iam_user.carol.name
  groups = [aws_iam_group.readonly.name]
}

# ─────────────────────────────────────────────────────────────────────────────
# LOGIN PROFILES — Console Passwords
# Creates an initial password for AWS console access.
# Terraform generates a random password — user changes it on first login.
# WHY password_reset_required: security best practice — you set initial,
# they set their real one. You never know their final password.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_iam_user_login_profile" "alice" {
  user                    = aws_iam_user.alice.name
  password_reset_required = true
}

resource "aws_iam_user_login_profile" "bob" {
  user                    = aws_iam_user.bob.name
  password_reset_required = true
}

resource "aws_iam_user_login_profile" "carol" {
  user                    = aws_iam_user.carol.name
  password_reset_required = true
}

# ─────────────────────────────────────────────────────────────────────────────
# CUSTOM IAM POLICY
# Written from scratch — specific bucket, specific actions only.
# This is LEAST PRIVILEGE — minimum permissions needed, nothing more.
# WHY custom over managed: AWS managed S3 policies give access to
# ALL buckets. We only want access to ONE specific bucket.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_iam_policy" "s3_read_only" {
  name        = "s3-read-only-policy"
  description = "Read-only access to the dva-demo-bucket S3 bucket only"

  # jsonencode() converts a Terraform map to a JSON string.
  # WHY jsonencode over raw JSON: no escaped quotes, cleaner syntax,
  # Terraform validates the structure before applying.
  policy = jsonencode({

    # Policy language version — ALWAYS "2012-10-17".
    # This is not a date you pick — it is a fixed string identifier.
    # Never change this value.
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "AllowListBucket"
        Effect = "Allow"

        # s3:ListBucket = see the list of files in the bucket.
        # Without this the user can download files but can't see
        # what files exist — useless on its own.
        Action = ["s3:ListBucket"]

        # ListBucket applies to the BUCKET ITSELF.
        # No trailing /* — the bucket is the resource, not the objects.
        # This is the most common S3 policy mistake on the exam.
        Resource = "arn:aws:s3:::${var.demo_bucket_name}"
      },
      {
        Sid    = "AllowGetObject"
        Effect = "Allow"

        # s3:GetObject = download/read individual files.
        Action = ["s3:GetObject"]

        # GetObject applies to OBJECTS INSIDE the bucket.
        # Needs /* to cover all objects — without it the action
        # has no resources to apply to and effectively does nothing.
        # WHY different resource from ListBucket: bucket ≠ objects.
        # They are separate resource types in AWS's permission model.
        Resource = "arn:aws:s3:::${var.demo_bucket_name}/*"
      }
    ]
  })

  tags = { Name = "s3-read-only-policy" }
}

# ─────────────────────────────────────────────────────────────────────────────
# ATTACH CUSTOM POLICY TO DEVELOPERS GROUP
# All developers get read access to the demo bucket.
# WHY attach to group not user: one attachment covers all current
# and future developers — no per-user management needed.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_iam_group_policy_attachment" "developers_s3" {
  group      = aws_iam_group.developers.name
  policy_arn = aws_iam_policy.s3_read_only.arn
}

# ─────────────────────────────────────────────────────────────────────────────
# IAM ROLE — EC2 S3 Read Role
# Allows EC2 instances to read from S3 without any access keys.
# A role has TWO required parts:
#   1. Trust Policy    → WHO can assume this role (ec2.amazonaws.com)
#   2. Permission Policy → WHAT they can do (read S3)
# Both must exist — a role without a trust policy can't be used.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "ec2_s3_role" {
  name        = "ec2-s3-read-role"
  description = "Allows EC2 instances to read from S3 — no access keys needed"

  # TRUST POLICY — defines who can assume this role.
  # This is the "who can wear this hat" definition.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEC2Assume"
        Effect = "Allow"

        # sts:AssumeRole = the action of taking on a role's permissions.
        # STS = Security Token Service — issues temporary credentials.
        # WHY sts not iam: AssumeRole is an STS action not an IAM action.
        Action = "sts:AssumeRole"

        # Principal = who is allowed to assume this role.
        # Service = an AWS service (not a user or role).
        # "ec2.amazonaws.com" = the EC2 service specifically.
        # WHY Service not AWS: AWS principal = IAM users/roles.
        # Service principal = AWS services like EC2, Lambda, RDS.
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = { Name = "ec2-s3-read-role" }
}

# ─────────────────────────────────────────────────────────────────────────────
# ATTACH PERMISSION POLICY TO ROLE
# Defines WHAT the role can do once assumed.
# We reuse the custom S3 read policy from above.
# WHY reuse: one policy, attached to both group AND role.
# Update the policy once — changes apply everywhere it is attached.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_iam_role_policy_attachment" "ec2_s3_policy" {
  role       = aws_iam_role.ec2_s3_role.name
  policy_arn = aws_iam_policy.s3_read_only.arn
}

# ─────────────────────────────────────────────────────────────────────────────
# INSTANCE PROFILE
# A container that allows EC2 to use an IAM role.
# EC2 cannot use a role directly — it needs this wrapper.
# WHY this extra step: instance profiles are how EC2 receives
# temporary STS credentials from the role at boot time.
# In the console AWS creates this automatically when you attach a role.
# In Terraform you must create it explicitly — easy to forget.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_iam_instance_profile" "ec2_s3_profile" {
  name = "ec2-s3-read-profile"

  # Which role this profile wraps.
  # When you attach this profile to an EC2, it gets the role's permissions.
  role = aws_iam_role.ec2_s3_role.name
}

# ─────────────────────────────────────────────────────────────────────────────
# ACCOUNT PASSWORD POLICY
# Applies to the ENTIRE AWS account — all IAM users follow these rules.
# Only ONE password policy per account — this replaces the AWS default.
# NOTE: Does NOT affect root account, access keys, or MFA devices.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_iam_account_password_policy" "main" {

  # Minimum password length — AWS requires at least 8.
  # 12 is industry best practice — strong enough, not annoying.
  minimum_password_length = 12

  # Complexity requirements — forces stronger passwords.
  # WHY all four: makes brute force attacks significantly harder.
  require_uppercase_characters = true
  require_lowercase_characters = true
  require_numbers              = true
  require_symbols              = true

  # Prevent reusing recent passwords.
  # WHY: Without this users rotate between two passwords forever,
  # defeating the purpose of password rotation entirely.
  password_reuse_prevention = 5

  # Force password change every 90 days.
  # 0 = never expires. 90 = industry standard rotation period.
  # WHY 90 not shorter: balance between security and user experience.
  max_password_age = 90

  # Let users change their own password.
  # WHY true: if false only admins can change passwords —
  # creates a support burden and is a security anti-pattern.
  allow_users_to_change_password = true

  # false = users with expired passwords can still log in to change it.
  # true  = users with expired passwords are completely locked out.
  # WHY false: hard_expiry = true causes lockouts that require admin
  # intervention — creates unnecessary support overhead.
  hard_expiry = false
}

# ─────────────────────────────────────────────────────────────────────────────
# ACCOUNT ALIAS
# Creates a friendly console login URL instead of the 12-digit account ID.
# Before: https://123456789012.signin.aws.amazon.com/console
# After:  https://aws-dva-hamed.signin.aws.amazon.com/console
# Must be globally unique across ALL AWS accounts worldwide.
# Only lowercase letters, numbers, and hyphens allowed.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_iam_account_alias" "main" {
  # Comes from var.account_alias in variables.tf.
  # If you get "alias already exists" — someone took it.
  # Add something unique: your-name-aws-dva, hamed-dva-2024 etc.
  account_alias = var.account_alias
}