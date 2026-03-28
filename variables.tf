variable "aws_region" {
  description = "Região AWS onde os recursos serão criados"
  type        = string
  default     = "us-east-1"
}

variable "instance_name" {
  description = "Nome da instância EC2 (usado também como prefixo dos recursos)"
  type        = string
  default     = "my-ec2"
}

variable "instance_type" {
  description = "Tipo da instância EC2"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "Nome do par de chaves SSH que será criado na AWS e salvo localmente"
  type        = string
  default     = "ec2-key"
}

variable "vpc_cidr" {
  description = "CIDR block da VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block da subnet pública"
  type        = string
  default     = "10.0.1.0/24"
}

variable "allowed_ssh_cidrs" {
  description = "Lista de CIDRs permitidos para acesso SSH (use seu IP público com /32)"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Restrinja em produção: ["SEU_IP/32"]
}

variable "ssh_keys_bucket" {
  description = "Nome globalmente único do bucket S3 onde a chave privada SSH será armazenada"
  type        = string
  default     = "ec2-ssh-keys"
}

variable "ssh_keys_prefix" {
  description = "Prefixo (pasta) dentro do bucket S3 onde a chave privada será armazenada"
  type        = string
  default     = "keys"
}
