##############################################################################
# s3-buckets.tf
# Demonstrates creating and configuring S3 buckets with Terraform.
# This mirrors the hands-on work from "Create S3 Buckets with Terraform".
#
# Workflow:
#   terraform init   → download AWS provider, initialise state
#   terraform plan   → preview changes (no AWS resources created yet)
#   terraform apply  → create/update real AWS resources
#   terraform destroy → tear down everything defined in this file
##############################################################################

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ── Provider ─────────────────────────────────────────────────────────────────
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

# ── Variables ─────────────────────────────────────────────────────────────────
variable "aws_region" {
  description = "AWS region to deploy resources into"
  type        = string
  default     = "eu-north-1"
}

variable "aws_profile" {
  description = "AWS CLI profile to use for authentication"
  type        = string
  default     = "default"
}

variable "project_name" {
  description = "Project name used as a prefix for resource names"
  type        = string
  default     = "nextwork-cicd"
}

# ── S3 Bucket: Private Artifacts ──────────────────────────────────────────────
# This bucket holds build artifacts produced by CodeBuild.
# It must remain private — no public access whatsoever.
resource "aws_s3_bucket" "artifacts" {
  bucket = "${var.project_name}-artifacts-tf"

  tags = {
    Name        = "${var.project_name}-artifacts"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── S3 Bucket: Static Website Hosting ────────────────────────────────────────
# Demonstrates enabling a static website on S3, with a custom error page
# and a routing rule that redirects /docs/* → /documents/*.
resource "aws_s3_bucket" "website" {
  bucket = "${var.project_name}-website-tf"

  tags = {
    Name        = "${var.project_name}-website"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }

  routing_rule {
    condition {
      key_prefix_equals = "docs/"
    }
    redirect {
      replace_key_prefix_with = "documents/"
    }
  }
}

# Separate public access block for the website bucket.
# NOTE: For a website bucket you must allow public reads — but only grant
# read via bucket policy (below), not via ACLs.
resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = true
  block_public_policy     = false # must be false to attach a public bucket policy
  ignore_public_acls      = true
  restrict_public_buckets = false # must be false to serve public website traffic
}

resource "aws_s3_bucket_policy" "website" {
  bucket     = aws_s3_bucket.website.id
  depends_on = [aws_s3_bucket_public_access_block.website]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.website.arn}/*"
      }
    ]
  })
}

# ── S3 Object: Upload index.html ──────────────────────────────────────────────
# Terraform can manage content as code — every apply ensures this file
# exists in the bucket with the expected content.
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.website.id
  key          = "index.html"
  source       = "${path.module}/website/index.html"
  content_type = "text/html"

  # Terraform re-uploads whenever the local file's MD5 changes
  etag = filemd5("${path.module}/website/index.html")
}

# ── Outputs ───────────────────────────────────────────────────────────────────
output "artifact_bucket_name" {
  description = "Name of the private S3 artifacts bucket"
  value       = aws_s3_bucket.artifacts.id
}

output "website_bucket_name" {
  description = "Name of the website S3 bucket"
  value       = aws_s3_bucket.website.id
}

output "website_endpoint" {
  description = "S3 static website endpoint URL"
  value       = aws_s3_bucket_website_configuration.website.website_endpoint
}
