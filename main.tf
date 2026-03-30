terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ---------------------------------------------------------------------------
# Chave SSH — gerada pelo Terraform e armazenada no S3
# ---------------------------------------------------------------------------
resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_s3_bucket" "ssh_keys" {
  bucket        = var.ssh_keys_bucket
  force_destroy = true

  tags = merge(local.common_tags, { Name = var.ssh_keys_bucket })
}

resource "aws_s3_bucket_versioning" "ssh_keys" {
  bucket = aws_s3_bucket.ssh_keys.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ssh_keys" {
  bucket = aws_s3_bucket.ssh_keys.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "ssh_keys" {
  bucket = aws_s3_bucket.ssh_keys.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "private_key" {
  bucket                 = aws_s3_bucket.ssh_keys.id
  key                    = "${var.ssh_keys_prefix}/${var.key_name}.pem"
  content                = tls_private_key.ec2_key.private_key_pem
  server_side_encryption = "aws:kms"

  tags = local.common_tags
}

resource "aws_key_pair" "ec2_key_pair" {
  key_name   = var.key_name
  public_key = tls_private_key.ec2_key.public_key_openssh

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# Rede — VPC dedicada com subnet pública
# ---------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, { Name = "${var.instance_name}-vpc" })
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, { Name = "${var.instance_name}-subnet-public" })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, { Name = "${var.instance_name}-igw" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, { Name = "${var.instance_name}-rt-public" })
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ---------------------------------------------------------------------------
# Security Group — SSH aberto (ajuste o CIDR conforme necessário)
# ---------------------------------------------------------------------------
resource "aws_security_group" "ec2_sg" {
  name        = "${var.instance_name}-sg"
  description = "Allow SSH inbound"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.instance_name}-sg" })
}

# ---------------------------------------------------------------------------
# AMI — Ubuntu 24.04 LTS (mais recente)
# ---------------------------------------------------------------------------
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ---------------------------------------------------------------------------
# EC2 Instances — 3 instâncias na mesma subnet pública
# ---------------------------------------------------------------------------
resource "aws_instance" "main" {
  count = 3

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.ec2_key_pair.key_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
    encrypted             = true
  }

  tags = merge(local.common_tags, { Name = "${var.instance_name}-${count.index + 1}" })
}

# ---------------------------------------------------------------------------
# Elastic IPs — um por instância
# ---------------------------------------------------------------------------
resource "aws_eip" "main" {
  count    = 3
  instance = aws_instance.main[count.index].id
  domain   = "vpc"

  tags = merge(local.common_tags, { Name = "${var.instance_name}-eip-${count.index + 1}" })
}

# ---------------------------------------------------------------------------
# Locals
# ---------------------------------------------------------------------------
locals {
  common_tags = {
    Project     = var.instance_name
    ManagedBy   = "terraform"
  }
}

# ---------------------------------------------------------------------------
# ssh-keyscan — coleta as chaves públicas dos hosts via Elastic IPs
# ---------------------------------------------------------------------------
data "external" "ssh_keyscan" {
  program = [
    "bash", "-c",
    <<-EOT
      IPS=$(cat | python3 -c "import sys,json; print(' '.join(json.load(sys.stdin)['ips'].split(',')))")
      RESULT=$(ssh-keyscan $IPS 2>/dev/null)
      python3 -c "import sys,json; s=sys.stdin.read(); print(json.dumps({'known_hosts': s}))" <<< "$RESULT"
    EOT
  ]

  query = {
    ips = join(",", aws_eip.main[*].public_ip)
  }

  depends_on = [aws_eip.main]
}
