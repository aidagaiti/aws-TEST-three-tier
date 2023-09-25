terraform {
  backend "s3" {
    bucket = "aws-test-three-tier"
    key    = "path/to/my/key"
    region = "us-east-1"
    #dynamodb_table = "terraform-state"
  }
}