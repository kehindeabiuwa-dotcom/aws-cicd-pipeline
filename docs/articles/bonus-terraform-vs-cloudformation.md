---
title: "Terraform vs CloudFormation: Creating S3 Buckets Two Ways (And When to Use Each)"
published: false
description: "Build the same S3 infrastructure in both Terraform and CloudFormation, side by side. A hands-on comparison of state management, syntax, and when to reach for each IaC tool."
tags: aws, terraform, iac, cloudformation
series: Building a Production CI/CD Pipeline on AWS
cover_image: https://github.com/kehindeabiuwa-dotcom/aws-cicd-pipeline/raw/main/screenshots/diagrams/bonus-diagram.png
canonical_url:
---

# Bonus — Terraform vs CloudFormation: Creating S3 Buckets Two Ways (And When to Use Each)

**Series:** Building a Production CI/CD Pipeline on AWS (7-Part Series)
**Author:** Kehinde Abiuwa | AWS Solutions Architect Professional | AZ-305
**LinkedIn:** [linkedin.com/in/kehinde-abiuwa-b68087247](https://www.linkedin.com/in/kehinde-abiuwa-b68087247)

---

## The IaC Debate

Ask any cloud engineer "CloudFormation or Terraform?" and you'll get a strong opinion. Both are Infrastructure as Code tools. Both can create the same AWS resources. But they have fundamentally different design philosophies, state management models, and use cases.

This article builds the same thing — S3 buckets with versioning, encryption, website hosting, and file uploads — in both tools. Side by side. Same output, different approach. By the end, you'll understand which to reach for and why.

---

## The Same Goal, Two Tools

We'll create:
1. A private S3 bucket for build artifacts (versioned, encrypted, all public access blocked)
2. A public S3 bucket for static website hosting (with custom error page and URL routing)
3. Upload `index.html` to the website bucket as part of the deployment

---

## CloudFormation Approach

**`infrastructure/cloudformation/cicd-stack.yaml` (excerpt):**

```yaml
ArtifactBucket:
  Type: AWS::S3::Bucket
  Properties:
    BucketName: !Sub "nextwork-devops-cicd-artifacts-${AWS::AccountId}"
    VersioningConfiguration:
      Status: Enabled
    BucketEncryption:
      ServerSideEncryptionConfiguration:
        - ServerSideEncryptionByDefault:
            SSEAlgorithm: AES256
    PublicAccessBlockConfiguration:
      BlockPublicAcls: true
      BlockPublicPolicy: true
      IgnorePublicAcls: true
      RestrictPublicBuckets: true

WebsiteBucket:
  Type: AWS::S3::Bucket
  Properties:
    WebsiteConfiguration:
      IndexDocument: index.html
      ErrorDocument: error.html
      RoutingRules:
        - RoutingRuleCondition:
            KeyPrefixEquals: docs/
          RedirectRule:
            ReplaceKeyPrefixWith: documents/
```

**Key characteristics:**
- Declarative YAML describing desired state
- AWS manages the state (in CloudFormation stacks)
- Resources are part of a larger stack — created and deleted together
- No local state file to manage

---

## Terraform Approach

**`infrastructure/terraform/s3-buckets.tf` (excerpt):**

```hcl
resource "aws_s3_bucket" "artifacts" {
  bucket = "${var.project_name}-artifacts-tf"

  tags = {
    Name      = "${var.project_name}-artifacts"
    ManagedBy = "Terraform"
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
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

Notice that Terraform creates **separate resources** for the bucket itself, versioning, encryption, and public access block. CloudFormation puts all of this into one `AWS::S3::Bucket` resource. This reflects Terraform's more modular philosophy — each configuration aspect is independently manageable.

---

## The Terraform Workflow

```bash
# 1. Initialize — download the AWS provider, set up local state
terraform init

# 2. Plan — preview what will be created/changed/destroyed
terraform plan

# 3. Apply — create the real AWS resources
terraform apply

# 4. Destroy — tear down everything defined in the config
terraform destroy
```

The `init → plan → apply` sequence is fundamental:
- `terraform init` downloads the `hashicorp/aws` provider to `.terraform/`
- `terraform plan` reads your `.tf` files, compares to current AWS state via API, and shows exactly what will change — **without changing anything**
- `terraform apply` executes the plan and writes the results to `terraform.tfstate`

**Always run `plan` before `apply`.** The plan output shows `+` (create), `~` (modify), `-` (destroy). Review it before applying, especially in production.

<!-- TODO: Add screenshot bonus-terraform-apply.png — terminal showing terraform plan output and apply confirmation -->

---

## Debugging: The Two Most Common Terraform Errors

**Error 1: Plugin timeout during `terraform init`**

```
Error: Failed to install provider
│ timeout while waiting for plugin to start
```

This usually happens on macOS when Gatekeeper quarantines the downloaded provider binary. Fix:

```bash
xattr -d com.apple.quarantine ~/.terraform.d/plugins/registry.terraform.io/hashicorp/aws/*/*/terraform-provider-aws_*
terraform init
```

**Error 2: `InvalidClientTokenId` during `terraform plan`**

```
Error: retrieving caller identity from STS
│ InvalidClientTokenId: The security token included in the request is invalid.
```

Terraform couldn't authenticate to AWS. Fix:
1. Install the AWS CLI: `brew install awscli`
2. Configure credentials: `aws configure`
3. Test authentication: `aws sts get-caller-identity`
4. Run `terraform plan` again

Terraform reads credentials from the same locations as the AWS CLI — `~/.aws/credentials` and `~/.aws/config`. Once the CLI works, Terraform works.

---

## Side-by-Side Comparison

| Feature | CloudFormation | Terraform |
|---|---|---|
| **Language** | YAML or JSON | HCL (HashiCorp Configuration Language) |
| **State management** | AWS-managed (per stack) | Local `.tfstate` file (or remote backend) |
| **Multi-cloud** | AWS only | AWS, Azure, GCP, and 1000+ providers |
| **Native AWS support** | Best-in-class | Excellent (via provider, ~24hr AWS launch lag) |
| **Drift detection** | Built-in | `terraform plan` shows drift |
| **Rollback on failure** | Automatic | Manual (`terraform destroy` or restore from backup) |
| **Module system** | Nested stacks (complex) | Registry modules (easy) |
| **Secret management** | AWS Secrets Manager, SSM | Vault, environment variables |
| **Team collaboration** | Stack policies | Remote state + state locking |
| **Cost** | Free | Free (open source); Terraform Cloud has paid plans |
| **Learning curve** | Medium | Medium-high |

---

## When to Use CloudFormation

**Choose CloudFormation when:**
- Your infrastructure is 100% AWS (or will be for the foreseeable future)
- You want native integration with AWS services (Service Catalog, CDK, SAM)
- You need AWS-managed state — no tfstate file to lose or corrupt
- Your team is already familiar with YAML/JSON
- You're using AWS CDK (which synthesises to CloudFormation)

**Real-world scenario:** A startup that has standardised on AWS and wants all infrastructure audited via CloudTrail, manageable via AWS Config, and deployable through AWS Service Catalog.

---

## When to Use Terraform

**Choose Terraform when:**
- You manage infrastructure across multiple cloud providers
- You want to use the rich Terraform Registry module ecosystem (pre-built, community-maintained modules for common patterns)
- Your team prefers HCL's explicit, modular structure
- You need Terraform-specific features like `for_each`, complex locals, or provider aliases

**Real-world scenario:** A company that runs primary workloads on AWS but uses Cloudflare for DNS, Datadog for monitoring, and Azure AD for identity — Terraform manages all of them with a single `terraform apply`.

---

## Uploading Files as Code

One powerful Terraform feature demonstrated in this project is managing file content as code:

```hcl
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.website.id
  key          = "index.html"
  source       = "${path.module}/website/index.html"
  content_type = "text/html"
  etag         = filemd5("${path.module}/website/index.html")
}
```

The `etag` field uses the MD5 hash of the local file. Every time you run `terraform apply`, Terraform checks whether the local file has changed (by comparing MD5s). If it has, Terraform uploads the new version. Your content deployments are now tracked in version control alongside your infrastructure.

This is the IaC philosophy applied to content: **everything is code, everything is reproducible**.

![S3 console showing both buckets created by Terraform](https://github.com/kehindeabiuwa-dotcom/aws-cicd-pipeline/raw/main/screenshots/bonus-s3-console.png)
*Both S3 buckets created by Terraform — the artifact bucket (private) and the website bucket (public).*

---

## My Take: Use Both, Know the Difference

I use CloudFormation for AWS-specific infrastructure — especially anything that integrates deeply with IAM, CodePipeline, or CloudFormation-native features like StackSets and Service Catalog. The native integration and AWS-managed state reduce operational overhead.

I use Terraform when managing multi-cloud resources or when I need the flexibility of the module registry. The `plan` workflow is also more transparent than CloudFormation's change sets for complex templates.

Both are skills worth having. The AWS Solutions Architect Professional exam tests your understanding of CloudFormation deeply. The job market increasingly values Terraform proficiency. Learning both makes you a more complete cloud engineer.

---

*Kehinde Abiuwa | AWS Solutions Architect Professional | AZ-305*
*[linkedin.com/in/kehinde-abiuwa-b68087247](https://www.linkedin.com/in/kehinde-abiuwa-b68087247)*
