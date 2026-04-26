variable "aws_region" {
  description = "AWS region to deploy the EC2 instance into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Used as a prefix for resource names. A random suffix is appended for uniqueness across re-applies."
  type        = string
  default     = "realm9-test-ec2"
}

variable "instance_type" {
  description = "EC2 instance type. t3.micro is free-tier eligible."
  type        = string
  default     = "t3.micro"
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH in. Default 0.0.0.0/0 (open) for the test — restrict to your IP for any non-throwaway use."
  type        = string
  default     = "0.0.0.0/0"
}
