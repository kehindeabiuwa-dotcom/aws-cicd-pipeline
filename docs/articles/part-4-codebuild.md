---
title: "Continuous Integration with AWS CodeBuild: Never Build Manually Again"
published: false
description: "Write a buildspec.yml to automate Java compilation, testing, and packaging with AWS CodeBuild — including the two build failures you will definitely hit and how to fix them."
tags: aws, cicd, devops, codebuild
series: Building a Production CI/CD Pipeline on AWS
cover_image: https://raw.githubusercontent.com/kehindeabiuwa-dotcom/aws-cicd-pipeline/main/screenshots/diagrams/part4-diagram.png
canonical_url:
---

![Architecture diagram for Part 4](https://raw.githubusercontent.com/kehindeabiuwa-dotcom/aws-cicd-pipeline/main/screenshots/diagrams/part4-diagram.png)

# Part 4 — Continuous Integration with AWS CodeBuild: Never Build Manually Again

**Series:** Building a Production CI/CD Pipeline on AWS (7-Part Series)
**Author:** Kehinde Abiuwa | AWS Solutions Architect Professional | AZ-305
**LinkedIn:** [linkedin.com/in/kehinde-abiuwa-b68087247](https://www.linkedin.com/in/kehinde-abiuwa-b68087247)

---

## What Continuous Integration Actually Means

CI (Continuous Integration) is not just "automated builds." The original definition, from Martin Fowler and Kent Beck's Extreme Programming work in the late 1990s, is: **integrating code changes into a shared repository frequently — at least daily — with each integration verified by an automated build and tests.**

The key word is "verified." A build that compiles is not the same as a build that passes tests. CI means both, automatically, on every commit.

In this part, we set up AWS CodeBuild to automatically compile, test, and package our Java web application every time code is pushed to GitHub. We'll also write the `buildspec.yml` file — the instructions that tell CodeBuild exactly what to do — and walk through the two build failures you'll encounter and why they happen.

---

## What We're Building

```
GitHub (push to master)
        │  Source trigger (CodeConnections)
        ▼
CodeBuild Project
  ├── Fetches CodeArtifact authorization token
  ├── Compiles Java code (mvn compile)
  ├── Runs tests (mvn test)
  ├── Packages WAR file (mvn package)
  └── Uploads artifact ZIP to S3
        │
        ▼
S3 Artifact Bucket
  └── nextwork-web-project.zip
        ├── target/nextwork-web-project.war   ← the application
        ├── appspec.yml                        ← CodeDeploy instructions
        └── scripts/                           ← lifecycle hook scripts
```

Everything CodeDeploy needs to deploy the application is bundled into a single artifact.

---

## Step 1: Set Up the CodeBuild Project

In the AWS Console, navigate to **CodeBuild** → **Build projects** → **Create build project**.

**Source configuration:**
- Provider: GitHub
- Repository: Your GitHub repo URL
- Connection type: GitHub App (via AWS CodeConnections)

**Why GitHub App over personal access tokens for CodeBuild?**
AWS CodeConnections manages the GitHub App connection. AWS rotates the credentials, handles OAuth flows, and the connection is not tied to any individual GitHub account's personal token. If the developer who set up the token leaves the organisation and rotates their credentials, the build doesn't break.

**Environment configuration:**
- Environment image: Managed image
- Operating system: Amazon Linux
- Runtime: Standard
- Image: `aws/codebuild/standard:7.0`
- Service role: Create a new service role (`codebuild-nextwork-devops-cicd-service-role`)

**Artifacts:**
- Type: Amazon S3
- Bucket: Create a new S3 bucket (`nextwork-devops-cicd-artifacts-<account-id>`)
- Packaging: Zip

**Logs:**
- Enable CloudWatch Logs (always — this is how you diagnose build failures)

![CodeBuild project creation page showing source, environment, and artifact settings](https://raw.githubusercontent.com/kehindeabiuwa-dotcom/aws-cicd-pipeline/main/screenshots/p4-codebuild-config.png)
*CodeBuild project configuration — source connected to GitHub via CodeConnections, Amazon Linux environment, S3 artifacts.*

---

## Step 2: Write buildspec.yml

The `buildspec.yml` file tells CodeBuild what to do at each phase. Without it, CodeBuild has no instructions and fails immediately.

```yaml
version: 0.2

env:
  variables:
    CODEARTIFACT_DOMAIN: "nextwork-devops-cicd"
    CODEARTIFACT_REPO: "nextwork-devops-cicd"

phases:
  install:
    runtime-versions:
      java: corretto8

  pre_build:
    commands:
      - echo "Pre-build started on $(date)"
      - export CODEARTIFACT_AUTH_TOKEN=$(aws codeartifact get-authorization-token \
          --domain $CODEARTIFACT_DOMAIN \
          --domain-owner $(aws sts get-caller-identity --query Account --output text) \
          --query authorizationToken \
          --output text)

  build:
    commands:
      - echo "Build started on $(date)"
      - mvn compile -s settings.xml

  post_build:
    commands:
      - echo "Build completed on $(date)"
      - mvn package -s settings.xml

artifacts:
  files:
    - target/nextwork-web-project.war
    - appspec.yml
    - scripts/**/*
  discard-paths: no
```

**Phase breakdown:**

| Phase | Purpose | Failure means |
|---|---|---|
| `install` | Set up the runtime (Java 8 Corretto) | Wrong runtime specified |
| `pre_build` | Prepare environment (get CodeArtifact token) | IAM permissions missing |
| `build` | Compile the source code | Syntax error in Java code |
| `post_build` | Package into WAR file | Build output misconfiguration |

The `artifacts` section defines what gets uploaded to S3 after a successful build. `discard-paths: no` preserves the directory structure — critical because `appspec.yml` references `scripts/stop_server.sh` by path, and flattening the paths would break CodeDeploy.

![buildspec.yml open in VS Code showing all four build phases](https://raw.githubusercontent.com/kehindeabiuwa-dotcom/aws-cicd-pipeline/main/screenshots/p4-buildspec-file.png)
*The complete `buildspec.yml` — four phases from environment setup to Maven packaging.*

---

## Step 3: First Build Failure — Missing buildspec.yml

When you run the build for the first time, it fails immediately:

```
[Container] Phase complete: DOWNLOAD_SOURCE
[Container] Phase context status code: YAML_FILE_ERROR
Message: YAML file does not exist
```

**Why?** CodeBuild looks for `buildspec.yml` at the root of your repository by default. If you've stored it anywhere else (e.g., inside the `app/` subdirectory), you need to either move it or specify the path in the build project configuration.

Fix: commit `buildspec.yml` to the root of your repository and push.

```bash
git add buildspec.yml settings.xml
git commit -m "Add buildspec.yml and Maven CodeArtifact settings"
git push
```

---

## Step 4: Second Build Failure — CodeArtifact Permission Denied

The second build gets further but fails in the `pre_build` phase:

```
[Container] Running command: aws codeartifact get-authorization-token ...
An error occurred (AccessDeniedException) when calling the GetAuthorizationToken operation:
User: arn:aws:sts::123456789:assumed-role/codebuild-nextwork-devops-cicd-service-role/...
is not authorized to perform: codeartifact:GetAuthorizationToken
```

**Why?** The CodeBuild service role was automatically created with permissions for S3 and CloudWatch Logs — but not CodeArtifact. Every AWS service needs explicit IAM permission to access other services.

**Fix:** Attach a policy to the CodeBuild service role that grants CodeArtifact read access.

In IAM, find the role `codebuild-nextwork-devops-cicd-service-role` and attach:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "codeartifact:GetAuthorizationToken",
        "codeartifact:GetRepositoryEndpoint",
        "codeartifact:ReadFromRepository"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "sts:GetServiceBearerToken",
      "Resource": "*"
    }
  ]
}
```

After attaching the policy, run the build again. It should succeed.

---

## Step 5: Successful Build — Verify the Artifact

A successful build shows:

```
[Container] Phase complete: POST_BUILD State: SUCCEEDED
[Container] Phase complete: UPLOAD_ARTIFACTS State: SUCCEEDED
```

Navigate to your S3 artifact bucket. You should see a ZIP file containing:
- `target/nextwork-web-project.war`
- `appspec.yml`
- `scripts/`

This artifact is what CodeDeploy will use to deploy the application. Every build produces a new version of this artifact — and CodePipeline tracks which version flows through each stage.

<!-- TODO: Add screenshot p4-s3-artifact.png — S3 bucket showing the uploaded artifact ZIP from the successful build -->

---

## Step 6 (Extension): Automated Testing

In a real CI pipeline, testing isn't optional. Let's add a simple shell-based validation test that checks the project structure is correct:

Create `test/validate-structure.sh`:

```bash
#!/bin/bash
# Validates that required project files and directories exist
set -e

echo "Checking project structure..."

REQUIRED_FILES=(
  "pom.xml"
  "src/main/webapp/index.jsp"
  "src/main/webapp/WEB-INF/web.xml"
  "buildspec.yml"
  "appspec.yml"
)

for FILE in "${REQUIRED_FILES[@]}"; do
  if [ -f "$FILE" ]; then
    echo "✓ $FILE"
  else
    echo "✗ MISSING: $FILE"
    exit 1
  fi
done

echo "All required files present. Structure validation passed."
```

Update `buildspec.yml` to run this test in the `build` phase:

```yaml
build:
  commands:
    - echo "Running structure validation tests..."
    - chmod +x test/validate-structure.sh
    - ./test/validate-structure.sh
    - echo "Compiling..."
    - mvn compile -s settings.xml
```

Push to GitHub and run the build. CodeBuild will now run the validation script before compiling. If any required file is missing, the build fails early — exactly what CI is meant to do.

![CodeBuild build history showing a successful build](https://raw.githubusercontent.com/kehindeabiuwa-dotcom/aws-cicd-pipeline/main/screenshots/p4-build-success.png)
*Build succeeded — all phases completed, the `.war` file and deployment assets are in S3.*

---

## Key Design Decisions and Trade-offs

**Managed image vs. custom Docker image:**
CodeBuild managed images (`aws/codebuild/standard:7.0`) are maintained by AWS, include common runtimes, and are the default. Custom Docker images (from ECR) make sense when you need specific tools, a reproducible environment, or faster startup times by pre-installing heavy dependencies. For this project, managed images are correct.

**Zip packaging for artifacts:**
Zip packaging reduces the artifact size (faster upload to S3), keeps everything in a single file (simpler tracking), and is required by CodeDeploy. The alternative — no packaging — uploads raw files individually and makes artifact management harder.

**S3 versioning on the artifact bucket:**
Enable versioning on the artifact bucket. Every build produces a new object, and versioning means older builds are retained. This is essential for rollbacks — CodeDeploy can redeploy a previous artifact if the latest build causes issues.

---

## Lessons Learned

**Every IAM error is a specific missing permission.** The error message tells you the exact action and resource. Search for that action in the IAM policy documentation and add it to the service role. Don't add `*` to every action — that violates least privilege and is a common lazy shortcut that causes security incidents.

**Build phase errors are almost always a environment mismatch.** If code compiles locally but not in CodeBuild, check: Java version, Maven version, environment variables, and file paths. The buildspec `runtime-versions` must match your local development environment.

**CloudWatch Logs are mandatory.** Disable them and you're flying blind when builds fail. The logs show exactly which command failed, the output, and the exit code. In a production pipeline, these logs flow into a centralised logging system (CloudWatch Logs Insights or a SIEM).

---

## What's Next

In Part 5, we add AWS CodeDeploy — the final piece of the automated deployment puzzle. CodeDeploy takes the artifact produced by CodeBuild, copies it to the EC2 instance, and runs our lifecycle scripts to stop the old version, install dependencies, start the new version, and validate it's healthy.

**[Read Part 5 → Automated Deployment with AWS CodeDeploy: Lifecycle Hooks and Rollback Strategies](#)**

---

*Kehinde Abiuwa | AWS Solutions Architect Professional | AZ-305*
*[linkedin.com/in/kehinde-abiuwa-b68087247](https://www.linkedin.com/in/kehinde-abiuwa-b68087247)*
