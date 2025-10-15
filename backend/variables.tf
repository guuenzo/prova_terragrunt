variable "aws_region" {
  default = "us-east-1"
}

variable "bucket_name" {
  default = "ws-bucket-terraform-state-2"
}

variable "dynamodb_table_name" {
  default = "terraform-state-lock"
}