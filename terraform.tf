terraform {
  backend "s3" {
    bucket = "opentofu"
    key = "test/opentofu.tfstate"
    #dynamodb_table = "opentofu-lock-table"
    region = "us-east-2"
  }
}
