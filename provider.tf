terraform {
  required_version = "~> 0.13.2"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.4.0"
      region  = var.region
    }
  }
}
