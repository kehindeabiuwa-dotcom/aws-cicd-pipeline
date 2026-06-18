# AWS CI/CD Pipeline — Production-Grade DevOps on AWS

A complete, end-to-end CI/CD pipeline built entirely with AWS-native services. Push code to GitHub — within minutes it's compiled, tested, and deployed to EC2. No manual steps.

![AWS](https://img.shields.io/badge/AWS-CodePipeline-FF9900?logo=amazonaws&logoColor=white)
![IaC](https://img.shields.io/badge/IaC-CloudFormation-7B42BC)
![Runtime](https://img.shields.io/badge/Java-8%20Corretto-ED8B00)
![GitHub stars](https://img.shields.io/github/stars/kehindeabiuwa-dotcom/aws-cicd-pipeline?style=social)
![GitHub forks](https://img.shields.io/github/forks/kehindeabiuwa-dotcom/aws-cicd-pipeline?style=social)

![Pipeline architecture diagram — GitHub to CodeBuild to CodeDeploy to EC2](https://raw.githubusercontent.com/kehindeabiuwa-dotcom/aws-cicd-pipeline/main/screenshots/diagrams/part7-diagram.png)

> 📖 **Full walkthrough:** [7-part CI/CD series on Dev.to](https://dev.to/kehindeabiuwadotcom/setting-up-a-cloud-development-environment-ec2-ssh-and-vs-code-35i3-temp-slug-9072144?preview=10feea059748eb776a464e1366cb72b288056990efbd415549e484b5e2795706d2c4b9a7878c650a0f1711901a4ffd79ab317bdac09280d612e7d81f)
>
> ⭐ **Found this useful?** Star the repo — it helps others discover it.

**Author:** Kehinde Abiuwa | AWS Solutions Architect Professional | AZ-305
**LinkedIn:** [linkedin.com/in/kehinde-abiuwa-b68087247](https://www.linkedin.com/in/kehinde-abiuwa-b68087247)

---

## Pipeline Architecture

```
Developer
    │
    git push (master)
    │
GitHub Repository
    │  webhook trigger
    ▼
┌──────────────────────────────────────────────────────────┐
│                    AWS CodePipeline                      │
│                                                          │
│  Source (GitHub)  →  Build (CodeBuild)  →  Deploy       │
│  SourceArtifact      BuildArtifact         (CodeDeploy)  │
└──────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
        CodeArtifact       S3 Bucket       EC2 Instance
        (Maven deps)      (Artifacts)    (Web Server)
                                        role=webserver tag
```

**Deployment lifecycle (CodeDeploy):**
```
ApplicationStop → BeforeInstall → [files copied] → ApplicationStart → ValidateService
stop_server.sh   install_deps.sh   WAR → Tomcat    start_server.sh   health check (HTTP 200)
```

---

## Services Used

| Service | Role |
|---|---|
| **AWS EC2** | Hosts the Java web application (Tomcat + Apache) |
| **AWS CodePipeline** | Orchestrates Source → Build → Deploy stages |
| **AWS CodeBuild** | Compiles Java code, runs tests, packages WAR |
| **AWS CodeDeploy** | Deploys artifacts to EC2 with lifecycle hooks |
| **AWS CodeArtifact** | Private Maven package repository (proxies Maven Central) |
| **AWS CloudFormation** | Provisions all infrastructure as code |
| **Amazon S3** | Stores build artifacts between pipeline stages |
| **AWS IAM** | Scoped least-privilege service roles for every component |
| **Amazon CloudWatch** | Build logs, deployment logs, and alarm-based rollback |
| **AWS CodeConnections** | Secure GitHub integration (GitHub App, not tokens) |
| **Terraform** | Alternative IaC demonstrated for S3 bucket management |

---

## Repository Structure

```
aws-cicd-pipeline/
├── app/
│   ├── buildspec.yml             ← CodeBuild instructions (4 phases)
│   ├── appspec.yml               ← CodeDeploy deployment manifest
│   ├── scripts/
│   │   ├── stop_server.sh        ← ApplicationStop hook
│   │   ├── install_dependencies.sh ← BeforeInstall hook
│   │   ├── start_server.sh       ← ApplicationStart hook
│   │   └── validate_service.sh   ← ValidateService health check
│   └── src/main/webapp/
│       └── index.jsp             ← Java web application page
│
├── infrastructure/
│   ├── cloudformation/
│   │   └── cicd-stack.yaml      ← Complete IaC template (all resources)
│   └── terraform/
│       └── s3-buckets.tf        ← Terraform S3 example with website hosting
│
└── docs/
    ├── articles/                 ← 7-part article series + bonus
    │   ├── part-1-ec2-vscode-setup.md
    │   ├── part-2-github-integration.md
    │   ├── part-3-codeartifact.md
    │   ├── part-4-codebuild.md
    │   ├── part-5-codedeploy.md
    │   ├── part-6-cloudformation-iac.md
    │   ├── part-7-codepipeline.md
    │   └── bonus-terraform-vs-cloudformation.md
    ├── linkedin-posts/
    │   └── all-linkedin-posts.md ← 8 ready-to-post LinkedIn posts
    └── lucidchart-diagram-specs.md ← Architecture diagram specs + AI prompts
```

---

## Key Design Decisions

### IAM Least Privilege Throughout
Every AWS service has its own scoped IAM role — no shared credentials, no `*` action wildcards where specific permissions suffice. The CodeBuild service role has three separate managed policies (S3, CloudWatch Logs, CodeArtifact) so permissions can be audited and revoked individually.

### Short-Lived Credentials for CodeArtifact
CodeBuild fetches a fresh CodeArtifact authorization token (12-hour max TTL) at the start of every build in the `pre_build` phase. No long-lived credentials stored in environment variables or build configurations.

### Artifact Bundling — Everything CodeDeploy Needs
The build artifact ZIP contains the WAR file, `appspec.yml`, and all deployment scripts. This ensures every deployment is self-contained — the exact scripts that were tested with the build are the ones that run during deployment. No version skew between code and scripts.

### Idempotent Deployment Scripts
All lifecycle hook scripts are idempotent — they can be run multiple times and produce the same result. `install_dependencies.sh` uses `dnf install -y` (no-op if already installed). `stop_server.sh` checks with `pgrep` before stopping to avoid failures on first deployment.

### Auto-Rollback on Failure
CodeDeploy is configured to automatically roll back to the last successful revision on deployment failure. Rollback uses the existing artifact in S3 — it doesn't re-trigger CodeBuild. The previous artifact must be retained in S3 (versioning is enabled on the artifact bucket).

### Infrastructure as Code — Everything
The VPC, EC2 instance, all IAM roles, CodeBuild project, CodeDeploy deployment group, and CodePipeline are all defined in `infrastructure/cloudformation/cicd-stack.yaml`. Tear down and rebuild the entire CI/CD stack with two commands.

---

## Deploy the Full Stack

**Prerequisites:**
- AWS CLI configured with a profile that has CloudFormation, IAM, EC2, and CI/CD service permissions
- An EC2 key pair in the target region
- A GitHub repository with this application code
- An AWS CodeConnections connection to GitHub (created in CodePipeline → Settings → Connections)

**Deploy:**

```bash
aws cloudformation deploy \
  --template-file infrastructure/cloudformation/cicd-stack.yaml \
  --stack-name NextWorkCICDStack \
  --parameter-overrides \
    GitHubOwner=<kehindeabiuwa-dotcom> \
    GitHubRepo=<your-repo-name> \
    GitHubBranch=master \
    GitHubConnectionArn=<your-codeConnections-arn> \
    KeyPairName=<your-keypair-name> \
  --capabilities CAPABILITY_NAMED_IAM \
  --region eu-north-1
```

**After deployment completes:**
- The web app URL is in the CloudFormation Outputs tab
- The first pipeline execution starts automatically
- Watch the pipeline at: AWS Console → CodePipeline → `nextwork-devops-cicd-pipeline`

**Tear down everything:**

```bash
aws cloudformation delete-stack \
  --stack-name NextWorkCICDStack \
  --region eu-north-1
```

---

## Terraform (S3 Example)

To explore the Terraform IaC approach:

```bash
cd infrastructure/terraform

# Install Terraform: https://developer.hashicorp.com/terraform/downloads
terraform init
terraform plan
terraform apply
```

The Terraform configuration creates a private artifacts bucket and a static website bucket, demonstrating the `init → plan → apply` workflow side-by-side with the CloudFormation approach.

---

## Article Series

| Part | Title | Link |
|---|---|---|
| 1 | Setting Up a Cloud Dev Environment: EC2, SSH, and VS Code | [Read on Dev.to](https://dev.to/kehindeabiuwadotcom/setting-up-a-cloud-development-environment-ec2-ssh-and-vs-code-35i3-temp-slug-9072144?preview=10feea059748eb776a464e1366cb72b288056990efbd415549e484b5e2795706d2c4b9a7878c650a0f1711901a4ffd79ab317bdac09280d612e7d81f) |
| 2 | Version Control for CI/CD: Connecting GitHub to AWS | [Read on Dev.to](https://dev.to/kehindeabiuwadotcom/version-control-for-your-cicd-pipeline-connecting-github-to-aws-3n9l-temp-slug-7195219?preview=8c2805396fdd9cdf155939e20e2d20ecdc56f2e5eb9c497fac2b215713cef2c3a2bb97407bf9463c154674d8a6cf8bd0674fad6fd306ca18dc484d64) |
| 3 | Secure Package Management with AWS CodeArtifact | [Read on Dev.to](https://dev.to/kehindeabiuwadotcom/secure-package-management-why-you-shouldnt-pull-from-maven-central-in-production-542k-temp-slug-7660275?preview=1ec4a419d564b852cfe66b03ae33910c4b5768060f5e50a08c4395bcbcff37aca8c86b6df94034cba5024fb733c01178f7db6d8b0ea2d61adec4ed62) |
| 4 | Continuous Integration with AWS CodeBuild | [Read on Dev.to](https://dev.to/kehindeabiuwadotcom/continuous-integration-with-aws-codebuild-never-build-manually-again-3ba9-temp-slug-144734?preview=bcaa17f3c84f549907ba74638d9029a5f5f3493e646609b6eed2425f20af31087eda060174624183309ad5317fea93e89e40882cc890760ad022477d) |
| 5 | Automated Deployment with AWS CodeDeploy | [Read on Dev.to](https://dev.to/kehindeabiuwadotcom/automated-deployment-with-aws-codedeploy-lifecycle-hooks-and-rollback-2499-temp-slug-4315989?preview=544fadb2341300264753ac46750982b69661ae47cf3b30c27d601a36c7990d4d41ddfd6056506dc50cdcab866e309d2cfda481c6254379fb22b35dcb) |
| 6 | Infrastructure as Code with CloudFormation | [Read on Dev.to](https://dev.to/kehindeabiuwadotcom/infrastructure-as-code-with-cloudformation-turning-a-5-hour-setup-into-a-5-minute-stack-46pg-temp-slug-5182566?preview=eb4d64c1ea661607c1642118b8a444da063104efe40ea8f0fbb755a16c92749719840bba4530d8e864054ef6889afd3aaae0e5b5c9e8ab1a0abca2b4) |
| 7 | The Full CI/CD Pipeline: One Push, Zero Manual Steps | [Read on Dev.to](https://dev.to/kehindeabiuwadotcom/the-full-cicd-pipeline-one-git-push-three-stages-zero-manual-steps-3e4-temp-slug-5148435?preview=4ccc739bbf0465d67317cce4b507710d8099111bcf901b2e008b8c94d0c3e8fa258969c2312a2c505a78fb98b41522e9cfde71ff119c4097737120c3) |
| Bonus | Terraform vs CloudFormation: S3 Buckets Two Ways | [Read on Dev.to](https://dev.to/kehindeabiuwadotcom/terraform-vs-cloudformation-creating-s3-buckets-two-ways-and-when-to-use-each-47m5-temp-slug-1404951?preview=bbffb88d2da0c5632a38dc6b84103a87c4a6135cd8f8a589fa48805f497b2814777ad2fa0abbfdc7a93c5a8e105716ed3d1c38b17ec791022bbb1086) |

---

## Security Notes

- Never commit `.pem` key files (they're in `.gitignore`)
- Never commit AWS credentials or access keys
- The CodeBuild service role should be reviewed periodically — remove permissions that are no longer needed
- Consider replacing EC2 key pair + port 22 with AWS Systems Manager Session Manager for production environments (eliminates SSH key management and closes port 22)

---

*Kehinde Abiuwa | AWS Solutions Architect Professional | AZ-305*
*[linkedin.com/in/kehinde-abiuwa-b68087247](https://www.linkedin.com/in/kehinde-abiuwa-b68087247)*
