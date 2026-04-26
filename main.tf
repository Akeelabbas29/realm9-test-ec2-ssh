resource "random_pet" "suffix" {
  length    = 2
  separator = "-"
}

locals {
  resource_name = "${var.project_name}-${random_pet.suffix.id}"
}

# Latest Amazon Linux 2023 AMI for x86_64
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# Default VPC — simplest path; assumes the account still has one
data "aws_vpc" "default" {
  default = true
}

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "this" {
  key_name   = local.resource_name
  public_key = tls_private_key.ssh.public_key_openssh

  tags = {
    Name      = local.resource_name
    ManagedBy = "Terraform"
    Project   = "realm9-test"
  }
}

resource "aws_security_group" "ssh" {
  name        = "${local.resource_name}-sg"
  description = "Realm9 EC2+SSH test — allow inbound 22"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "${local.resource_name}-sg"
    ManagedBy = "Terraform"
    Project   = "realm9-test"
  }
}

resource "aws_instance" "this" {
  ami                         = data.aws_ssm_parameter.al2023_ami.value
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.this.key_name
  vpc_security_group_ids      = [aws_security_group.ssh.id]
  associate_public_ip_address = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 only
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name      = local.resource_name
    ManagedBy = "Terraform"
    Project   = "realm9-test"
  }
}
