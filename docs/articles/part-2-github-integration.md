---
title: "Version Control for Your CI/CD Pipeline: Connecting GitHub to AWS"
published: false
description: "Set up Git on EC2, push code to GitHub with a personal access token, and establish the source control workflow that will trigger your entire AWS CI/CD pipeline automatically."
tags: aws, git, devops, github
series: Building a Production CI/CD Pipeline on AWS
cover_image: https://github.com/kehindeabiuwa-dotcom/aws-cicd-pipeline/raw/main/screenshots/diagrams/part2-diagram.png
canonical_url:
---

# Part 2 — Version Control for Your CI/CD Pipeline: Connecting GitHub to AWS

**Series:** Building a Production CI/CD Pipeline on AWS (7-Part Series)
**Author:** Kehinde Abiuwa | AWS Solutions Architect Professional | AZ-305
**LinkedIn:** [linkedin.com/in/kehinde-abiuwa-b68087247](https://www.linkedin.com/in/kehinde-abiuwa-b68087247)

---

## The Role of Source Control in CI/CD

A CI/CD pipeline needs somewhere to watch. It monitors a repository for changes, and every new commit is the event that kicks everything else off. Without this, you're just running build scripts manually — that's not CI/CD, that's just automation.

In this part, we set up Git on the EC2 instance, connect the local repository to GitHub, and establish the workflow that will later trigger CodeBuild and CodeDeploy automatically.

We'll also cover something that trips up many beginners: GitHub deprecated password authentication over HTTPS, so you need to use a personal access token instead — and we'll explain exactly why this change was made and what it means for security.

---

## What We're Building

```
EC2 Instance (nextwork-web-project/)
        │  git push (HTTPS + personal access token)
        ▼
GitHub Repository (kehindeabiuwa-dotcom/nextwork-web-project)
        │  (in Part 7) webhook → CodePipeline trigger
        ▼
CodePipeline Source Stage
```

The GitHub repository becomes the single source of truth for your application code. Every pipeline run starts here.

---

## Step 1: Install Git on EC2

SSH into your EC2 instance (see Part 1) and install Git:

```bash
sudo dnf update -y
sudo dnf install -y git
```

Verify:

```bash
git --version
# git version 2.x.x
```

---

## Step 2: Set Your Git Identity

Git requires a name and email for every commit it creates. This is how the version history records who made each change — critical for team collaboration and audit trails.

```bash
git config --global user.name "Kehinde Abiuwa"
git config --global user.email "abiuwakehinde96@outlook.com"
```

These values are stored in `~/.gitconfig` and applied to every repository on this machine.

---

## Step 3: Create a GitHub Repository

Go to [github.com](https://github.com), click **New repository**, and configure it:
- **Repository name:** `nextwork-web-project`
- **Visibility:** Public (so CodePipeline can access it without additional authentication setup)
- **Initialize with README:** No — we'll push our existing code

Copy the repository URL: `https://github.com/<your-username>/nextwork-web-project.git`

---

## Step 4: Initialise and Connect the Local Repository

On your EC2 instance, navigate to the project directory and initialise Git:

```bash
cd ~/nextwork-web-project
git init
git remote add origin https://github.com/<your-username>/nextwork-web-project.git
```

`git init` creates a hidden `.git/` directory that tracks all changes. `git remote add origin` tells your local repository where to push changes — the GitHub repository is now the "origin" remote.

---

## Step 5: Stage, Commit, and Push

```bash
git add .
git commit -m "Initial commit: Java web app scaffold"
git push -u origin master
```

**What each command does:**

| Command | What it does |
|---|---|
| `git add .` | Stages all changes — moves them into the "staging area" ready to be committed |
| `git commit -m "..."` | Saves a snapshot of the staged changes to the local repository history |
| `git push -u origin master` | Uploads the local `master` branch to GitHub; `-u` sets `origin/master` as the tracking branch so future pushes only need `git push` |

![Terminal showing successful git push output with branch tracking](https://github.com/kehindeabiuwa-dotcom/aws-cicd-pipeline/raw/main/screenshots/p2-git-push-output.png)
*The `git push -u origin master` output confirming the branch is now tracking the remote.*

---

## Step 6: The Authentication Problem and Why It Exists

When Git asks for your credentials during the push, entering your GitHub password will fail with:

```
remote: Support for password authentication was removed on August 13, 2021.
remote: Please see https://docs.github.com/en/get-started/getting-started-with-git/about-remote-repositories#cloning-with-https-urls
fatal: Authentication failed for 'https://github.com/...'
```

**Why did GitHub remove password authentication?**
Passwords are a weak authentication factor for automated systems. If a developer's GitHub password is leaked (via a phishing attack, password reuse, or a data breach), an attacker gets full account access including the ability to push malicious code to all repositories. Personal access tokens are scoped (you define exactly what they can do) and can be revoked individually without changing the account password.

This is exactly the reasoning behind AWS's IAM: least-privilege, individually revocable, scoped credentials.

---

## Step 7: Create a GitHub Personal Access Token

1. Log in to GitHub → **Settings** → **Developer settings** → **Personal access tokens** → **Tokens (classic)**
2. Click **Generate new token (classic)**
3. Set an expiration date (90 days recommended for security)
4. Select scopes:
   - ✅ `repo` — full repository access (needed to push code)
5. Click **Generate token** and **copy it immediately** — GitHub only shows it once

When Git asks for your password during the push, paste the token instead. Git will store it in the OS credential manager so you don't need to enter it again on subsequent pushes.

![GitHub personal access token generation page](https://github.com/kehindeabiuwa-dotcom/aws-cicd-pipeline/raw/main/screenshots/p2-github-token.png)
*GitHub personal access token generated — copy it immediately, it's only shown once.*

---

## Step 8: Verify the Push

After a successful push, go to your GitHub repository in a browser. You should see all your project files including `pom.xml`, `src/`, and `index.jsp`.

![GitHub repository showing the pushed project files](https://github.com/kehindeabiuwa-dotcom/aws-cicd-pipeline/raw/main/screenshots/p2-github-repo-files.png)
*The GitHub repository after the first push — all project files and the initial commit message visible.*

---

## Step 9: Test the Workflow — Edit, Commit, Push

To confirm version control is working end-to-end, make a small change to `index.jsp`, stage, commit, and push:

```bash
# Edit index.jsp with VS Code (via Remote-SSH) or nano
nano src/main/webapp/index.jsp

git add src/main/webapp/index.jsp
git commit -m "Update homepage content"
git push
```

Go to GitHub — you should see the new commit and the updated file. The commit message, timestamp, and author are all recorded.

<!-- TODO: Add screenshot p2-commit-history.png — GitHub commit history showing at least 2 commits -->

---

## Step 10: Add a README

A README is the first thing anyone sees when they visit your repository. It signals professionalism, explains what the project does, and is considered essential for any public repository.

Create `README.md` at the project root:

```markdown
# NextWork Web Project

A Java web application built as part of an end-to-end CI/CD pipeline series on AWS.

## Pipeline
GitHub → CodeBuild → CodeDeploy → EC2

## Tech Stack
- Java 8 (Amazon Corretto)
- Apache Maven
- AWS EC2, CodeBuild, CodeDeploy, CodePipeline, CodeArtifact

## Author
Kehinde Abiuwa
```

```bash
git add README.md
git commit -m "Add README"
git push
```

---

## Key Design Decisions and Trade-offs

**Personal access tokens vs. GitHub Apps vs. SSH keys:**

| Method | Security | Use case |
|---|---|---|
| Password | ❌ Deprecated | Never use |
| Personal access token (classic) | ✅ Good | Personal projects, CLI access |
| Fine-grained personal access token | ✅ Better | Scoped to specific repos |
| GitHub App | ✅ Best | Organisation, CI/CD (CodePipeline uses this via CodeConnections) |
| SSH keys | ✅ Good | Developer machines, no HTTPS |

For the pipeline in Part 4, CodeBuild uses **AWS CodeConnections with a GitHub App** — not a personal access token. The GitHub App is managed by AWS, rotates credentials automatically, and doesn't require you to handle tokens. Personal access tokens are fine for your local git operations on EC2, but the pipeline itself uses the more secure GitHub App integration.

---

## Lessons Learned

**`git commit` is local; `git push` is what sends changes to GitHub.** This is the most common confusion for beginners. You can commit many times locally and push them all at once. If you're not seeing changes on GitHub, you forgot to push.

**`git log` is your friend.** After pushing, run `git log --oneline` to see a clean history of commits. This becomes invaluable in Part 7 when you're watching which commit SHA flows through each pipeline stage.

**The `-u` flag on your first push is important.** Running `git push -u origin master` sets the upstream tracking relationship. After that, a plain `git push` knows where to send changes. Without `-u`, you'd need to specify `origin master` every time.

---

## What's Next

In Part 3, we set up AWS CodeArtifact to act as a private, controlled package repository for Maven dependencies. Instead of pulling libraries directly from Maven Central — a public source you don't control — CodeArtifact acts as a secure proxy, caches approved packages, and lets you publish internal libraries.

**[Read Part 3 → Secure Package Management with AWS CodeArtifact](#)**

---

*Kehinde Abiuwa | AWS Solutions Architect Professional | AZ-305*
*[linkedin.com/in/kehinde-abiuwa-b68087247](https://www.linkedin.com/in/kehinde-abiuwa-b68087247)*
