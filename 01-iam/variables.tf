variable "aws_region" {
  description = "AWS region for the provider"
  type        = string
  default     = "eu-west-2"
}

variable "project_name" {
  description = "Prefix for all resource names"
  type        = string
  default     = "dva-iam"
}

variable "demo_bucket_name" {
  description = "S3 bucket name to grant read access to in the custom policy"
  type        = string
  default     = "dva-demo-bucket"
}

variable "account_alias" {
  description = "AWS account alias — must be globally unique across all AWS accounts"
  type        = string
  default     = "aws-dva-hamed"

  # If this fails with "alias already exists" — someone took it.
  # Try: hamed-aws-dva, hamed-dva-study, your-name-aws-2024
}