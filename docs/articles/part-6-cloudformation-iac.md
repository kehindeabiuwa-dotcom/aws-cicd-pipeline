![Architecture diagram for Part 6](https://raw.githubusercontent.com/kehindeabiuwa-dotcom/aws-cicd-pipeline/main/screenshots/diagrams/part6-diagram.png)

# Part 6 — Infrastructure as Code with CloudFormation: Turning a 5-Hour Setup into a 5-Minute Stack

**Series:** Building a Production CI/CD Pipeline on AWS (7-Part Series)
**Author:** Kehinde Abiuwa | AWS Solutions Architect Professional | AZ-305
**LinkedIn:** [linkedin.com/in/kehinde-abiuwa-b68087247](https://www.linkedin.com/in/kehinde-abiuwa-b68087247)

---

## The Infrastructure Problem

By this point in the series, we've manually created: a VPC, subnet, internet gateway, route table, security group, EC2 instance, IAM instance role with CodeArtifact policy, IAM CodeBuild service role with multiple policies, IAM CodeDeploy service role, an S3 artifact bucket, a CodeArtifact domain and repository, a CodeBuild project, a CodeDeploy application and deployment group.

If you need to rebuild this environment — in a new account, a different region, for a colleague, or after accidentally deleting a resource — you're looking at hours of console clicking, remembering exactly which settings you used, and hoping you didn't miss anything.

Infrastructure as Code solves this. A CloudFormation template is a YAML or JSON file that describes every resource and its configuration. Running that template through CloudFormation creates the entire stack in the correct dependency order, in minutes, consistently every time.

---

## What We're Building

```
cicd-stack.yaml (CloudFormation template)
        │  aws cloudformation deploy
        ▼
CloudFormation Stack: NextWorkCICDStack
  ├── VPC + Subnet + IGW + Route Table
  ├── Security Group
  ├── EC2 Instance (with CodeDeploy agent via UserData)
  ├── IAM Roles (EC2, CodeBuild, CodeDeploy, CodePipeline)
  ├── IAM Policies (scoped to least privilege)
  ├── S3 Artifact Bucket (versioned, encrypted)
  ├── CodeArtifact Domain + Repository
  ├── CodeBuild Project
  ├── CodeDeploy Application + Deployment Group
  └── CodePipeline (Source → Build → Deploy)
```

One file. One command. Everything.

---

## Step 1: Use the IaC Generator to Scaffold Your Template

AWS provides an IaC Generator tool that can scan your existing resources and generate a draft CloudFormation template. This is an excellent starting point — it captures most infrastructure but requires manual additions for some complex resources.

In the CloudFormation console → **IaC Generator** → **Create template**:
1. Select all your existing CI/CD resources (EC2 instance, security group, VPC, IAM roles, S3 bucket)
2. Let the generator scan and produce a draft

**What the generator captures well:**
- EC2 instances, their network interfaces, security groups, subnets, EBS volumes
- IAM roles
- S3 buckets

**What the generator cannot capture:**
- CodeBuild projects (too many runtime configuration details)
- CodeDeploy deployment groups (sensitive permission configurations)
- CodePipeline (complex connection configurations)

These must be written manually and appended to the template.

<!-- TODO: Add screenshot p6-iac-generator.png — CloudFormation IaC Generator scanning existing resources -->

---

## Step 2: Understanding the Template Structure

A CloudFormation template has these main sections:

```yaml
AWSTemplateFormatVersion: "2010-09-09"
Description: "Human-readable description of what this template does"

Parameters:
  # Input values that can be passed at deploy time
  # Makes templates reusable across environments

Resources:
  # The actual AWS resources to create (required)
  # Each resource has a logical ID, Type, and Properties

Outputs:
  # Values to export after stack creation
  # E.g., the web app URL, bucket name, pipeline name
```

**Parameters make templates environment-agnostic:**

```yaml
Parameters:
  GitHubOwner:
    Type: String
    Description: GitHub account name

  InstanceType:
    Type: String
    Default: t3.micro
    AllowedValues: [t3.micro, t3.small, t3.medium]

  LatestAmazonLinuxAmi:
    Type: AWS::SSM::Parameter::Value<AWS::EC2::Image::Id>
    Default: /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64
```

The `AWS::SSM::Parameter::Value<AWS::EC2::Image::Id>` type is particularly powerful — it automatically resolves the latest Amazon Linux AMI ID at deploy time. No hardcoded AMI IDs that expire.

---

## Step 3: First Failure — IAM Policy Creation Order

When you first deploy the template with IAM roles and policies, you'll hit:

```
Resource handler returned message:
"The role with name IAMRoleCodebuildnextworkdevopscicdservicerole
cannot be found." (HandlerErrorCode: InvalidRequest)
```

**Why?** CloudFormation creates resources in parallel where it can. If an IAM policy that must be attached to a role is created before the role exists, the attachment fails.

**Fix: `DependsOn`**

```yaml
CodeBuildBasePolicy:
  Type: AWS::IAM::ManagedPolicy
  DependsOn: CodeBuildServiceRole   # ← wait for the role before creating this policy
  Properties:
    Roles:
      - !Ref CodeBuildServiceRole
    PolicyDocument:
      # ...
```

The `DependsOn` attribute tells CloudFormation: create this resource only after the specified resource is complete. Use it whenever you have a resource that references another resource that might not be ready yet.

---

## Step 4: Second Failure — Circular Dependency

After fixing the creation order, you hit a new error:

```
Circular dependency between resources: [CodeBuildServiceRole, CodeBuildBasePolicy,
CodeBuildCloudWatchPolicy, CodeBuildCodeArtifactPolicy]
```

**Why?** The IaC Generator captured the IAM role's existing managed policy attachments directly in the role's `ManagedPolicyArns`. The role references the policies, and the policies (with `DependsOn`) reference the role. A→B and B→A = circular.

**Fix:** Remove the `ManagedPolicyArns` from the role definition. Let the policies declare which role they belong to (via `Roles:`) — that's a one-directional dependency.

```yaml
# WRONG - creates circular dependency
CodeBuildServiceRole:
  Type: AWS::IAM::Role
  Properties:
    ManagedPolicyArns:
      - !Ref CodeBuildBasePolicy     # ← policy depends on role, role depends on policy
      - !Ref CodeBuildCloudWatchPolicy

# CORRECT - one-directional
CodeBuildServiceRole:
  Type: AWS::IAM::Role
  Properties:
    # No ManagedPolicyArns here

CodeBuildBasePolicy:
  Type: AWS::IAM::ManagedPolicy
  DependsOn: CodeBuildServiceRole
  Properties:
    Roles:
      - !Ref CodeBuildServiceRole   # ← policy knows about role, role doesn't know about policy
```

This is a common CloudFormation pitfall. The IaC Generator captures state accurately but doesn't always produce dependency-safe templates.

![CloudFormation stack showing a failure event in the Events tab](https://raw.githubusercontent.com/kehindeabiuwa-dotcom/aws-cicd-pipeline/main/screenshots/p6-stack-failure.png)
*A CloudFormation circular dependency error — the Events tab shows exactly which resource caused the failure.*

---

## Step 5: Manually Add CodeBuild and CodeDeploy Resources

Add the CodeBuild project to the template:

```yaml
CodeBuildProject:
  Type: AWS::CodeBuild::Project
  Properties:
    Name: nextwork-devops-cicd
    ServiceRole: !GetAtt CodeBuildServiceRole.Arn
    Source:
      Type: GITHUB
      Location: !Sub "https://github.com/${GitHubOwner}/${GitHubRepo}.git"
      BuildSpec: buildspec.yml
    Environment:
      Type: LINUX_CONTAINER
      ComputeType: BUILD_GENERAL1_SMALL
      Image: aws/codebuild/standard:7.0
    Artifacts:
      Type: S3
      Location: !Ref ArtifactBucket
      Packaging: ZIP
    LogsConfig:
      CloudWatchLogs:
        Status: ENABLED
```

Add the CodeDeploy deployment group:

```yaml
CodeDeployDeploymentGroup:
  Type: AWS::CodeDeploy::DeploymentGroup
  Properties:
    ApplicationName: !Ref CodeDeployApplication
    DeploymentGroupName: nextwork-devops-cicd-deploymentgroup
    ServiceRoleArn: !GetAtt CodeDeployServiceRole.Arn
    DeploymentConfigName: CodeDeployDefault.AllAtOnce
    Ec2TagFilters:
      - Key: role
        Value: webserver
        Type: KEY_AND_VALUE
    AutoRollbackConfiguration:
      Enabled: true
      Events:
        - DEPLOYMENT_FAILURE
```

**Use `!Ref` and `!GetAtt` to reference other resources:**
- `!Ref` returns the logical ID or primary identifier of a resource
- `!GetAtt` returns a specific attribute (like the ARN of a role)

Consistent references are what prevent circular dependencies. If you use a hardcoded string where you should use `!Ref`, you introduce a hidden dependency that CloudFormation can't track.

---

## Step 6: Deploy the Stack

```bash
aws cloudformation deploy \
  --template-file infrastructure/cloudformation/cicd-stack.yaml \
  --stack-name NextWorkCICDStack \
  --parameter-overrides \
    GitHubOwner=kehindeabiuwa-dotcom \
    GitHubRepo=nextwork-web-project \
    GitHubConnectionArn=arn:aws:codeconnections:eu-north-1:<account-id>:connection/<id> \
    KeyPairName=NextWorkkeypair \
  --capabilities CAPABILITY_NAMED_IAM
```

The `--capabilities CAPABILITY_NAMED_IAM` flag is required when the template creates IAM resources with custom names. CloudFormation requires explicit acknowledgement that you understand the IAM implications.

![CloudFormation stack in CREATE_COMPLETE status with all resources listed](https://raw.githubusercontent.com/kehindeabiuwa-dotcom/aws-cicd-pipeline/main/screenshots/p6-stack-success.png)
*The complete stack deployed successfully — every resource created in the correct dependency order from a single YAML file.*

---

## Key Design Decisions and Trade-offs

**CloudFormation vs. Terraform:**

| Factor | CloudFormation | Terraform |
|---|---|---|
| Native AWS support | ✅ First-class | Via provider (maintained by HashiCorp) |
| Multi-cloud | ❌ AWS only | ✅ AWS, Azure, GCP, and more |
| State management | AWS manages (Stack state) | Requires state backend (S3 + DynamoDB) |
| Drift detection | Built in | `terraform plan` shows drift |
| Community modules | Limited | Extensive Registry |
| Learning curve | Medium | Medium-high (HCL syntax) |

For AWS-only workloads, CloudFormation is the native choice and integrates seamlessly with all AWS services. Terraform is better when you need to manage infrastructure across multiple cloud providers or want access to the large open-source module ecosystem.

This project uses both — CloudFormation for the CI/CD pipeline (Part 6-7), and Terraform for S3 buckets (the bonus article) — so you can evaluate both firsthand.

---

## Lessons Learned

**Delete the stack before testing the template.** CloudFormation will not create a resource that already exists by name (for most resource types). If you've created resources manually and then try to create a stack with the same names, you'll get `ResourceAlreadyExists` errors. Delete the manual resources first.

**The IaC Generator is a starting point, not a final output.** It gets you 70-80% of the way there. The remaining 20-30% — dependency ordering, circular dependencies, manual resources like CodeBuild/CodeDeploy — always requires manual editing.

**Tag every resource.** Every resource in the template should have a `Tags` block with at least `Name`, `Environment`, and `Project`. When your AWS bill arrives with 50 EC2 charges and you can't tell which instance belongs to which project, you'll understand why.

---

## What's Next

In Part 7, we complete the pipeline by adding AWS CodePipeline — the orchestrator that connects GitHub, CodeBuild, and CodeDeploy into a single automated workflow. We'll test it with a live commit, watch the pipeline execute in real time, and demonstrate automated rollback.

**[Read Part 7 → Building the Full CI/CD Pipeline: GitHub → CodeBuild → CodeDeploy with CodePipeline](https://dev.to/kehindeabiuwadotcom/the-full-cicd-pipeline-one-git-push-three-stages-zero-manual-steps-3e4-temp-slug-5148435?preview=4ccc739bbf0465d67317cce4b507710d8099111bcf901b2e008b8c94d0c3e8fa258969c2312a2c505a78fb98b41522e9cfde71ff119c4097737120c3)**

---

*Kehinde Abiuwa | AWS Solutions Architect Professional | AZ-305*
*[linkedin.com/in/kehinde-abiuwa-b68087247](https://www.linkedin.com/in/kehinde-abiuwa-b68087247)*
