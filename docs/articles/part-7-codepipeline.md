---
title: "The Full CI/CD Pipeline: One Git Push, Three Stages, Zero Manual Steps"
published: false
description: "Connect CodePipeline to GitHub, CodeBuild, and CodeDeploy so a single git push triggers the entire pipeline. Includes real debugging notes from 210 minutes of troubleshooting."
tags: aws, cicd, devops, automation
series: Building a Production CI/CD Pipeline on AWS
cover_image: https://raw.githubusercontent.com/kehindeabiuwa-dotcom/aws-cicd-pipeline/main/screenshots/diagrams/part7-diagram.png
canonical_url:
---

# Part 7 — The Full CI/CD Pipeline: One Git Push, Three Stages, Zero Manual Steps

**Series:** Building a Production CI/CD Pipeline on AWS (7-Part Series)
**Author:** Kehinde Abiuwa | AWS Solutions Architect Professional | AZ-305
**LinkedIn:** [linkedin.com/in/kehinde-abiuwa-b68087247](https://www.linkedin.com/in/kehinde-abiuwa-b68087247)

---

## The Payoff

Six parts in, you have all the components: an EC2 web server, a GitHub repository, CodeArtifact for package management, CodeBuild for automated builds, CodeDeploy for automated deployments, and a CloudFormation template to provision the entire stack.

The missing piece: something that connects them. Right now, you trigger CodeBuild manually, then manually create a CodeDeploy deployment. That's automation of individual steps, not a pipeline.

AWS CodePipeline is the orchestrator. It watches GitHub for changes, triggers CodeBuild, takes the build artifact, and passes it to CodeDeploy — without you doing anything. From the moment you push code to the moment users see the updated application, zero manual steps.

---

## What We're Building

```
Developer pushes to GitHub (master branch)
        │  Webhook triggers CodePipeline
        ▼
┌─────────────────────────────────────────────────────┐
│               CodePipeline                          │
│                                                     │
│  ┌──────────┐    ┌──────────┐    ┌──────────────┐  │
│  │  Source  │ →  │  Build   │ →  │    Deploy    │  │
│  │ GitHub   │    │CodeBuild │    │  CodeDeploy  │  │
│  │          │    │          │    │              │  │
│  │ Source   │    │ Source   │    │  Build       │  │
│  │Artifact  │    │Artifact  │    │  Artifact    │  │
│  └──────────┘    └──────────┘    └──────────────┘  │
│                                                     │
│          All artifacts stored in S3                 │
└─────────────────────────────────────────────────────┘
        │
        ▼
EC2 Web Server — updated application live
```

Each stage produces an artifact that the next stage consumes. The pipeline makes the artifact flow explicit and trackable — you can see exactly which GitHub commit SHA was built and deployed.

---

## Step 1: Create the CodePipeline

In the AWS Console, navigate to **CodePipeline** → **Create pipeline**.

**Pipeline settings:**
- Pipeline name: `nextwork-devops-cicd-pipeline`
- Execution mode: **Superseded** ← important (explained below)
- Service role: Create a new role

**What is Superseded execution mode?**

CodePipeline offers three execution modes:

| Mode | Behaviour | Use case |
|---|---|---|
| **Superseded** | If a new execution starts while one is in progress, the older run is cancelled | Most pipelines — ensures latest code always wins |
| **Queued** | Executions wait in line and run one at a time | When every commit must be built and deployed in order |
| **Parallel** | Multiple executions run simultaneously | Feature branches, multi-environment |

Superseded is correct for a main branch pipeline. If you push two commits quickly, you only care about deploying the latest one — not both in sequence.

---

## Step 2: Configure the Source Stage (GitHub)

- Provider: GitHub (via AWS CodeConnections)
- Connection: The connection you created in Part 4
- Repository name: `kehindeabiuwa-dotcom/nextwork-web-project`
- Branch name: `master`
- **Detection option: Enable webhook events** ✅

Webhook events are how the pipeline starts automatically on push. Without webhooks, you'd need to poll GitHub or trigger the pipeline manually. With webhooks, GitHub calls CodePipeline within seconds of a push.

The source stage outputs `SourceArtifact` — a ZIP of your repository at the specific commit SHA. This is stored in the S3 artifact bucket.

---

## Step 3: Configure the Build Stage (CodeBuild)

- Provider: AWS CodeBuild
- Project name: `nextwork-devops-cicd` (the project from Part 4)
- Input artifact: `SourceArtifact`
- Output artifact: `BuildArtifact`

CodeBuild receives the `SourceArtifact` (the repository code), runs `buildspec.yml`, and produces `BuildArtifact` (the ZIP containing the WAR, `appspec.yml`, and scripts).

---

## Step 4: Configure the Deploy Stage (CodeDeploy)

- Provider: AWS CodeDeploy
- Application name: `nextwork-webapp-build`
- Deployment group: `nextwork-devops-cicd-deploymentgroup`
- Input artifact: `BuildArtifact`

This stage passes `BuildArtifact` to CodeDeploy, which runs the lifecycle hooks we wrote in Part 5.

---

## Step 5: Run the Pipeline

After creation, CodePipeline immediately starts its first execution using the current `master` branch. Watch the three stage cards in the console:

1. **Source** — fetches the latest commit from GitHub (green in seconds)
2. **Build** — CodeBuild compiles, tests, packages (takes 2-5 minutes)
3. **Deploy** — CodeDeploy runs lifecycle hooks and deploys (takes 2-3 minutes)

Each stage shows:
- Status (running, succeeded, failed)
- The commit SHA that triggered the run
- Links to the specific CodeBuild build log or CodeDeploy deployment

![CodePipeline showing all three stages in Succeeded state](https://raw.githubusercontent.com/kehindeabiuwa-dotcom/aws-cicd-pipeline/main/screenshots/p7-pipeline-stages.png)
*All three pipeline stages succeeded — from GitHub commit to live deployment, fully automated.*

After the pipeline succeeds, open the EC2 instance's public IP in a browser. You should see your application.

---

## Step 6: Test the Automated Trigger

This is the defining moment of a CI/CD pipeline. Edit `index.jsp` on your local machine (or via VS Code Remote-SSH), commit, and push:

```bash
git add src/main/webapp/index.jsp
git commit -m "Update homepage: add deployment timestamp"
git push
```

Watch the CodePipeline console. Within a few seconds of the push, the Source stage turns blue (running). The commit message appears under each stage card, confirming it's your change flowing through the pipeline.

After 5-10 minutes, refresh the browser — you should see the updated page.

<!-- TODO: Add screenshot p7-pipeline-running.png — CodePipeline mid-execution with commit message visible under Source stage -->
<!-- TODO: Add screenshot p7-webapp-updated.png — browser showing the updated page after the automated deployment -->

This is the complete CI/CD loop: write code → push → automated build → automated deployment → live application. No manual steps.

---

## Step 7: Test Rollback

Rollback is the safety net. Let's verify it works.

In the Deploy stage of the pipeline, click **Retry** → then immediately click the **Rollback** option on the deployment in CodeDeploy.

What happens:
1. The **Deploy stage** starts a rollback deployment
2. CodeDeploy redeploys the **previous successful artifact** from S3
3. The **Source and Build stages are not re-triggered** — rollback uses an existing artifact
4. After the rollback, the application reverts to the previous version

You can verify by checking the CodeDeploy deployment details — the revision S3 key will point to the previous artifact, not the latest one.

**Production rollback triggers you should configure:**
- `DEPLOYMENT_FAILURE` — automatic (we have this)
- `DEPLOYMENT_STOP_ON_ALARM` — trigger rollback when a CloudWatch alarm fires (e.g., error rate > 5%)

![CodeDeploy showing a Rollback deployment in progress](https://raw.githubusercontent.com/kehindeabiuwa-dotcom/aws-cicd-pipeline/main/screenshots/p7-rollback-deploy.png)
*Auto-rollback in action — CodeDeploy redeploys the last successful artifact without any manual intervention.*

---

## Debugging: The Real Lessons from 210 Minutes of Troubleshooting

The PDF notes that Part 7 took 210 minutes — the longest in the series. Here's what went wrong and how to avoid it:

**Problem 1: Deploy stage retries the same artifact**
When you click "Retry stage" in CodePipeline, it does not re-run Source or Build. It retries the Deploy stage with the existing BuildArtifact. If the artifact itself is the problem (e.g., wrong WAR path in `appspec.yml`), retrying the stage won't help. You need to fix the artifact, push new code, and wait for a full pipeline run.

**Problem 2: Old lifecycle scripts running on the instance**
CodeDeploy's `ApplicationStop` hook uses the scripts from the **current revision on the instance** — not the new revision being deployed. If you've updated `stop_server.sh` in your new commit, the old version of that script still runs during ApplicationStop. This can cause confusion when you think you've fixed a script bug but it's still failing. The fix takes effect on the **next** deployment after the broken one.

**Problem 3: Tomcat vs. Apache — who serves traffic?**
The web app requires Tomcat to run JSP files. Apache proxies port 80 to Tomcat's port 8080. Both must be running and configured correctly. If you access `http://<ip>` and see Apache's default page instead of your app, the proxy is misconfigured. If you get a 404, Tomcat isn't finding the WAR file.

**Problem 4: Missing IAM permission `codedeploy:GetApplicationRevision`**
CodePipeline's service role needs `codedeploy:GetApplicationRevision` to check the current revision. This isn't obvious from the error message, which is generic. When you see CodePipeline failing at the Deploy stage with an access error, check the CodePipeline service role IAM policy.

---

## Key Design Decisions and Trade-offs

**Why CodePipeline vs. GitHub Actions?**

| Factor | CodePipeline | GitHub Actions |
|---|---|---|
| AWS integration | Native — no credentials needed | Requires IAM user/OIDC setup |
| Cost | $1/pipeline/month + AWS service costs | Free for public repos; minutes-based for private |
| Visibility | AWS Console, CloudWatch | GitHub Actions UI |
| Non-AWS deployments | Awkward (custom actions needed) | Easy (thousands of marketplace actions) |
| Enterprise features | AWS native (VPC, PrivateLink, CloudTrail) | GitHub Enterprise |

CodePipeline is the right choice when your entire stack is on AWS and you want native IAM integration and CloudTrail audit logging of every pipeline execution. GitHub Actions is often easier for mixed or multi-cloud environments.

---

## The Complete Architecture

You've built, over seven parts:

```
Developer (local VS Code → Remote SSH → EC2)
    │
    git push
    │
GitHub Repository (master branch)
    │  webhook
    ▼
CodePipeline
    │
    ├─── Source Stage
    │        └── GitHub via CodeConnections → SourceArtifact (S3)
    │
    ├─── Build Stage
    │        └── CodeBuild
    │               ├── Fetches CodeArtifact token (IAM role → short-lived creds)
    │               ├── CodeArtifact repo (proxies Maven Central, caches deps)
    │               ├── mvn compile + mvn package → .war file
    │               └── BuildArtifact (S3): WAR + appspec.yml + scripts
    │
    └─── Deploy Stage
             └── CodeDeploy
                    ├── Targets EC2 by tag (role=webserver)
                    ├── ApplicationStop → stop_server.sh
                    ├── BeforeInstall   → install_dependencies.sh
                    ├── Files copied    → WAR → /usr/share/tomcat/webapps/
                    ├── ApplicationStart → start_server.sh
                    └── ValidateService → validate_service.sh (HTTP 200 check)

Infrastructure defined in: infrastructure/cloudformation/cicd-stack.yaml
```

Every component has an IAM role with scoped least-privilege permissions. No hardcoded credentials anywhere. Infrastructure is version-controlled and reproducible. Rollback is automatic on failure.

---

## What's Next

This is the final part of the CI/CD pipeline series. The bonus article (Part 8) compares Terraform and CloudFormation hands-on — using the same S3 bucket as the example — so you understand when to use each tool and why.

**[Read the Bonus Article → Terraform vs CloudFormation: Creating S3 Buckets Two Ways and When to Use Each](#)**

---

*Kehinde Abiuwa | AWS Solutions Architect Professional | AZ-305*
*[linkedin.com/in/kehinde-abiuwa-b68087247](https://www.linkedin.com/in/kehinde-abiuwa-b68087247)*
