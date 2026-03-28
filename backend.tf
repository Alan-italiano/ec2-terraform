# ---------------------------------------------------------------------------
# Backend S3 — estado remoto do Terraform
#
# Pré-requisitos (criar manualmente UMA VEZ antes do primeiro `terraform init`):
#   aws s3api create-bucket --bucket <BUCKET_ESTADO> --region us-east-1
#   aws s3api put-bucket-versioning --bucket <BUCKET_ESTADO> \
#       --versioning-configuration Status=Enabled
#   aws dynamodb create-table --table-name terraform-locks \
#       --attribute-definitions AttributeName=LockID,AttributeType=S \
#       --key-schema AttributeName=LockID,KeyType=HASH \
#       --billing-mode PAY_PER_REQUEST
#
# Substitua os valores entre < > e descomente o bloco abaixo.
# ---------------------------------------------------------------------------

# terraform {
#   backend "s3" {
#     bucket         = "<BUCKET_ESTADO>"
#     key            = "ec2-terraform/terraform.tfstate"
#     region         = "us-east-1"
#     encrypt        = true
#     dynamodb_table = "terraform-locks"
#   }
# }
