resource "random_pet" "suffix" {
  length    = 2
  separator = "-"
}

locals {
  resource_name = "${var.project_name}-${random_pet.suffix.id}"
  common_tags = {
    Name      = local.resource_name
    ManagedBy = "Terraform"
    Project   = "realm9-test"
  }
}

# Latest Amazon Linux 2023 AMI for x86_64
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# Reuse the default VPC + a default subnet in the first AZ.
# Avoids hitting the per-region VPC quota; works in any region that
# still has its default VPC (most regions do; us-east-1 in this account
# does not, which is why the project defaults to eu-west-2).
data "aws_vpc" "default" {
  default = true
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_subnets" "default_vpc" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Pick the first subnet in the default VPC for the instance
data "aws_subnet" "selected" {
  id = data.aws_subnets.default_vpc.ids[0]
}

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "this" {
  key_name   = local.resource_name
  public_key = tls_private_key.ssh.public_key_openssh
  tags       = local.common_tags
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

  tags = merge(local.common_tags, { Name = "${local.resource_name}-sg" })
}

resource "aws_instance" "this" {
  ami                         = data.aws_ssm_parameter.al2023_ami.value
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.this.key_name
  subnet_id                   = data.aws_subnet.selected.id
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

  tags = local.common_tags
}
