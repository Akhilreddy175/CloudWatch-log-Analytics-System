# 1. Configuration Variables
$RoleName = "log-analyzer-role"
$LogGroupName = "/my-app/web-server"
$SnsTopicName = "log-alerts"
$FunctionName = "log-analyzer"
$ScheduleRuleName = "log-analyzer-schedule"

Write-Host "Starting cleanup of Log Analytics resources..." -ForegroundColor Yellow

# Get Account ID
$AccountId = (aws sts get-caller-identity --query "Account" --output text)

# 2. Delete EventBridge Rule Target & Rule
Write-Host "Removing EventBridge rule targets..." -ForegroundColor Cyan
aws events remove-targets --rule $ScheduleRuleName --ids "1"

Write-Host "Deleting EventBridge rule..." -ForegroundColor Cyan
aws events delete-rule --name $ScheduleRuleName

# 3. Delete Lambda Function
Write-Host "Deleting Lambda function..." -ForegroundColor Cyan
aws lambda delete-function --function-name $FunctionName

# 4. Delete SNS Topic
Write-Host "Deleting SNS Topic..." -ForegroundColor Cyan
$TopicArn = "arn:aws:sns:us-east-1:${AccountId}:$SnsTopicName"
aws sns delete-topic --topic-arn $TopicArn

# 5. Delete CloudWatch Log Group
Write-Host "Deleting Log Group..." -ForegroundColor Cyan
aws logs delete-log-group --log-group-name $LogGroupName

# 6. Detach and Delete IAM Roles/Policies
Write-Host "Detaching policies from IAM Role..." -ForegroundColor Cyan
aws iam detach-role-policy --role-name $RoleName --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
aws iam detach-role-policy --role-name $RoleName --policy-arn "arn:aws:iam::${AccountId}:policy/log-analyzer-logs-policy"
aws iam detach-role-policy --role-name $RoleName --policy-arn "arn:aws:iam::${AccountId}:policy/log-analyzer-sns-policy"

Write-Host "Deleting IAM Role..." -ForegroundColor Cyan
aws iam delete-role --role-name $RoleName

Write-Host "Deleting custom IAM policies..." -ForegroundColor Cyan
aws iam delete-policy --policy-arn "arn:aws:iam::${AccountId}:policy/log-analyzer-logs-policy"
aws iam delete-policy --policy-arn "arn:aws:iam::${AccountId}:policy/log-analyzer-sns-policy"

Write-Host "CLEANUP COMPLETE! All resources destroyed." -ForegroundColor Green
