# 1. Configuration Variables
$Region = "us-east-1"
$RoleName = "log-analyzer-role"
$LogGroupName = "/my-app/web-server"
$LogStreamName = "server-001"
$SnsTopicName = "log-alerts"
$EmailAddress = "bunnyreddyjr@gmail.com" 
$FunctionName = "log-analyzer"
$ScheduleRuleName = "log-analyzer-schedule"

Write-Host "Starting Deployment of Log Analytics..." -ForegroundColor Green

# 2. Get AWS Account ID
$AccountId = (aws sts get-caller-identity --query "Account" --output text)
Write-Host "Using AWS Account: $AccountId" -ForegroundColor Cyan

# 3. Create IAM Role & Attach Policies
Write-Host "Creating IAM Role..." -ForegroundColor Cyan
aws iam create-role --role-name $RoleName --assume-role-policy-document file://trust-policy.json

Write-Host "Attaching execution policies..." -ForegroundColor Cyan
aws iam attach-role-policy --role-name $RoleName --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
# (Wait a few seconds for IAM changes to propagate in AWS)
Start-Sleep -Seconds 5

# 4. Create Log Group & Stream
Write-Host "Creating CloudWatch Log Group..." -ForegroundColor Cyan
aws logs create-log-group --log-group-name $LogGroupName
aws logs create-log-stream --log-group-name $LogGroupName --log-stream-name $LogStreamName

# 5. Create SNS Topic & Subscribe
Write-Host "Creating SNS Topic..." -ForegroundColor Cyan
$TopicArn = (aws sns create-topic --name $SnsTopicName --query "TopicArn" --output text)
aws sns subscribe --topic-arn $TopicArn --protocol "email" --notification-endpoint $EmailAddress

Write-Host "SNS Topic and Subscription setup done." -ForegroundColor Green

# 6. Package and Create Lambda Function
Write-Host "Zipping Lambda function code..." -ForegroundColor Cyan
Compress-Archive -Path lambda_function.py -DestinationPath lambda_function.zip -Force

$RoleArn = "arn:aws:iam::${AccountId}:role/$RoleName"

Write-Host "Deploying Lambda function..." -ForegroundColor Cyan
aws lambda create-function `
  --function-name $FunctionName `
  --runtime "python3.9" `
  --role $RoleArn `
  --handler "lambda_function.lambda_handler" `
  --zip-file "fileb://lambda_function.zip" `
  --timeout 30 `
  --environment "Variables={LOG_GROUP_NAME=$LogGroupName,SNS_TOPIC_ARN=$TopicArn,ERROR_THRESHOLD=1}"

# 7. Create EventBridge Schedule
Write-Host "Creating EventBridge scheduling rule..." -ForegroundColor Cyan
$RuleArn = (aws events put-rule --name $ScheduleRuleName --schedule-expression "rate(5 minutes)" --state "ENABLED" --query "RuleArn" --output text)

Write-Host "Adding permission for EventBridge to invoke Lambda..." -ForegroundColor Cyan
aws lambda add-permission `
  --function-name $FunctionName `
  --statement-id "AllowEventBridgeToInvoke" `
  --action "lambda:InvokeFunction" `
  --principal "events.amazonaws.com" `
  --source-arn $RuleArn

Write-Host "Setting Lambda as target for EventBridge rule..." -ForegroundColor Cyan
$LambdaArn = "arn:aws:lambda:${Region}:${AccountId}:function:$FunctionName"
aws events put-targets --rule $ScheduleRuleName --targets "Id=1,Arn=$LambdaArn"

Write-Host "DEPLOYMENT FULLY COMPLETE! Check email inbox to confirm subscription." -ForegroundColor Green