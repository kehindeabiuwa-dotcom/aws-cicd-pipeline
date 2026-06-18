![Architecture diagram for Part 5](https://raw.githubusercontent.com/kehindeabiuwa-dotcom/aws-cicd-pipeline/main/screenshots/diagrams/part5-diagram.png)

# Part 5 — Automated Deployment with AWS CodeDeploy: Lifecycle Hooks and Rollback

**Series:** Building a Production CI/CD Pipeline on AWS (7-Part Series)
**Author:** Kehinde Abiuwa | AWS Solutions Architect Professional | AZ-305
**LinkedIn:** [linkedin.com/in/kehinde-abiuwa-b68087247](https://www.linkedin.com/in/kehinde-abiuwa-b68087247)

---

## Deployment is Not "Copy Files and Hope"

In the early days of web development, deploying an application meant: SSH into the server, copy the new files, restart Apache, and hope nothing broke. This is manual, error-prone, and doesn't scale.

A proper deployment system needs to:
1. Stop the existing application cleanly before replacing files
2. Install any new dependencies required by the new version
3. Start the new version
4. Verify it's actually working (not just started — *working*)
5. Roll back automatically if any of the above fails

AWS CodeDeploy implements all five steps through a lifecycle hook model. You define what happens at each step — and if any step fails with a non-zero exit code, CodeDeploy stops and can automatically revert to the last working version.

---

## What We're Building

```
S3 Artifact Bucket (BuildArtifact.zip)
        │  CodeDeploy reads artifact
        ▼
EC2 Instance (role=webserver tag)
  CodeDeploy Agent
    │
    ├── ApplicationStop  → scripts/stop_server.sh
    ├── BeforeInstall    → scripts/install_dependencies.sh
    │     (copies WAR to /usr/share/tomcat/webapps/)
    ├── ApplicationStart → scripts/start_server.sh
    └── ValidateService  → scripts/validate_service.sh
```

The agent runs on the EC2 instance and polls CodeDeploy for new deployments. When it receives one, it downloads the artifact from S3, extracts it, and executes each lifecycle hook script in order.

---

## Step 1: Provision the Infrastructure with CloudFormation

Instead of creating the EC2 instance, VPC, and security group manually, we'll use CloudFormation — Infrastructure as Code that can be version-controlled and reproduced in minutes.

The CloudFormation template provisions:
- **VPC** with a public subnet, internet gateway, and routing table
- **Security group** allowing HTTP (80) and SSH (22)
- **EC2 instance** tagged with `role=webserver` — CodeDeploy uses this tag to find targets
- **IAM instance profile** allowing the EC2 instance to read from S3 (for artifact download)

**Why CloudFormation instead of the AWS console?**
Every resource created in the console exists only in that account and region, undocumented, unreproducible. A CloudFormation template is a git-committable, reviewable, reproducible record of your infrastructure. When you're done testing, `aws cloudformation delete-stack` tears everything down in the correct dependency order. No hunting for orphaned resources that generate unexpected bills.

![CloudFormation console showing the stack creating resources](https://raw.githubusercontent.com/kehindeabiuwa-dotcom/aws-cicd-pipeline/main/screenshots/p5-cloudformation-stack.png)
*CloudFormation provisioning the EC2 instance, IAM roles, and security group — all in one automated operation.*

After the stack creates successfully, note the EC2 instance's public IP from the Outputs tab.

---

## Step 2: Write the Deployment Scripts

These four scripts are the heart of CodeDeploy's lifecycle. They live in the `scripts/` directory and are bundled into the build artifact.

**`stop_server.sh` — ApplicationStop hook:**

```bash
#!/bin/bash
echo "=== stop_server.sh ==="

if pgrep httpd > /dev/null 2>&1; then
    systemctl stop httpd.service
fi

if pgrep -x "java" > /dev/null 2>&1; then
    systemctl stop tomcat.service
fi
```

Using `pgrep` before stopping avoids a non-zero exit code when the service isn't running — which happens on first deployment when nothing is installed yet. **This is a subtle but important detail.** A non-zero exit from ApplicationStop causes the deployment to fail before any files are touched.

**`install_dependencies.sh` — BeforeInstall hook:**

```bash
#!/bin/bash
set -e

dnf update -y
dnf install -y java-1.8.0-amazon-corretto tomcat tomcat-webapps httpd

# Configure Apache to proxy port 80 → Tomcat port 8080
cat > /etc/httpd/conf.d/tomcat-proxy.conf << 'EOF'
<VirtualHost *:80>
    ProxyPreserveHost On
    ProxyPass / http://localhost:8080/
    ProxyPassReverse / http://localhost:8080/
</VirtualHost>
EOF

chown -R tomcat:tomcat /usr/share/tomcat/webapps/
```

This script is idempotent — running it multiple times produces the same result. That's required for CodeDeploy hooks. `dnf install -y` is a no-op if the package is already installed.

**`start_server.sh` — ApplicationStart hook:**

```bash
#!/bin/bash
set -e

systemctl start tomcat.service
systemctl enable tomcat.service

systemctl start httpd.service
systemctl enable httpd.service
```

`enable` makes both services auto-start on reboot. Without this, the application goes down whenever the instance restarts.

**`validate_service.sh` — ValidateService hook:**

```bash
#!/bin/bash
set -e

for i in $(seq 1 5); do
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/nextwork-web-project/)
    if [ "$HTTP_STATUS" -eq 200 ]; then
        echo "Application healthy (HTTP $HTTP_STATUS)"
        exit 0
    fi
    sleep 5
done

echo "Application failed health check"
exit 1
```

This is the gate that determines if the deployment succeeded. If the app isn't responding with HTTP 200 after 25 seconds (5 attempts, 5 second intervals), the deployment fails — and if auto-rollback is enabled, CodeDeploy immediately redeploys the previous version.

---

## Step 3: Write appspec.yml

`appspec.yml` is the CodeDeploy deployment manifest. It tells the agent what to copy and which scripts to run:

```yaml
version: 0.0
os: linux

files:
  - source: target/nextwork-web-project.war
    destination: /usr/share/tomcat/webapps/

hooks:
  ApplicationStop:
    - location: scripts/stop_server.sh
      timeout: 60
      runas: root

  BeforeInstall:
    - location: scripts/install_dependencies.sh
      timeout: 300
      runas: root

  ApplicationStart:
    - location: scripts/start_server.sh
      timeout: 60
      runas: root

  ValidateService:
    - location: scripts/validate_service.sh
      timeout: 30
      runas: root
```

**Critical detail:** After adding `appspec.yml`, you must also update `buildspec.yml` to include it in the artifact bundle:

```yaml
artifacts:
  files:
    - target/nextwork-web-project.war
    - appspec.yml
    - scripts/**/*
  discard-paths: no
```

`discard-paths: no` preserves the `scripts/` directory structure. Without it, all files would be flattened to the artifact root, and `scripts/stop_server.sh` would be referenced by CodeDeploy but not found at that path.

---

## Step 4: Set Up CodeDeploy

**Create a CodeDeploy application:**
- Application name: `nextwork-webapp-build`
- Compute platform: EC2/On-Premises

**Create a deployment group:**
- Deployment group name: `nextwork-devops-cicd-deploymentgroup`
- Service role: Create a new IAM role with the `AWSCodeDeployRole` managed policy
- Deployment type: In-place
- Environment configuration: Amazon EC2 instances with tag `role=webserver`
- Deployment configuration: `CodeDeployDefault.AllAtOnce`
- Enable rollback on deployment failure: ✅

**Why tags for EC2 instance targeting?**
Tags let you define deployment targets by purpose rather than by instance ID. If you terminate and replace an EC2 instance, the new instance gets the same `role=webserver` tag and CodeDeploy automatically finds it. This is how blue-green deployments work at scale — spin up new instances with the tag, deploy to them, then remove the tag (or terminate) the old ones.

![CodeDeploy deployment group showing EC2 tag filter configuration](https://raw.githubusercontent.com/kehindeabiuwa-dotcom/aws-cicd-pipeline/main/screenshots/p5-codedeploy-group.png)
*Deployment group targeting EC2 instances by tag — `role=webserver` rather than instance ID.*

---

## Step 5: Create and Run a Deployment

Create a deployment:
- Revision type: Amazon S3
- S3 location: The artifact ZIP from CodeBuild (e.g., `s3://nextwork-devops-cicd-artifacts-<account-id>/BuildArtifact/nextwork-web-project.zip`)

Watch the deployment lifecycle:
1. `ApplicationStop` — stops old services (or skips if nothing is running)
2. `BeforeInstall` — installs Tomcat, Apache, configures proxy
3. Files are copied from the artifact to `/usr/share/tomcat/webapps/`
4. `ApplicationStart` — starts services
5. `ValidateService` — checks the app is responding

<!-- TODO: Add screenshot p5-deploy-success.png — CodeDeploy deployment showing all lifecycle hooks with green checkmarks -->

After the deployment succeeds, open the EC2 instance's public IP in a browser. You should see the Hello from NextWork CI/CD Pipeline! page served by Tomcat through Apache.

![The web application live in a browser after deployment](https://raw.githubusercontent.com/kehindeabiuwa-dotcom/aws-cicd-pipeline/main/screenshots/p5-webapp-live.png)
*The deployed web application — served from Tomcat through Apache on the EC2 instance.*

---

## Step 6 (Extension): Simulating a Failed Deployment and Rollback

This is one of the most valuable things to practice — understanding what happens when a deployment fails.

Deliberately break `stop_server.sh`:

```bash
#!/bin/bash
systemctll stop httpd.service  # typo — extra 'l'
exit 1                         # explicit failure
```

Push, trigger a build, and create a new deployment with the broken artifact. With rollback enabled, you'll see:

1. Deployment starts
2. `ApplicationStop` runs the broken script — `exit 1`
3. CodeDeploy marks the deployment as FAILED
4. CodeDeploy automatically starts a rollback — redeploying the last successful revision from S3
5. The application returns to the last known good state

![CodeDeploy deployment showing FAILED status and an automatic rollback deployment below it](https://raw.githubusercontent.com/kehindeabiuwa-dotcom/aws-cicd-pipeline/main/screenshots/p5-rollback.png)
*Automatic rollback triggered — CodeDeploy creates a new rollback deployment using the last successful artifact from S3.*

The key insight: rollback redeploys the **previous artifact from S3** — it does not re-run the build. Source and Build stages in CodePipeline are not re-triggered. This is why artifact versioning matters: the previous artifact must still exist in S3.

**Production rollback strategy:**
- Enable rollback on deployment failure
- Enable rollback on CloudWatch alarm (e.g., error rate > 1%)
- Use blue-green deployment behind an ALB for zero-downtime rollbacks
- Keep N-2 artifact versions in S3 (enable lifecycle rules to expire older ones)

---

## Key Design Decisions and Trade-offs

**AllAtOnce vs. HalfAtATime vs. OneAtATime:**

| Configuration | Speed | Downtime risk | Use case |
|---|---|---|---|
| `AllAtOnce` | Fastest | All instances update simultaneously | Single instance, dev/test |
| `HalfAtATime` | Medium | Half in service at all times | Small clusters |
| `OneAtATime` | Slowest | Maximum availability | Production, high-traffic |

For this project, `AllAtOnce` is appropriate because we have a single EC2 instance. In production, use `OneAtATime` or `HalfAtATime` to ensure continuous availability during deployments.

---

## Lessons Learned

**`stop_server.sh` must not fail on first deployment.** On the first deployment, nothing is running. `systemctl stop httpd.service` when httpd isn't installed exits with code 5 (service not found) — which CodeDeploy treats as a failure. Always check if the service exists before stopping it.

**`discard-paths: no` in buildspec.yml is not optional.** This is the most common CodeDeploy debugging issue. Without it, `scripts/start_server.sh` becomes `start_server.sh` at the artifact root, but `appspec.yml` still references `scripts/start_server.sh`. The hook script is not found. Deployment fails.

**The CodeDeploy agent must be running.** The agent polls the CodeDeploy service and must be running on every target instance. If it stops running (e.g., after an OS update), deployments stop reaching that instance silently. Always configure the agent to auto-restart on boot: `systemctl enable codedeploy-agent`.

---

## What's Next

In Part 6, we take all the infrastructure we've manually created — the VPC, EC2, IAM roles, CodeBuild project, CodeDeploy deployment group — and codify it in a single CloudFormation template. Infrastructure as Code means reproducible, version-controlled, and auditable infrastructure.

**[Read Part 6 → Infrastructure as Code with CloudFormation: Turning Your CI/CD Stack into a Template](#)**

---

*Kehinde Abiuwa | AWS Solutions Architect Professional | AZ-305*
*[linkedin.com/in/kehinde-abiuwa-b68087247](https://www.linkedin.com/in/kehinde-abiuwa-b68087247)*
