#!/usr/bin/env bash
# ============================================================
# Setup Terraform S3 Backend Resources
# ============================================================
# Jalankan script ini SATU KALI sebelum `terraform init`
# untuk membuat S3 bucket dan DynamoDB table yang dibutuhkan.
#
# Usage:
#   chmod +x scripts/setup-backend.sh
#   ./scripts/setup-backend.sh
# ============================================================

set -euo pipefail

BUCKET_NAME="iac-tfstate-407772390483"
DYNAMO_TABLE="terraform-locks"
REGION="ap-southeast-3"

echo "🪣 Creating S3 bucket: ${BUCKET_NAME} ..."
if aws s3api head-bucket --bucket "${BUCKET_NAME}" 2>/dev/null; then
  echo "   ✅ Bucket already exists, skipping."
else
  aws s3api create-bucket \
    --bucket "${BUCKET_NAME}" \
    --region "${REGION}" \
    --create-bucket-configuration LocationConstraint="${REGION}"

  # Enable versioning (protect state from accidental overwrite)
  aws s3api put-bucket-versioning \
    --bucket "${BUCKET_NAME}" \
    --versioning-configuration Status=Enabled

  # Enable server-side encryption
  aws s3api put-bucket-encryption \
    --bucket "${BUCKET_NAME}" \
    --server-side-encryption-configuration '{
      "Rules": [{ "ApplyServerSideEncryptionByDefault": { "SSEAlgorithm": "AES256" } }]
    }'

  # Block all public access
  aws s3api put-public-access-block \
    --bucket "${BUCKET_NAME}" \
    --public-access-block-configuration \
      BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

  echo "   ✅ Bucket created with versioning + encryption + public access blocked."
fi

echo ""
echo "🔒 Creating DynamoDB table: ${DYNAMO_TABLE} ..."
if aws dynamodb describe-table --table-name "${DYNAMO_TABLE}" --region "${REGION}" >/dev/null 2>&1; then
  echo "   ✅ Table already exists, skipping."
else
  aws dynamodb create-table \
    --table-name "${DYNAMO_TABLE}" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "${REGION}"

  echo "   ⏳ Waiting for table to become active..."
  aws dynamodb wait table-exists \
    --table-name "${DYNAMO_TABLE}" \
    --region "${REGION}"

  echo "   ✅ DynamoDB table created."
fi

echo ""
echo "🎉 Backend resources ready! Now run:"
echo "   cd environments/dev"
echo "   terraform init -migrate-state"
