resource "aws_s3_bucket" "configs" {
  bucket = "${var.project_name}-configs-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "${var.project_name}-configs"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_s3_bucket_versioning" "configs" {
  bucket = aws_s3_bucket.configs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "configs" {
  bucket = aws_s3_bucket.configs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

data "aws_caller_identity" "current" {}