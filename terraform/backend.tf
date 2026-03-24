terraform {
  backend "s3" {
    bucket         = "mjcastro-devopslab-tfstate"
    key            = "devopslab/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
