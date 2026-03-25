variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-west-2"
}

variable "project_name" {
  description = "Prefix for all resource names"
  type        = string
  default     = "dva-ec2-fundamentals"
}

variable "my_ip" {
    description = "My Ip Addres to ssh into ec2 instance"
    type = string
    default = "94.175.96.115/32"
  
}

variable "instance_type" {
    description = "My Ip Addres to ssh into ec2 instance"
    type = string
    default = "t3.micro"
  
}