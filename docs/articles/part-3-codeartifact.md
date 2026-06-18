---
title: "Secure Package Management: Why You Shouldn't Pull from Maven Central in Production"
published: false
description: "Set up AWS CodeArtifact as a private Maven proxy to prevent dependency confusion attacks, cache approved packages, and control exactly what your builds can download."
tags: aws, devops, security, java
series: Building a Production CI/CD Pipeline on AWS
cover_image: https://github.com/kehindeabiuwa-dotcom/aws-cicd-pipeline/raw/main/screenshots/diagrams/part3-diagram.png
canonical_url:
---

# Part 3 — Secure Package Management: Why You Shouldn't Pull from Maven Central in Production

**Series:** Building a Production CI/CD Pipeline on AWS (7-Part Series)
**Author:** Kehinde Abiuwa | AWS Solutions Architect Professional | AZ-305
**LinkedIn:** [linkedin.com/in/kehinde-abiuwa-b68087247](https://www.linkedin.com/in/kehinde-abiuwa-b68087247)

---

## The Problem with Public Package Repositories

When Maven compiles a Java project, it downloads dependencies — libraries your code uses — from a repository. The default is Maven Central, a public registry that anyone can publish to.

The risk: a malicious actor publishes a package with a name similar to a popular library (typosquatting), or a legitimate maintainer's account gets compromised and a backdoored version is pushed. Your build system faithfully downloads and executes that code.

In 2021, a researcher demonstrated this exact attack, called dependency confusion, against Apple, Microsoft, and Netflix — all of which had internal package names that could be hijacked by publishing a public package with the same name. The fix is a private artifact repository that controls which packages your builds are allowed to use.

AWS CodeArtifact is that private repository for AWS-native CI/CD pipelines.

---

## What We're Building

```
EC2 / CodeBuild (Maven client)
        │  Authenticates with short-lived token
        ▼
CodeArtifact Repository (nextwork-devops-cicd)
        │  Upstream: Maven Central
        ▼
Maven Central (only fetched if not already cached)
```

Maven always talks to CodeArtifact. CodeArtifact proxies to Maven Central only if the package isn't already cached. Once cached, your builds don't need internet access to that package again.

---

## Step 1: Create a CodeArtifact Domain and Repository

**What is a domain?**
A CodeArtifact domain is the top-level container. You apply permissions once at the domain level, and they propagate to all repositories inside it. For a single-team project, one domain is sufficient.

In the AWS Console, navigate to **CodeArtifact** → **Domains** → **Create domain**:
- **Domain name:** `nextwork-devops-cicd`

Then create a repository inside the domain:
- **Repository name:** `nextwork-devops-cicd`
- **Upstream repositories:** Add `maven-central-store` (the AWS-managed public Maven Central proxy)

The upstream connection means: when Maven requests a dependency, CodeArtifact checks its own cache first, then fetches from Maven Central if needed, and caches it for future builds.

![CodeArtifact domain and repository with Maven Central upstream configured](https://github.com/kehindeabiuwa-dotcom/aws-cicd-pipeline/raw/main/screenshots/p3-codeartifact-repo.png)
*The CodeArtifact repository with Maven Central set as the upstream source.*

---

## Step 2: Fix the IAM Permission Error

When you first try to authenticate with CodeArtifact from EC2, you'll hit an error:

```
An error occurred (UnrecognizedClientException) when calling the
GetAuthorizationToken operation: The security token included in the request is invalid.
```

**Why does this happen?**
By default, EC2 instances have no IAM permissions. AWS follows the principle of least privilege — resources get only the minimum access required. An EC2 instance without an attached IAM role has no access to any other AWS service.

**The fix:**

1. **Create an IAM policy** with the exact permissions needed for CodeArtifact:

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
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "sts:AWSServiceName": "codeartifact.amazonaws.com"
        }
      }
    }
  ]
}
```

2. **Create an IAM role** with EC2 as the trusted service and attach the policy.

3. **Attach the role to your EC2 instance** via Actions → Security → Modify IAM role.

**Why use an IAM role instead of access keys?**
IAM roles provide temporary, automatically rotated credentials. Long-lived access keys stored on an EC2 instance are a security liability — if the instance is compromised, the attacker has permanent access. With an IAM role, the credentials expire (typically every hour) and rotate automatically. There are no keys to leak.

This is security best practice that applies to every AWS service — not just CodeArtifact.

![IAM role attached to EC2 instance in the Modify IAM role dialog](https://github.com/kehindeabiuwa-dotcom/aws-cicd-pipeline/raw/main/screenshots/p3-iam-role-attached.png)
*Attaching the IAM role to the EC2 instance — this grants the instance permission to authenticate with CodeArtifact.*

---

## Step 3: Authenticate Maven with CodeArtifact

CodeArtifact uses short-lived authorization tokens (12 hours max). You get a token by calling the CodeArtifact API, then pass it to Maven via an environment variable:

```bash
export CODEARTIFACT_AUTH_TOKEN=$(aws codeartifact get-authorization-token \
  --domain nextwork-devops-cicd \
  --domain-owner $(aws sts get-caller-identity --query Account --output text) \
  --query authorizationToken \
  --output text)
```

Then configure Maven's `settings.xml` to use CodeArtifact as its package source:

```xml
<settings>
  <servers>
    <server>
      <id>nextwork-devops-cicd</id>
      <username>aws</username>
      <password>${env.CODEARTIFACT_AUTH_TOKEN}</password>
    </server>
  </servers>

  <profiles>
    <profile>
      <id>nextwork-devops-cicd</id>
      <repositories>
        <repository>
          <id>nextwork-devops-cicd</id>
          <url>https://nextwork-devops-cicd-<account-id>.d.codeartifact.<region>.amazonaws.com/maven/nextwork-devops-cicd/</url>
        </repository>
      </repositories>
    </profile>
  </profiles>

  <activeProfiles>
    <activeProfile>nextwork-devops-cicd</activeProfile>
  </activeProfiles>

  <mirrors>
    <mirror>
      <id>nextwork-devops-cicd</id>
      <mirrorOf>*</mirrorOf>
      <url>https://nextwork-devops-cicd-<account-id>.d.codeartifact.<region>.amazonaws.com/maven/nextwork-devops-cicd/</url>
    </mirror>
  </mirrors>
</settings>
```

The `<mirrorOf>*</mirrorOf>` tells Maven to route **all** dependency requests through CodeArtifact — not just ones for your internal packages. This is what gives you full visibility and control.

---

## Step 4: Compile and Verify

Run a Maven compile using the CodeArtifact settings:

```bash
mvn compile -s settings.xml
```

Watch the output — you'll see Maven downloading packages. Now go back to the CodeArtifact console and check your repository. You should see all the downloaded dependencies listed there, cached for future builds.

![CodeArtifact repository showing cached Maven dependencies](https://github.com/kehindeabiuwa-dotcom/aws-cicd-pipeline/raw/main/screenshots/p3-maven-deps-cached.png)
*Maven dependencies now cached in CodeArtifact — subsequent builds don't need to hit Maven Central.*

This is the "pull-through cache" model in action. First build: slow (fetches from Maven Central). Every build after: fast (cached in CodeArtifact, no external call needed).

---

## Step 5 (Extension): Publish an Internal Package

CodeArtifact isn't just for proxying public packages — you can publish your own private packages to it. This is useful for shared internal libraries: utility code, company-specific wrappers, internal APIs — kept private and available only to your AWS account.

To demonstrate, we'll create and publish a simple generic package:

```bash
# Create a test file
echo "Internal library v1.0.0 - NextWork DevOps" > internal-lib.txt

# Compress it into a tar.gz archive
tar -czvf internal-lib.tar.gz internal-lib.txt

# Generate SHA-256 checksum for integrity verification
shasum -a 256 internal-lib.tar.gz > internal-lib.tar.gz.sha256

# Publish to CodeArtifact
aws codeartifact publish-package-version \
  --domain nextwork-devops-cicd \
  --repository nextwork-devops-cicd \
  --format generic \
  --namespace my-org \
  --package internal-lib \
  --package-version 1.0.0 \
  --asset-name internal-lib.tar.gz \
  --asset-sha256 $(cat internal-lib.tar.gz.sha256 | cut -d' ' -f1) \
  --asset-content internal-lib.tar.gz
```

Download and verify it:

```bash
aws codeartifact get-package-version-asset \
  --domain nextwork-devops-cicd \
  --repository nextwork-devops-cicd \
  --format generic \
  --namespace my-org \
  --package internal-lib \
  --package-version 1.0.0 \
  --asset internal-lib.tar.gz \
  downloaded-lib.tar.gz

tar -xzvf downloaded-lib.tar.gz
cat internal-lib.txt
# Internal library v1.0.0 - NextWork DevOps ✓
```

The SHA-256 checksum is the mechanism that verifies the package wasn't corrupted or tampered with in transit. This is how package integrity is guaranteed in professional artifact management.

![CodeArtifact repository showing the published internal package](https://github.com/kehindeabiuwa-dotcom/aws-cicd-pipeline/raw/main/screenshots/p3-custom-package.png)
*Custom internal package published to CodeArtifact — private libraries that will never appear in Maven Central.*

---

## Key Design Decisions and Trade-offs

**Why CodeArtifact over running your own Nexus/Artifactory?**

| Factor | CodeArtifact | Self-managed Nexus/Artifactory |
|---|---|---|
| Operational overhead | None (managed service) | High (patching, backups, HA) |
| Cost | Pay per request + storage | EC2 + EBS costs, always running |
| IAM integration | Native | Requires custom config |
| HA / disaster recovery | Built in | Your responsibility |
| Migration effort | Low (upstream connectors) | Higher |

For a team that's already on AWS, CodeArtifact is almost always the right choice. Self-managed options make sense if you need cross-cloud compatibility or specific enterprise features.

---

## Lessons Learned

**The token expiry is intentional.** CodeArtifact tokens last up to 12 hours. In CI/CD, you generate a fresh token at the start of every build (in the `pre_build` phase of `buildspec.yml`). This is a deliberate security design — short-lived credentials limit blast radius. Even if a token leaks, it's only useful for a few hours.

**The `mirrorOf: *` setting routes everything through CodeArtifact.** This is powerful but has an implication: if CodeArtifact is unavailable (outage, permission issue), your builds fail even for packages that would otherwise be available from Maven Central. This is the trade-off between security control and availability.

**IAM roles on EC2 are free.** There is no cost to attaching an IAM role. The common mistake is omitting the role, storing access keys in a `.env` file on the instance, and then wondering why they get leaked. Always use roles.

---

## What's Next

In Part 4, we set up AWS CodeBuild to automate everything we've done manually in the build phase — installing dependencies, compiling, running tests, and packaging the WAR file — triggered automatically on every push to GitHub.

**[Read Part 4 → Continuous Integration with AWS CodeBuild: Automating Your Build Pipeline](#)**

---

*Kehinde Abiuwa | AWS Solutions Architect Professional | AZ-305*
*[linkedin.com/in/kehinde-abiuwa-b68087247](https://www.linkedin.com/in/kehinde-abiuwa-b68087247)*
