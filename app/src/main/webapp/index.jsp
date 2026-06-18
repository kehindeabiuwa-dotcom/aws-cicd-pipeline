<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>NextWork CI/CD Pipeline Demo</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            background: linear-gradient(135deg, #232f3e 0%, #ff9900 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .card {
            background: white;
            border-radius: 12px;
            padding: 48px;
            max-width: 600px;
            width: 90%;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            text-align: center;
        }
        .badge {
            display: inline-block;
            background: #ff9900;
            color: white;
            padding: 4px 14px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 600;
            letter-spacing: 1px;
            text-transform: uppercase;
            margin-bottom: 24px;
        }
        h1 { color: #232f3e; font-size: 28px; margin-bottom: 12px; }
        p  { color: #555; line-height: 1.6; margin-bottom: 20px; }
        .pipeline {
            display: flex;
            justify-content: center;
            align-items: center;
            gap: 8px;
            margin: 24px 0;
            flex-wrap: wrap;
        }
        .stage {
            background: #f8f8f8;
            border: 2px solid #e0e0e0;
            border-radius: 8px;
            padding: 10px 18px;
            font-size: 13px;
            font-weight: 600;
            color: #232f3e;
        }
        .stage.active { border-color: #ff9900; color: #ff9900; }
        .arrow { color: #aaa; font-size: 18px; }
        .footer { margin-top: 32px; font-size: 12px; color: #aaa; }
        .footer strong { color: #232f3e; }
    </style>
</head>
<body>
    <div class="card">
        <div class="badge">Live Deployment</div>
        <h1>CI/CD Pipeline Demo</h1>
        <p>
            This page is served by a fully automated AWS CI/CD pipeline.
            Every push to <code>master</code> triggers a build in CodeBuild
            and an automated deployment via CodeDeploy — no manual steps required.
        </p>

        <div class="pipeline">
            <div class="stage">GitHub</div>
            <span class="arrow">→</span>
            <div class="stage">CodeBuild</div>
            <span class="arrow">→</span>
            <div class="stage active">CodeDeploy</div>
            <span class="arrow">→</span>
            <div class="stage active">Live ✓</div>
        </div>

        <p>
            The infrastructure — VPC, EC2, IAM roles, CodeBuild project,
            and CodeDeploy deployment group — is defined entirely in CloudFormation
            and can be torn down and recreated in minutes.
        </p>

        <div class="footer">
            Built by <strong>Kehinde Abiuwa</strong> &nbsp;|&nbsp;
            AWS Solutions Architect Professional &nbsp;|&nbsp; AZ-305
        </div>
    </div>
</body>
</html>
