output "vpc_id" {
  description = "ID da VPC criada"
  value       = aws_vpc.main.id
}

output "subnet_id" {
  description = "ID da subnet pública criada"
  value       = aws_subnet.public.id
}

output "elastic_ips" {
  description = "Elastic IPs públicos das instâncias"
  value       = aws_eip.main[*].public_ip
}

output "instance_ids" {
  description = "IDs das instâncias EC2"
  value       = aws_instance.main[*].id
}

output "ami_used" {
  description = "AMI utilizada"
  value       = data.aws_ami.ubuntu.id
}

output "private_key_s3_uri" {
  description = "URI S3 da chave privada SSH"
  value       = "s3://${aws_s3_bucket.ssh_keys.id}/${var.ssh_keys_prefix}/${var.key_name}.pem"
}

output "private_key_download_command" {
  description = "Comando para baixar a chave privada do S3"
  value       = "aws s3 cp s3://${aws_s3_bucket.ssh_keys.id}/${var.ssh_keys_prefix}/${var.key_name}.pem ./${var.key_name}.pem && chmod 600 ./${var.key_name}.pem"
}

output "ssh_connection_strings" {
  description = "Strings de conexão SSH prontas para uso (após baixar a chave)"
  value = [
    for eip in aws_eip.main : "ssh -i ./${var.key_name}.pem ubuntu@${eip.public_ip}"
  ]
}

output "ssh_known_hosts" {
  description = "Resultado do ssh-keyscan dos Elastic IPs (chaves públicas dos hosts)"
  value       = data.external.ssh_keyscan.result.known_hosts
}
