#!/usr/bin/env python3
"""
Simple deployment webhook for CodeDetect
Run this on EC2 to enable automated deployments without SSH keys!
"""
from flask import Flask, request, jsonify
import subprocess
import hmac
import hashlib
import os

app = Flask(__name__)

# Set this secret in environment variable
WEBHOOK_SECRET = os.environ.get('WEBHOOK_SECRET', 'change-me-to-something-secure')

@app.route('/deploy', methods=['POST'])
def deploy():
    """
    Endpoint that GitHub Actions calls to trigger deployment
    """
    # Verify secret token
    token = request.headers.get('X-Deploy-Token', '')

    # Simple security check
    expected_hash = hashlib.sha256(WEBHOOK_SECRET.encode()).hexdigest()
    provided_hash = hashlib.sha256(token.encode()).hexdigest()

    if not hmac.compare_digest(expected_hash, provided_hash):
        return jsonify({'error': 'Unauthorized'}), 401

    try:
        # Run deployment commands
        commands = [
            'cd /home/ec2-user/app',
            'git fetch origin',
            'git reset --hard origin/main',
            'docker-compose down || true',
            'docker-compose build --no-cache',
            'docker-compose up -d'
        ]

        result = subprocess.run(
            ' && '.join(commands),
            shell=True,
            capture_output=True,
            text=True,
            timeout=300
        )

        return jsonify({
            'status': 'success',
            'output': result.stdout,
            'errors': result.stderr
        })

    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'ok'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000)
