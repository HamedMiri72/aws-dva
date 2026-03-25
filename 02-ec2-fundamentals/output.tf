output "instance_public_ip" {
  description = "Public IP to SSH into and visit in browser"
  value       = aws_instance.web.public_ip
}

output "ssh_command" {
  description = "Ready-to-run SSH command"
  value       = "ssh -i ~/.ssh/aws-dva-key ec2-user@${aws_instance.web.public_ip}"
}

output "website_url" {
  description = "URL to see the web server"
  value       = "http://${aws_instance.web.public_ip}"
}