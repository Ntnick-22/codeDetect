# ============================================================================
# GITHUB ACTIONS CI/CD IAM USER AND PERMISSIONS
# ============================================================================
# This manages the IAM user that GitHub Actions uses to deploy infrastructure
# ============================================================================

# ----------------------------------------------------------------------------
# IAM USER - GitHub Actions
# ----------------------------------------------------------------------------

resource "aws_iam_user" "github_actions" {
  name = "github-actions-cicd"

  tags = merge(
    local.common_tags,
    {
      Name    = "github-actions-cicd"
      Purpose = "CI/CD automation"
    }
  )
}

# ----------------------------------------------------------------------------
# IAM POLICY - GitHub Actions Permissions
# ----------------------------------------------------------------------------

resource "aws_iam_policy" "github_actions" {
  name        = "GitHubActionsCICD"
  description = "Permissions for GitHub Actions to deploy CodeDetect infrastructure"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # EC2 Permissions
      {
        Sid    = "EC2Permissions"
        Effect = "Allow"
        Action = [
          "ec2:*"
        ]
        Resource = "*"
      },
      # Auto Scaling Permissions
      {
        Sid    = "AutoScalingPermissions"
        Effect = "Allow"
        Action = [
          "autoscaling:*"
        ]
        Resource = "*"
      },
      # S3 Permissions
      {
        Sid    = "S3Permissions"
        Effect = "Allow"
        Action = [
          "s3:*"
        ]
        Resource = "*"
      },
      # RDS Permissions
      {
        Sid    = "RDSPermissions"
        Effect = "Allow"
        Action = [
          "rds:*"
        ]
        Resource = "*"
      },
      # IAM Permissions (for creating roles)
      {
        Sid    = "IAMPermissions"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:PassRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:ListAttachedRolePolicies",
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:GetInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:ListPolicyVersions",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:TagRole",
          "iam:UntagRole"
        ]
        Resource = "*"
      },
      # CloudWatch Permissions
      {
        Sid    = "CloudWatchPermissions"
        Effect = "Allow"
        Action = [
          "cloudwatch:*",
          "logs:*"
        ]
        Resource = "*"
      },
      # SNS Permissions
      {
        Sid    = "SNSPermissions"
        Effect = "Allow"
        Action = [
          "sns:*"
        ]
        Resource = "*"
      },
      # Systems Manager (Parameter Store) Permissions
      {
        Sid    = "SSMPermissions"
        Effect = "Allow"
        Action = [
          "ssm:PutParameter",
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:DeleteParameter",
          "ssm:DescribeParameters",
          "ssm:AddTagsToResource",
          "ssm:RemoveTagsFromResource"
        ]
        Resource = "*"
      },
      # Lambda Permissions
      {
        Sid    = "LambdaPermissions"
        Effect = "Allow"
        Action = [
          "lambda:*"
        ]
        Resource = "*"
      },
      # SES Permissions
      {
        Sid    = "SESPermissions"
        Effect = "Allow"
        Action = [
          "ses:VerifyEmailIdentity",
          "ses:DeleteIdentity",
          "ses:GetIdentityVerificationAttributes",
          "ses:SendEmail",
          "ses:SendRawEmail"
        ]
        Resource = "*"
      },
      # STS (for getting account ID)
      {
        Sid    = "STSPermissions"
        Effect = "Allow"
        Action = [
          "sts:GetCallerIdentity"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "GitHubActionsCICD"
    }
  )
}

# ----------------------------------------------------------------------------
# ATTACH POLICY TO USER
# ----------------------------------------------------------------------------

resource "aws_iam_user_policy_attachment" "github_actions" {
  user       = aws_iam_user.github_actions.name
  policy_arn = aws_iam_policy.github_actions.arn
}

# ============================================================================
# NOTES
# ============================================================================
#
# This Terraform file will IMPORT the existing IAM user and policy.
# To import existing resources:
#
# terraform import aws_iam_user.github_actions github-actions-cicd
# terraform import aws_iam_policy.github_actions arn:aws:iam::772297676546:policy/GitHubActionsCICD
# terraform import aws_iam_user_policy_attachment.github_actions github-actions-cicd/arn:aws:iam::772297676546:policy/GitHubActionsCICD
#
# After importing, Terraform will manage these resources and you can update
# permissions by editing this file and running terraform apply.
#
# ============================================================================
