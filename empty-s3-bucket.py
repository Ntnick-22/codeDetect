#!/usr/bin/env python3
"""
Empty S3 Bucket - Delete All Versions
This script deletes all objects and versions from an S3 bucket
"""

import boto3

BUCKET_NAME = 'codedetect-nick-uploads-12345'

def empty_bucket(bucket_name):
    """Delete all objects and versions from S3 bucket"""
    s3 = boto3.resource('s3')
    bucket = s3.Bucket(bucket_name)

    print(f"Emptying bucket: {bucket_name}")

    # Delete all versions
    try:
        bucket.object_versions.all().delete()
        print("All object versions deleted")
    except Exception as e:
        print(f"Error deleting versions: {e}")

    # Delete all objects (just in case)
    try:
        bucket.objects.all().delete()
        print("All objects deleted")
    except Exception as e:
        print(f"Error deleting objects: {e}")

    print(f"Bucket {bucket_name} is now empty!")

if __name__ == "__main__":
    empty_bucket(BUCKET_NAME)
