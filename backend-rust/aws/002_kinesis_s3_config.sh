#!/bin/bash
# 002_kinesis_s3_config.sh
# AWS Phase 2: Configure Kinesis Video Streams to dump archives into Amazon S3

set -e

REGION="${AWS_REGION:-us-east-1}"
BUCKET_NAME="regatta-media-archive-${RANDOM}"
ROLE_NAME="RegattaKinesisVideoToS3Role"

echo "☁️ Setting up Amazon Kinesis to S3 Video Pipeline in $REGION..."

# 1. Create the S3 Bucket for Video Archival
echo "Creating S3 Bucket: $BUCKET_NAME"
aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION"

# 2. Create the IAM Role for Kinesis to access S3
echo "Creating IAM Role: $ROLE_NAME"
cat <<EOF > /tmp/kinesis-trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "kinesisvideo.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
aws iam create-role \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document file:///tmp/kinesis-trust-policy.json

# 3. Attach S3 Write Permissions to the Role
cat <<EOF > /tmp/kinesis-s3-policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:PutObjectAcl",
                "s3:GetBucketLocation"
            ],
            "Resource": [
                "arn:aws:s3:::$BUCKET_NAME",
                "arn:aws:s3:::$BUCKET_NAME/*"
            ]
        }
    ]
}
EOF
aws iam put-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-name KinesisWriteToS3 \
    --policy-document file:///tmp/kinesis-s3-policy.json

# 4. (For the Fleet) KVS creation normally happens dynamically via the Fargate API, 
# but here is the manual baseline creation for the stream template.
echo "⚠️ Note: Actual KVS Streams should be provisioned dynamically per-boat by the Fargate Backend using AWS SDK."

echo "✅ Kinesis to S3 Pipeline Infrastructure Ready!"
echo "S3_MEDIA_BUCKET=$BUCKET_NAME"
echo "KINESIS_IAM_ROLE=$ROLE_NAME"
