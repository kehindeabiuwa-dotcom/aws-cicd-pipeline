![Architecture diagram for Part 1](https://raw.githubusercontent.com/kehindeabiuwa-dotcom/aws-cicd-pipeline/main/screenshots/diagrams/part1-diagram.png)

# Part 1 — Setting Up a Cloud Development Environment: EC2, SSH, and VS Code

**Series:** Building a Production CI/CD Pipeline on AWS (7-Part Series)
**Author:** Kehinde Abiuwa | AWS Solutions Architect Professional | AZ-305
**LinkedIn:** [linkedin.com/in/kehinde-abiuwa-b68087247](https://www.linkedin.com/in/kehinde-abiuwa-b68087247)

---

## Why This Series Exists

Before you can automate anything, you need something to automate. This series walks through building a complete, production-grade CI/CD pipeline on AWS from scratch — starting with a simple Java web application running on an EC2 instance, all the way through to a fully automated pipeline where a `git push` triggers a build, test, and deployment without a single manual step.

By the end of this 7-part series, you will have built:
- A cloud development environment with EC2 and VS Code Remote-SSH
- GitHub integration for version control and pipeline triggers
- AWS CodeArtifact for private, secure dependency management
- AWS CodeBuild for automated compilation and testing
- AWS CodeDeploy for zero-touch deployments with rollback
- A full CloudFormation template that provisions the entire infrastructure as code
- A CodePipeline that connects all the above into a single automated workflow

Everything we build is production-minded. That means IAM least-privilege, Infrastructure as Code from day one, rollback strategies, and avoiding the shortcuts that cause production incidents.

Let's start at the foundation.

---

## What We're Building in This Part

A cloud-hosted Java web application running on an Amazon EC2 instance, with VS Code on your local machine acting as the development IDE via Remote-SSH — so you can write, edit, and test code as if the files were on your local disk, even though they live on a remote server.

**Architecture for Part 1:**

```
Local Machine (VS Code + Remote-SSH extension)
        │  SSH over port 22 (key pair auth)
        ▼
EC2 Instance (Amazon Linux 2023)
  ├── Java + Maven installed
  ├── nextwork-web-project/ (Java web app)
  └── index.jsp (the page we'll edit and eventually deploy)
```

---

## Step 1: Launch an EC2 Instance

EC2 (Elastic Compute Cloud) is AWS's virtual machine service. For this project, we need a Linux server that can host our Java application and run the build and deployment tools we'll add in later parts.

**Why Amazon Linux 2023 specifically?**
Amazon Linux 2023 (AL2023) is AWS's latest general-purpose Linux distribution. Compared to Amazon Linux 2, it uses `dnf` instead of `yum`, ships with more recent package versions, and has a longer support lifecycle. Since we'll be installing Maven, Java, Tomcat, and eventually the CodeDeploy agent, we want a stable, modern base.

**Configuration choices:**
- **Instance type:** `t3.micro` is sufficient for development. We'll upgrade in production.
- **Key pair:** AWS generates an RSA key pair and downloads the `.pem` private key to your machine. **This is the only time you get the private key — do not lose it.**
- **Security group:** Allow SSH (port 22) from your IP only. Avoid `0.0.0.0/0` in production — it exposes SSH to the entire internet.
- **Storage:** Default 8GB gp3 EBS volume is fine.

<!-- TODO: Add screenshot p1-ec2-running.png — EC2 console showing a running instance with the public IPv4 address visible -->

---

## Step 2: Secure Your Key and Connect via SSH

Once the instance is running, open your local terminal and set the correct permissions on your `.pem` file:

```bash
chmod 400 ~/Desktop/DevOps/NextWorkkeypair.pem
```

The `chmod 400` command makes the file readable only by you. SSH refuses to use a private key file with overly permissive permissions — this is a security feature, not a bug. Without this step, you'll hit a `WARNING: UNPROTECTED PRIVATE KEY FILE!` error and the connection will be refused.

Now connect:

```bash
ssh -i ~/Desktop/DevOps/NextWorkkeypair.pem ec2-user@<your-public-ipv4>
```

When you see `[ec2-user@ip-10-0-x-x ~]$` in your terminal, you're on the server.

![Terminal showing a successful SSH connection to the EC2 instance](https://raw.githubusercontent.com/kehindeabiuwa-dotcom/aws-cicd-pipeline/main/screenshots/p1-ssh-connected.png)
*Successful SSH connection — the `[ec2-user@...]$` prompt confirms you're on the server.*

---

## Step 3: Install Java and Maven

The web application we're building is a Java application managed by Apache Maven. Maven handles dependency management (downloading libraries), compilation, testing, and packaging — exactly what CodeBuild will automate in Part 4.

```bash
sudo dnf update -y
sudo dnf install -y java-1.8.0-amazon-corretto maven
```

Verify both are installed:

```bash
java -version
mvn -version
```

**Why Java 8 (Corretto)?**
Amazon Corretto is AWS's free, production-ready distribution of OpenJDK with long-term support. We use Java 8 because it aligns with the runtime we'll configure for CodeBuild. Consistency between your local environment and the build environment prevents the classic "it works on my machine" problem.

---

## Step 4: Generate the Java Web App with Maven

Maven's `archetype:generate` command scaffolds a complete project structure from a template (an "archetype"):

```bash
mvn archetype:generate \
  -DgroupId=com.nextwork.app \
  -DartifactId=nextwork-web-project \
  -DarchetypeArtifactId=maven-archetype-webapp \
  -DinteractiveMode=false
```

This creates the following structure:

```
nextwork-web-project/
├── pom.xml                          ← Maven project config (dependencies, build settings)
└── src/
    └── main/
        └── webapp/
            ├── WEB-INF/
            │   └── web.xml          ← Servlet configuration
            └── index.jsp            ← The main web page (what users see)
```

The `index.jsp` file is a JavaServer Pages file — it's HTML with embedded Java that gets processed by Tomcat (which we'll install in Part 5) before being sent to the browser.

---

## Step 5: Set Up VS Code with Remote-SSH

Editing files by SSH-ing in and using `nano` or `vim` works, but it's painful for anything beyond trivial edits. VS Code's Remote-SSH extension lets you work on the EC2 files exactly as if they were local — with syntax highlighting, file explorer, integrated terminal, and git integration.

**Install the extension:**
In VS Code, open Extensions (⌘+Shift+X), search for `Remote - SSH`, and install it.

**Configure the connection** by editing `~/.ssh/config` on your local machine:

```
Host nextwork-ec2
    HostName <your-ec2-public-ipv4>
    User ec2-user
    IdentityFile ~/Desktop/DevOps/NextWorkkeypair.pem
```

Then in VS Code, open the Command Palette (⌘+Shift+P), run **Remote-SSH: Connect to Host**, and select `nextwork-ec2`. VS Code installs a small server-side component on the EC2 instance and opens a new window connected to the remote filesystem.

![VS Code connected via Remote-SSH showing the nextwork-web-project folder](https://raw.githubusercontent.com/kehindeabiuwa-dotcom/aws-cicd-pipeline/main/screenshots/p1-vscode-remote.png)
*VS Code connected to the EC2 instance — note the green Remote-SSH indicator in the bottom-left corner.*

**Why this matters for DevOps:**
The Remote-SSH workflow mirrors how engineering teams work with remote development environments — whether that's a cloud VM, a Kubernetes pod, or a remote container. Getting comfortable with this workflow early is a career skill, not just a project shortcut.

---

## Step 6: Edit index.jsp

With VS Code connected, navigate to `nextwork-web-project/src/main/webapp/index.jsp` in the file explorer. Replace its default content with something you can visually verify after deployment:

```html
<html>
<body>
<h1>Hello from NextWork CI/CD Pipeline!</h1>
<p>This page is deployed via AWS CodeDeploy.</p>
</body>
</html>
```

Save the file. This change will eventually flow through the entire pipeline we're building — GitHub → CodeBuild → CodeDeploy → EC2.

![index.jsp open in VS Code with the edited HTML content](https://raw.githubusercontent.com/kehindeabiuwa-dotcom/aws-cicd-pipeline/main/screenshots/p1-indexjsp-edit.png)
*Editing index.jsp directly on the remote EC2 instance from VS Code.*

---

## Key Design Decisions and Trade-offs

| Decision | What I chose | Why | Production alternative |
|---|---|---|---|
| **Instance type** | t3.micro | Cost-effective for dev/learning | t3.medium+ for real workloads |
| **SSH key management** | Manual .pem download | Simple for a solo project | AWS Systems Manager Session Manager (no keys, no open port 22) |
| **Security group SSH rule** | Allow from your IP | Reduces exposure vs. 0.0.0.0/0 | SSM Session Manager eliminates port 22 entirely |
| **IDE** | VS Code Remote-SSH | Developer experience, feature-rich | Cloud9, Gitpod, or a local clone with git sync |
| **OS** | Amazon Linux 2023 | Native AWS integration, long support | Ubuntu 22.04 LTS (broader community support) |

The most important production recommendation is replacing SSH key pairs with **AWS Systems Manager Session Manager**. It eliminates the need for open port 22, stores no private keys, and provides a full audit trail of every session — all without a bastion host.

---

## Lessons Learned

**The `chmod 400` command is not optional.** Many beginners skip the permission step because it looks like a formality. SSH strictly enforces key file permissions as a security control. If you ever see `Permissions 0644 for '*.pem' are too open`, this is why.

**Your EC2 public IP changes on every restart.** In this series we use the instance's public IP address for SSH access. If you stop and start the instance, AWS assigns a new public IP. For a stable address, allocate an Elastic IP — but that costs money if the instance is stopped. For this project, just update your SSH config when the IP changes.

**Remote-SSH does not survive a VS Code update gracefully.** After a VS Code update, you may need to reconnect and let it reinstall the server component on EC2. This takes about 30 seconds and is expected.

---

## What's Next

In Part 2, we connect this EC2 environment to GitHub. We'll install Git, create a local repository, authenticate with a personal access token, and push our code to a remote repository — creating the source of truth that the rest of the CI/CD pipeline will monitor and build from.

**[Read Part 2 → Connecting GitHub to AWS: Version Control for Your CI/CD Pipeline](https://dev.to/kehindeabiuwadotcom/version-control-for-your-cicd-pipeline-connecting-github-to-aws-3n9l-temp-slug-7195219?preview=8c2805396fdd9cdf155939e20e2d20ecdc56f2e5eb9c497fac2b215713cef2c3a2bb97407bf9463c154674d8a6cf8bd0674fad6fd306ca18dc484d64)**

---

*Kehinde Abiuwa | AWS Solutions Architect Professional | AZ-305*
*[linkedin.com/in/kehinde-abiuwa-b68087247](https://www.linkedin.com/in/kehinde-abiuwa-b68087247)*
