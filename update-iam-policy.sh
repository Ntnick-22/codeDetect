#!/bin/bash

# Update GitHub Actions IAM policy to include RDS permissions
# This adds the necessary permissions for Terraform to create RDS resources

echo "Updating GitHub Actions IAM policy with RDS permissions..."

# Get the current policy ARN for the github-actions-cicd user
POLICY_ARN=$(aws iam list-attached-user-policies \
  --user-name github-actions-cicd \
  --query 'AttachedPolicies[0].PolicyArn' \
  --output text 2>/dev/null)

if [ -z "$POLICY_ARN" ] || [ "$POLICY_ARN" = "None" ]; then
  echo "Error: Could not find attached policy for github-actions-cicd user"
  echo "Looking for inline policies..."

  INLINE_POLICY=$(aws iam list-user-policies \
    --user-name github-actions-cicd \
    --query 'PolicyNames[0]' \
    --output text 2>/dev/null)

  if [ -n "$INLINE_POLICY" ] && [ "$INLINE_POLICY" != "None" ]; then
    echo "Found inline policy: $INLINE_POLICY"
    echo "Updating inline policy..."

    aws iam put-user-policy \
      --user-name github-actions-cicd \
      --policy-name "$INLINE_POLICY" \
      --policy-document file://github-actions-iam-policy.json

    if [ $? -eq 0 ]; then
      echo "✅ Inline policy updated successfully!"
    else
      echo "❌ Failed to update inline policy"
      exit 1
    fi
  else
    echo "❌ No policies found for github-actions-cicd user"
    exit 1
  fi
else
  echo "Found managed policy: $POLICY_ARN"

  # Create a new version of the policy
  echo "Creating new policy version..."

  aws iam create-policy-version \
    --policy-arn "$POLICY_ARN" \
    --policy-document file://github-actions-iam-policy.json \
    --set-as-default

  if [ $? -eq 0 ]; then
    echo "✅ Managed policy updated successfully!"
  else
    echo "❌ Failed to update managed policy"
    exit 1
  fi
fi

echo ""
echo "Policy updated! RDS permissions added:"
echo "- rds:* (full RDS access)"
echo ""
echo "GitHub Actions can now create RDS resources!"
