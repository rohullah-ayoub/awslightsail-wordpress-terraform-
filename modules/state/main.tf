provider "aws" {
  region = "${var.aws_region}"
}

resource "aws_s3_bucket" "state_bucket" {
  bucket        = "${var.project_prefix}-remote-state"
  acl           = "private"
  force_destroy = false

  versioning {
    enabled = true
  }

  logging {
    target_bucket = "${aws_s3_bucket.tf_state_access_log_bucket.id}"
    target_prefix = "state_log/"
  }
}

resource "aws_s3_bucket" "tf_state_access_log_bucket" {
  bucket        = "${var.project_prefix}-state-access-logs-bucket"
  acl           = "log-delivery-write"
  force_destroy = true
}

resource "aws_dynamodb_table" "lock_table" {
  name           = "${var.project_prefix}-state-lock-table"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
