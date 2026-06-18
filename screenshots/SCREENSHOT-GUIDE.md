# Screenshot Guide — AWS CI/CD Pipeline Series

These are the exact screenshots to extract from the PDFs for each article.
Each entry tells you: **which PDF**, **what page**, and **what the screenshot should show**.

After extracting, save them into this `screenshots/` folder using the filename given.
Then insert them into the article markdown files at the marked `> **Screenshot:**` lines.

---

## Part 1 — EC2 + VS Code Setup
**PDF:** `PART 1 - Set up a web app using AWS & VS Code.pdf`

| # | Filename | Page | What to capture |
|---|---|---|---|
| 1 | `p1-ec2-running.png` | Page 4 | EC2 console showing a running instance — the green "Running" status badge and the public IPv4 address visible in the instance details |
| 2 | `p1-ssh-connected.png` | Page 7 | Terminal showing a successful SSH connection — the `[ec2-user@ip-10-x-x-x ~]$` prompt |
| 3 | `p1-vscode-remote.png` | Page 9–10 | VS Code with the Remote-SSH extension connected — the file explorer showing the `nextwork-web-project` folder, and the green remote indicator in the bottom-left corner of VS Code |
| 4 | `p1-indexjsp-edit.png` | Page 11 | VS Code editor showing the edited `index.jsp` file open |

**Where to insert in the article:**
- `p1-ec2-running.png` → after "Step 1: Launch an EC2 Instance" screenshot callout
- `p1-ssh-connected.png` → after "Step 2: Secure Your Key and Connect via SSH" screenshot callout
- `p1-vscode-remote.png` → after "Step 5: Set Up VS Code with Remote-SSH" screenshot callout
- `p1-indexjsp-edit.png` → after "Step 6: Edit index.jsp" screenshot callout

---

## Part 2 — GitHub Integration
**PDF:** `PART 2 - Connect Github Repo with AWS.pdf`

| # | Filename | Page | What to capture |
|---|---|---|---|
| 1 | `p2-git-push-output.png` | Page 8 | Terminal showing the output of a successful `git push` — lines like "Branch 'master' set up to track remote branch 'master' from 'origin'" |
| 2 | `p2-github-token.png` | Page 11 | GitHub personal access token creation page — the token generated (blur/redact the actual token value, just show the UI with the copy button visible) |
| 3 | `p2-github-repo-files.png` | Page 12–13 | GitHub repository in the browser showing the pushed files (`pom.xml`, `src/`, etc.) and the commit message |
| 4 | `p2-commit-history.png` | Page 13–14 | GitHub commit history showing at least 2 commits (initial + update) |

**Where to insert in the article:**
- `p2-git-push-output.png` → after "Step 5: Stage, Commit, and Push" screenshot callout
- `p2-github-token.png` → after "Step 7: Create a GitHub Personal Access Token" screenshot callout
- `p2-github-repo-files.png` → after "Step 8: Verify the Push" screenshot callout
- `p2-commit-history.png` → after "Step 9: Test the Workflow" screenshot callout

---

## Part 3 — CodeArtifact
**PDF:** `PART 3 - Secure Packages with CodeArtifact.pdf`

| # | Filename | Page | What to capture |
|---|---|---|---|
| 1 | `p3-codeartifact-repo.png` | Page 4 | CodeArtifact console showing the domain and repository created, with the Maven Central upstream listed |
| 2 | `p3-iam-role-attached.png` | Page 5 | EC2 console showing the IAM role attached to the instance (Modify IAM role dialog or the instance summary showing the IAM role name) |
| 3 | `p3-maven-deps-cached.png` | Page 9 | CodeArtifact repository after the first `mvn compile` — the package list showing downloaded Maven dependencies cached in the repo |
| 4 | `p3-custom-package.png` | Page 10–11 | CodeArtifact showing the published custom internal package (`secret-mission`) with "Published" status |

**Where to insert in the article:**
- `p3-codeartifact-repo.png` → after "Step 1: Create a CodeArtifact Domain and Repository" screenshot callout
- `p3-iam-role-attached.png` → after "Step 2: Fix the IAM Permission Error" screenshot callout
- `p3-maven-deps-cached.png` → after "Step 4: Compile and Verify" screenshot callout
- `p3-custom-package.png` → after "Step 5: Publish an Internal Package" screenshot callout

---

## Part 4 — CodeBuild
**PDF:** `PART 4 - Continuous Integration with CodeBuild.pdf`

| # | Filename | Page | What to capture |
|---|---|---|---|
| 1 | `p4-codebuild-config.png` | Page 4–6 | CodeBuild project creation page showing the source (GitHub), environment (Amazon Linux), and artifacts (S3) configuration |
| 2 | `p4-buildspec-file.png` | Page 8–9 | The `buildspec.yml` file open in VS Code or shown in the terminal — showing all 4 phases |
| 3 | `p4-build-success.png` | Page 10–11 | CodeBuild build history showing a successful build — green checkmark, `SUCCEEDED` status |
| 4 | `p4-s3-artifact.png` | Page 11 | S3 bucket showing the uploaded build artifact ZIP file after a successful build |

**Where to insert in the article:**
- `p4-codebuild-config.png` → after "Step 1: Set Up the CodeBuild Project" screenshot callout
- `p4-buildspec-file.png` → after "Step 2: Write buildspec.yml" screenshot callout
- `p4-build-success.png` → after "Step 5: Successful Build — Verify the Artifact" screenshot callout (first part)
- `p4-s3-artifact.png` → after "Step 5: Successful Build — Verify the Artifact" screenshot callout (second part)

---

## Part 5 — CodeDeploy
**PDF:** `PART 5 - Deploy a Web App with CodeDeploy.pdf`

| # | Filename | Page | What to capture |
|---|---|---|---|
| 1 | `p5-cloudformation-stack.png` | Page 4–5 | CloudFormation console showing the stack in `CREATE_COMPLETE` status with resources listed |
| 2 | `p5-codedeploy-group.png` | Page 9–10 | CodeDeploy deployment group configuration showing the EC2 tag filter (`role=webserver`) |
| 3 | `p5-deploy-success.png` | Page 13 | CodeDeploy deployment showing all lifecycle hooks succeeded — green checkmarks on ApplicationStop, BeforeInstall, ApplicationStart, ValidateService |
| 4 | `p5-webapp-live.png` | Page 13 | Web browser showing the deployed web application at the EC2 public IP |
| 5 | `p5-rollback.png` | Page 15 | CodeDeploy showing a FAILED deployment followed by an automatic rollback deployment |

**Where to insert in the article:**
- `p5-cloudformation-stack.png` → after "Step 1: Provision the Infrastructure with CloudFormation" screenshot callout
- `p5-codedeploy-group.png` → after "Step 4: Set Up CodeDeploy" screenshot callout
- `p5-deploy-success.png` → after "Step 5: Create and Run a Deployment" screenshot callout
- `p5-webapp-live.png` → after "Step 5" (browser verification paragraph)
- `p5-rollback.png` → after "Step 6: Simulating a Failed Deployment and Rollback" screenshot callout

---

## Part 6 — CloudFormation IaC
**PDF:** `PART 6 - Infrastructure as Code (IaC) with CloudFormation.pdf`

| # | Filename | Page | What to capture |
|---|---|---|---|
| 1 | `p6-iac-generator.png` | Page 3–4 | CloudFormation IaC Generator showing the scanned resources list, before generating the template |
| 2 | `p6-stack-failure.png` | Page 5 | CloudFormation stack showing `CREATE_FAILED` status — the first failure with IAM policy error |
| 3 | `p6-stack-success.png` | Page 10 | CloudFormation console showing the stack in `CREATE_COMPLETE` with the full list of resources in the Resources tab |

**Where to insert in the article:**
- `p6-iac-generator.png` → after "Step 1: Use the IaC Generator to Scaffold Your Template" screenshot callout
- `p6-stack-failure.png` → after "Step 3: First Failure — IAM Policy Creation Order" (the failure context)
- `p6-stack-success.png` → after "Step 6: Deploy the Stack" screenshot callout

> **Note:** Part 6 has fewer screenshots than other parts because the code (the CloudFormation template) is the main deliverable. The template in `infrastructure/cloudformation/cicd-stack.yaml` is what readers will study.

---

## Part 7 — Full CodePipeline
**PDF:** `PART 7 - Build a CI:CD Pipeline with AWS.pdf`

| # | Filename | Page | What to capture |
|---|---|---|---|
| 1 | `p7-pipeline-stages.png` | Page 6–7 | CodePipeline console showing all three stages (Source, Build, Deploy) in `Succeeded` state — green checkmarks, matching commit SHAs under each stage |
| 2 | `p7-pipeline-running.png` | Page 11 | CodePipeline mid-execution — at least one stage showing the blue "In Progress" spinner after a git push |
| 3 | `p7-webapp-updated.png` | Page 11–12 | Web browser showing the updated web app after a successful pipeline run |
| 4 | `p7-rollback-deploy.png` | Page 13–14 | CodeDeploy showing a rollback deployment in progress or completed — the revision shows the previous S3 artifact key, not the latest |

**Where to insert in the article:**
- `p7-pipeline-stages.png` → after "Step 5: Run the Pipeline" screenshot callout
- `p7-pipeline-running.png` → after "Step 6: Test the Automated Trigger" screenshot callout
- `p7-webapp-updated.png` → after "Step 6" (browser verification paragraph)
- `p7-rollback-deploy.png` → after "Step 7: Test Rollback" screenshot callout

---

## Bonus — Terraform vs CloudFormation
**PDF:** `CREATE S3 BUCKETS WITH TERRAFORM.pdf`

| # | Filename | Page | What to capture |
|---|---|---|---|
| 1 | `bonus-terraform-apply.png` | Page 13–14 | Terminal showing `terraform apply` output — the green `Apply complete! Resources: 3 added` confirmation line |
| 2 | `bonus-s3-console.png` | Page 15 | S3 console showing the bucket created by Terraform, with the uploaded `image.png` object visible inside |

**Where to insert in the article:**
- `bonus-terraform-apply.png` → after the "Launching the S3 Bucket" / `terraform apply` section
- `bonus-s3-console.png` → after the "Uploading an S3 Object" section

---

## How to Extract Screenshots from the PDFs

1. Open the PDF in **Preview** (macOS)
2. Use **⌘+Shift+4** to take a screenshot of just the relevant portion of the page, OR
3. In Preview: select the relevant area using the Selection tool, then **File → Export as PNG**
4. Save with the exact filename listed above into this `screenshots/` folder

## How to Insert Screenshots into the Articles

In each article markdown file, find the `> **Screenshot:**` lines — they already mark the exact insertion points. Replace each line with:

```markdown
![Description of what the screenshot shows](../../screenshots/filename.png)
```

For example:

```markdown
![EC2 instance running with public IPv4 visible](../../screenshots/p1-ec2-running.png)
```

---

## Summary Count

| Article | Screenshots needed |
|---|---|
| Part 1 | 4 |
| Part 2 | 4 |
| Part 3 | 4 |
| Part 4 | 4 |
| Part 5 | 5 |
| Part 6 | 3 |
| Part 7 | 4 |
| Bonus | 2 |
| **Total** | **30** |
