remote_state {
  backend = "s3"
  config = {
    encrypt        = true
    bucket         = "ws-bucket-terraform-state"
    key            = "dev/webapp/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
  }
}

terraform {
  source = "../../modules/webapp"
}

inputs = {
  environment           = "dev"
  instance_count        = 1
  vpc_name              = "ws"
  vpc_cidr              = "10.50.0.0/16"
  pub_a_cidr            = "10.50.1.0/24"
  pub_b_cidr            = "10.50.2.0/24"
  priv_a_cidr           = "10.50.10.0/24"
  priv_b_cidr           = "10.50.11.0/24"
  az_a                  = "us-east-1a"
  az_b                  = "us-east-1b"
  amazon_linux_2023_ami = "ami-052064a798f08f0d3"
}