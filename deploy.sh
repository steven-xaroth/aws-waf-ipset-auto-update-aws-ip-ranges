#! /bin/bash

# CONFIG HERE
REGION='us-east-1'
CFN_STACK_NAME='AWS-WAF-AutoUpdate-AWS-IPs'
BUCKET_NAME='aws-waf-autoupdate-aws-ips'
OBJECT_NAME='update_aws_waf_ipset.zip'

# Execution
set -ex

if [ "$REGION" = "us-east-1" ]
then
    aws s3api create-bucket \
        --bucket $BUCKET_NAME \
        --region $REGION
else
    aws s3api create-bucket \
        --bucket $BUCKET_NAME \
        --region $REGION \
        --create-bucket-configuration LocationConstraint=$REGION
fi

pushd ./lambda

zip $OBJECT_NAME *.py
aws s3 cp $OBJECT_NAME s3://$BUCKET_NAME
rm $OBJECT_NAME

popd

aws cloudformation create-stack \
    --stack-name $CFN_STACK_NAME \
    --template-body file://cloudformation/template.yml \
    --region $REGION --parameters \
    --parameters ParameterKey=LambdaCodeS3Bucket,ParameterValue=$BUCKET_NAME \
                 ParameterKey=LambdaCodeS3Object,ParameterValue=$OBJECT_NAME \
    --capabilities CAPABILITY_IAM

aws cloudformation wait stack-create-complete \
    --stack-name $CFN_STACK_NAME \
    --region $REGION

aws lambda invoke \
  --function-name $CFN_STACK_NAME-UpdateWAFIPSets \
  --region $REGION \
  --payload file://lambda/test_event.json lambda_return.json

cat lambda_return.json
rm lambda_return.json
