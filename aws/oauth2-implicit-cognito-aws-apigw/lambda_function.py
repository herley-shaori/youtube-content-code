import logging

def lambda_handler(event, context):
    logging.info(event)
    return {
        'statusCode': 200,
        'body': 'Hello, World!'
    }