terraform {
  required_version = "~> 0.11.14"
}

provider "aws" {
  version             = "~> 2.29"
  region              = "${var.region}"
  allowed_account_ids = ["${var.aws_account_id}"]
}
