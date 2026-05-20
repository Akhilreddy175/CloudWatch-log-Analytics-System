import json
import boto3
import time
import os

def lambda_handler(event, context):
    # Clients initialization for logs & sns
    logs_client = boto3.client('logs')
    sns_client = boto3.client('sns')
    
    # Confi from env 
    log_group_name = os.environ.get('LOG_GROUP_NAME')
    sns_topic_arn = os.environ.get('SNS_TOPIC_ARN')
    error_threshold = int(os.environ.get('ERROR_THRESHOLD',1))
    
    print(f"Starting log query for group: {log_group_name}")
    
    #time-range for 1-Hour
    end_time = int(time.time())
    start_time = end_time - 3600
    
    # Query to count ERRORs
    query = "fields @timestamp, @message | filter @message like /ERROR/ | stats count()"
    
    response = logs_client.start_query(
        logGroupName = log_group_name,
        startTime = start_time,
        endTime = end_time,
        queryString = query
    )
    query_id = response['queryId']
    
    status = 'Running'
    attempts = 0
    max_attempts = 15
    
    while status in ['Running', 'Scheduled'] and attempts < max_attempts:
        time.sleep(1)
        result = logs_client.get_query_results(queryId=query_id)
        status = result['status']
        attempts += 1
        
    if status != 'Complete':
        raise Exception(f"Query failed or timed out. Status: {status}")
    
    #Get ERROR count 
    error_count = 0
    if result['results'] and len(result['results']) > 0:
        error_count = int(result['results'][0][0]['value'])
        
    print(f"Error found in last 1 hour: {error_count} (Threshold: {error_threshold})")
        
    #Send SNS alert
    alert_sent = False
    if error_count >= error_threshold:
        alert_message = f"""
         Log Analytics Alert!
         
        Log Group: {log_group_name}
        Time Period: Last 1 Hour
        Errors Detected: {error_count}
        Alert Threshold: {error_threshold}
        
        Please inspect the logs in CloudWatch Logs Insights.
        """
        
        sns_client.publish(
            TopicArn = sns_topic_arn,
            Subject = f"ALERT: {error_count} Errors Detected",
            Message = alert_message
        )
        print("Alert notification sent via SNS!")
        alert_sent = True
        
    return {
        'statusCode': 200,
        'body': json.dumps({
            'error_count': error_count,
            'alert_sent': alert_sent
        })
    }
