import json
import boto3
import os
import datetime

def lambda_handler(event, context):
    sns_topic_arn = os.environ.get('SNS_TOPIC_ARN')
    sns_client = boto3.client('sns')

    try:
        body_str = event.get('body', '{}')
        body = json.loads(body_str) if body_str else {}
        
        message = body.get('message', 'No message content')
        timestamp = body.get('timestamp', str(datetime.datetime.now()))

        email_message = f"Keyword detected in chat message!\n\nMessage: {message}\nTimestamp: {timestamp}"

        response = sns_client.publish(
            TopicArn=sns_topic_arn,
            Message=email_message,
            Subject="Chat Alert: Important Message Detected"
        )
        
        return {
            'statusCode': 200,
            'body': json.dumps({'success': True, 'messageId': response.get('MessageId')}),
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'POST, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type'
            }
        }
    except Exception as e:
        print(f"Error: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)}),
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'POST, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type'
            }
        }
