output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.this.id
}

output "public_ip" {
  description = "Public IPv4 address of the EC2 instance"
  value       = aws_instance.this.public_ip
}

output "public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.this.public_dns
}

output "ssh_username" {
  description = "Default SSH username for Amazon Linux 2023"
  value       = "ec2-user"
}

output "region" {
  description = "AWS region"
  value       = var.aws_region
}

output "key_name" {
  description = "Name of the EC2 key pair"
  value       = aws_key_pair.this.key_name
}

# THE multi-line sensitive output — saving this to a file is the test.
output "private_key_pem" {
  description = "RSA private key in PEM format. Save to a file with chmod 600, then ssh -i."
  value       = tls_private_key.ssh.private_key_pem
  sensitive   = true
}

output "ssh_command" {
  description = "Pre-formatted SSH command (after saving private_key_pem to /tmp/realm9-test.pem)"
  value       = "ssh -i /tmp/realm9-test.pem -o StrictHostKeyChecking=no ec2-user@${aws_instance.this.public_ip}"
}
