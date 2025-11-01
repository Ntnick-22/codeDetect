#!/usr/bin/env python3
"""Test S3 upload functionality"""
import boto3
from datetime import datetime
import os

print("=" * 60)
print("Testing S3 Upload")
print("=" * 60)

# Test S3 upload
bucket = 'codedetect-nick-uploads-12345'
region = 'eu-west-1'

print(f"\nBucket: {bucket}")
print(f"Region: {region}")

try:
    # Create S3 client
    s3 = boto3.client('s3', region_name=region)
    print("[OK] S3 client created successfully")

    # Create a test file
    test_file = 'test_upload_temp.txt'
    with open(test_file, 'w') as f:
        f.write(f'Test upload at {datetime.now().isoformat()}\n')
    print(f"[OK] Created test file: {test_file}")

    # Try to upload
    s3_key = 'uploads/test_from_script.txt'
    print(f"\n[UPLOAD] Uploading to s3://{bucket}/{s3_key}...")
    s3.upload_file(test_file, bucket, s3_key)
    print(f"[SUCCESS] File uploaded to S3!")

    # Verify it's there
    print(f"\n[CHECK] Checking uploads/ folder...")
    response = s3.list_objects_v2(Bucket=bucket, Prefix='uploads/')
    if 'Contents' in response:
        print(f"[OK] Found {len(response['Contents'])} file(s) in uploads/ folder:")
        for obj in response['Contents']:
            print(f"  - {obj['Key']} ({obj['Size']} bytes)")
    else:
        print("[WARNING] No files found in uploads/ folder")

    # Clean up test file
    os.remove(test_file)
    print(f"\n[OK] Test file cleaned up")

except FileNotFoundError as e:
    print(f"[ERROR] File not found: {e}")
except boto3.exceptions.NoCredentialsError:
    print("[ERROR] AWS credentials not available. Run 'aws configure'")
except Exception as e:
    print(f"[ERROR] FAILED: {type(e).__name__}")
    print(f"        Error: {e}")
    import traceback
    traceback.print_exc()

print("\n" + "=" * 60)
print("Test Complete")
print("=" * 60)
