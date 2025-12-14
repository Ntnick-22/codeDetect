from flask_sqlalchemy import SQLAlchemy
from flask import Flask, request, jsonify, render_template
from flask_cors import CORS
from werkzeug.utils import secure_filename
import os
import subprocess
import json
from datetime import datetime
import boto3
from botocore.exceptions import NoCredentialsError
import logging
import traceback
import secrets
import hashlib
import re

# Flask setup
app = Flask(
    __name__,
    static_folder='../frontend',
    static_url_path='',
    template_folder='../frontend'
)
CORS(app)

# ============================================================
# Logging Configuration
# ============================================================
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# ============================================================
# Security Configuration
# ============================================================
# SECRET_KEY is critical for:
# - Session encryption (cookies)
# - CSRF protection
# - Flash messages
# - Any cryptographic operations
#
# In production: Fetched from AWS Parameter Store via entrypoint.sh
# In development: Set in environment or use a default (insecure)
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'dev-secret-key-CHANGE-IN-PRODUCTION')

# Warn if using default secret key
if app.config['SECRET_KEY'] == 'dev-secret-key-CHANGE-IN-PRODUCTION':
    logger.warning("WARNING: Using default SECRET_KEY - Not secure for production!")
    logger.warning("Set SECRET_KEY environment variable or configure AWS Parameter Store")

# ============================================================
# Database Configuration (works both locally and on AWS)
# ============================================================
app.config['SQLALCHEMY_DATABASE_URI'] = os.environ.get(
    'DATABASE_URL', 'sqlite:///codedetect.db')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db = SQLAlchemy(app)


# ============================================================
# Database Model - Privacy-First (Anonymous Analytics)
# ============================================================
# We store only aggregate data, NO filenames or code content
# This protects user privacy while allowing platform analytics
class Analysis(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    # Anonymous field - just for identification, not real filename
    file_hash = db.Column(db.String(64), nullable=True)  # Changed from filename
    timestamp = db.Column(db.DateTime, default=datetime.utcnow, index=True)
    score = db.Column(db.Integer, nullable=False)
    total_issues = db.Column(db.Integer, default=0)
    security_issues = db.Column(db.Integer, default=0)
    complexity_issues = db.Column(db.Integer, default=0)
    # DO NOT store full analysis_data (contains code)
    # analysis_data = db.Column(db.Text)  # REMOVED for privacy

    def to_dict(self):
        return {
            'id': self.id,
            'timestamp': self.timestamp.isoformat(),
            'score': self.score,
            'total_issues': self.total_issues,
            'security_issues': self.security_issues,
            'complexity_issues': self.complexity_issues
        }


with app.app_context():
    db.create_all()

# ============================================================
# Configuration
# ============================================================
UPLOAD_FOLDER = 'uploads'
ALLOWED_EXTENSIONS = {'py'}
MAX_FILE_SIZE = 5 * 1024 * 1024  # 5MB

app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
app.config['MAX_CONTENT_LENGTH'] = MAX_FILE_SIZE

os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# ============================================================
# Utility Functions
# ============================================================


def allowed_file(filename):
    """
    Check if uploaded file has an allowed extension.

    Args:
        filename (str): Name of the uploaded file

    Returns:
        bool: True if file has .py extension, False otherwise
    """
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS


def upload_to_s3(filepath, bucket_name, s3_key):
    """
    Upload file to AWS S3 bucket.

    Args:
        filepath (str): Local path to file to upload
        bucket_name (str): Name of S3 bucket
        s3_key (str): S3 object key (path within bucket)

    Returns:
        bool: True if upload successful, False otherwise
    """
    try:
        s3 = boto3.client('s3', region_name='eu-west-1')
        logger.info(f"Uploading {filepath} to s3://{bucket_name}/{s3_key}")
        s3.upload_file(filepath, bucket_name, s3_key)
        logger.info(f"Successfully uploaded {s3_key} to {bucket_name}")
        return True
    except FileNotFoundError:
        logger.error(f"File not found for upload: {filepath}")
        return False
    except NoCredentialsError:
        logger.error("AWS credentials not available. Run 'aws configure'")
        return False
    except Exception as e:
        logger.error(f"S3 Upload failed - Error type: {type(e).__name__}")
        logger.error(f"S3 Upload error details: {str(e)}")
        traceback.print_exc()
        return False


def run_pylint(filepath):
    """
    Run Pylint code quality analysis on Python file.

    Args:
        filepath (str): Path to Python file to analyze

    Returns:
        list: List of Pylint issues found, empty list if error or no issues
    """
    try:
        result = subprocess.run(
            ['pylint', filepath, '--output-format=json'],
            capture_output=True, text=True, timeout=30
        )
        if result.stdout:
            return json.loads(result.stdout)
        return []
    except Exception as e:
        logger.error(f"Pylint error: {e}")
        return []


def run_bandit(filepath):
    """
    Run Bandit security analysis on Python file.

    Args:
        filepath (str): Path to Python file to analyze

    Returns:
        list: List of security issues found, empty list if error or no issues
    """
    try:
        logger.info(f"Running Bandit on: {filepath}")

        # Bandit returns exit code 1 when issues found - this is NORMAL!
        # Don't treat it as an error
        result = subprocess.run(
            ['bandit', filepath, '-f', 'json'],
            capture_output=True, text=True, timeout=30,
            check=False  # Don't raise exception on non-zero exit code
        )

        logger.info(f"Bandit exit code: {result.returncode}")
        logger.info(f"Bandit stdout length: {len(result.stdout) if result.stdout else 0}")
        logger.info(f"Bandit stderr length: {len(result.stderr) if result.stderr else 0}")

        # Parse JSON output
        if result.stdout:
            try:
                data = json.loads(result.stdout)
                issues = data.get('results', [])
                logger.info(f"Bandit found {len(issues)} security issues")

                # Log first issue for debugging
                if issues:
                    logger.info(f"First security issue: {issues[0].get('issue_text', 'N/A')}")

                return issues
            except json.JSONDecodeError as e:
                logger.error(f"Bandit JSON parse error: {e}")
                logger.error(f"Raw stdout: {result.stdout[:1000]}")
                return []

        # Check stderr for errors
        if result.stderr:
            logger.warning(f"Bandit stderr: {result.stderr[:500]}")

        logger.warning("Bandit returned no stdout - returning empty list")
        return []
    except Exception as e:
        logger.error(f"Bandit exception: {e}")
        traceback.print_exc()
        return []


def run_radon(filepath):
    """
    Run Radon cyclomatic complexity analysis on Python file.

    Args:
        filepath (str): Path to Python file to analyze

    Returns:
        dict: Complexity data for functions, empty dict if error
    """
    try:
        logger.info(f"Running Radon on: {filepath}")

        result = subprocess.run(
            ['radon', 'cc', filepath, '-j'],
            capture_output=True, text=True, timeout=30,
            check=False
        )

        logger.info(f"Radon exit code: {result.returncode}")
        logger.info(f"Radon stdout length: {len(result.stdout) if result.stdout else 0}")

        if result.stdout:
            complexity_data = json.loads(result.stdout)
            high_complexity = sum(
                1 for file_data in complexity_data.values()
                for func in file_data if func.get('complexity', 0) > 10
            )
            logger.info(f"Radon found {high_complexity} high complexity functions")
            return complexity_data

        logger.warning("Radon returned no stdout")
        return {}
    except Exception as e:
        logger.error(f"Radon error: {e}")
        traceback.print_exc()
        return {}


def calculate_score(pylint_issues, bandit_issues, complexity_data):
    """
    Calculate overall code quality score based on analysis results.

    Args:
        pylint_issues (list): List of Pylint issues
        bandit_issues (list): List of Bandit security issues
        complexity_data (dict): Radon complexity analysis results

    Returns:
        int: Quality score from 0-100 (100 = perfect, 0 = many issues)
    """
    score = 100
    error_count = 0
    warning_count = 0

    for issue in pylint_issues:
        issue_type = issue.get('type', 'warning')
        if issue_type in ['error', 'fatal']:
            error_count += 1
        elif issue_type == 'warning':
            warning_count += 1

    score -= error_count * 3
    score -= warning_count * 1

    for issue in bandit_issues:
        severity = issue.get('issue_severity', 'LOW')
        confidence = issue.get('issue_confidence', 'LOW')
        if severity == 'HIGH':
            score -= 8 if confidence == 'HIGH' else 5
        elif severity == 'MEDIUM':
            score -= 4 if confidence == 'HIGH' else 2
        else:
            score -= 1

    high_complexity_count = 0
    for file_data in complexity_data.values():
        for func in file_data:
            complexity = func.get('complexity', 0)
            if complexity > 15:
                score -= 5
                high_complexity_count += 1
            elif complexity > 10:
                score -= 2
                high_complexity_count += 1

    score = max(0, min(100, score))
    if error_count == 0 and warning_count == 0 and len(bandit_issues) == 0 and high_complexity_count == 0:
        score = 100

    return score

# ============================================================
# Routes
# ============================================================


@app.route('/')
def index():
    return render_template('index.html')


@app.route('/api/analyze', methods=['POST'])
def analyze_code():
    """
    Main endpoint for Python file analysis.

    Accepts file upload, runs Pylint, Bandit, and Radon analyses,
    uploads to S3, and stores anonymous statistics.

    Returns:
        tuple: JSON response with analysis results and HTTP status code
    """
    if 'file' not in request.files:
        return jsonify({'error': 'No file provided'}), 400

    file = request.files['file']
    if file.filename == '':
        return jsonify({'error': 'No file selected'}), 400

    if not allowed_file(file.filename):
        return jsonify({'error': 'Only .py files allowed'}), 400

    try:
        filename = secure_filename(file.filename)
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        unique_filename = f"{timestamp}_{filename}"
        filepath = os.path.join(app.config['UPLOAD_FOLDER'], unique_filename)
        file.save(filepath)

        # Read original code for auto-fix feature
        with open(filepath, 'r', encoding='utf-8') as f:
            original_code = f.read()

        # === Upload to S3 before analyzing ===
        bucket_name = os.environ.get(
            'S3_BUCKET_NAME', 'codedetect-nick-uploads-12345')
        s3_key = f"uploads/{unique_filename}"
        logger.info(f"S3 Bucket: {bucket_name}")
        logger.info(f"S3 Key: {s3_key}")
        upload_success = upload_to_s3(filepath, bucket_name, s3_key)

        if not upload_success:
            logger.warning("S3 upload failed - keeping local file for debugging")
            # Clean up anyway to save space, but log the issue
            # User can check console output for errors

        # Run analyses
        logger.info(f"=== STARTING ANALYSIS FOR: {filepath} ===")

        pylint_results = run_pylint(filepath)
        logger.info(f"Pylint returned {len(pylint_results)} issues")

        bandit_results = run_bandit(filepath)
        logger.critical(f"BANDIT RETURNED {len(bandit_results)} SECURITY ISSUES!")
        print(f"[DEBUG] BANDIT RETURNED {len(bandit_results)} SECURITY ISSUES!", flush=True)
        if bandit_results:
            logger.critical(f"First Bandit issue: {bandit_results[0]}")
            print(f"[DEBUG] First Bandit issue: {bandit_results[0]}", flush=True)
        else:
            print(f"[DEBUG] BANDIT ARRAY IS EMPTY - NO ISSUES DETECTED!", flush=True)

        complexity_results = run_radon(filepath)
        logger.info(f"Radon returned {len(complexity_results)} files")

        score = calculate_score(
            pylint_results, bandit_results, complexity_results)
        logger.info(f"Final score: {score}")

        response = {
            'filename': filename,
            'timestamp': timestamp,
            'score': score,
            'original_code': original_code,  # Include original code for auto-fix
            'analysis': {
                'quality_issues': pylint_results[:10],
                'security_issues': bandit_results,
                'complexity': complexity_results
            },
            'summary': {
                'total_issues': len(pylint_results),
                'security_issues': len(bandit_results),
                'high_complexity_functions': sum(
                    1 for file_data in complexity_results.values()
                    for func in file_data if func.get('complexity', 0) > 10
                )
            }
        }

        # Generate temporary S3 download link
        try:
            s3 = boto3.client('s3')
            presigned_url = s3.generate_presigned_url(
                'get_object',
                Params={'Bucket': bucket_name, 'Key': s3_key},
                ExpiresIn=3600  # 1 hour
            )
            response['s3_url'] = presigned_url
        except Exception as e:
            logger.error(f"Failed to create presigned URL: {e}")

        # Save to DB (ANONYMOUS - no filename or code content)
        # Only store aggregate stats for platform analytics
        try:
            # Create cryptographically secure random hash for anonymity
            file_hash = secrets.token_hex(16)

            new_analysis = Analysis(
                file_hash=file_hash,  # Anonymous identifier
                score=score,
                total_issues=len(pylint_results),
                security_issues=len(bandit_results),
                complexity_issues=response['summary']['high_complexity_functions']
                # NO filename, NO analysis_data (privacy-first!)
            )
            db.session.add(new_analysis)
            db.session.commit()
            logger.info(f"Anonymous analytics saved (hash: {file_hash})")
        except Exception as e:
            logger.warning(f"Database save error (non-critical): {e}")

        os.remove(filepath)  # cleanup local file
        return jsonify(response), 200

    except Exception as e:
        logger.error(f"Analysis error: {e}")
        return jsonify({'error': 'Analysis failed', 'details': str(e)}), 500


@app.route('/api/health', methods=['GET'])
def health_check():
    """
    Health check endpoint for load balancer monitoring.

    Returns:
        tuple: JSON response with service status and HTTP 200
    """
    return jsonify({
        'status': 'healthy',
        'service': 'CodeDetect API',
        'version': '1.1.0',
        'timestamp': datetime.now().isoformat()
    }), 200


@app.route('/api/debug/tools', methods=['GET'])
def debug_tools():
    """Debug endpoint to check if security tools are installed"""
    import shutil

    # Create a test file with obvious security issue
    test_file = '/tmp/test_bandit.py'
    with open(test_file, 'w') as f:
        f.write('import os\nos.system("rm -rf /")\n')

    # Run bandit on test file
    bandit_test = subprocess.run(
        ['bandit', test_file, '-f', 'json'],
        capture_output=True, text=True, check=False
    )

    return jsonify({
        'bandit_path': shutil.which('bandit'),
        'radon_path': shutil.which('radon'),
        'pylint_path': shutil.which('pylint'),
        'python_version': subprocess.run(['python', '--version'], capture_output=True, text=True).stdout,
        'bandit_test_exit_code': bandit_test.returncode,
        'bandit_test_stdout': bandit_test.stdout[:2000],
        'bandit_test_stderr': bandit_test.stderr[:500]
    }), 200


@app.route('/api/info', methods=['GET'])
def app_info():
    """
    Application information endpoint showing deployment details.

    Returns metadata about current deployment including version,
    environment, and security configuration.

    Returns:
        tuple: JSON response with deployment info and HTTP 200
    """
    # Get deployment info from environment variables (injected by GitHub Actions/Terraform)
    docker_tag = os.environ.get('DOCKER_TAG', 'unknown')
    deployment_time = os.environ.get('DEPLOYMENT_TIME', 'unknown')
    git_commit = os.environ.get('GIT_COMMIT', 'unknown')
    deployed_by = os.environ.get('DEPLOYED_BY', 'manual')
    active_env = os.environ.get('ACTIVE_ENVIRONMENT', 'unknown')

    return jsonify({
        'version': docker_tag,
        'deployment': {
            'docker_tag': docker_tag,
            'deployed_at': deployment_time,
            'git_commit': git_commit,
            'deployed_by': deployed_by,
            'active_environment': active_env,
            'instance_id': os.environ.get('INSTANCE_ID', 'unknown')
        },
        'features': [
            'AWS Parameter Store integration',
            'CloudWatch monitoring',
            'High Availability with Load Balancer',
            'Auto Scaling (2-4 instances)',
            'Automatic failover and self-healing',
            'Zero-downtime Blue/Green deployment',
            'Secure secrets management'
        ],
        'security': {
            'secret_key_configured': bool(app.config.get('SECRET_KEY') and
                                         app.config['SECRET_KEY'] != 'dev-secret-key-CHANGE-IN-PRODUCTION'),
            'using_parameter_store': bool(os.environ.get('SECRET_KEY')),
            's3_bucket_configured': bool(os.environ.get('S3_BUCKET_NAME'))
        },
        'environment': {
            'flask_env': os.environ.get('FLASK_ENV', 'prod'),
            's3_bucket': os.environ.get('S3_BUCKET_NAME', 'not set'),
            'aws_region': os.environ.get('AWS_REGION', 'eu-west-1')
        },
        'timestamp': datetime.now().isoformat()
    }), 200


@app.route('/api/history', methods=['GET'])
def get_history():
    """
    DEPRECATED - Removed for privacy
    History is no longer available to protect user privacy
    Use /api/stats for anonymous aggregate analytics instead
    """
    return jsonify({
        'message': 'History feature removed for privacy protection',
        'alternative': 'Use /api/stats for anonymous aggregate analytics'
    }), 410  # 410 Gone - resource no longer available




@app.route('/api/report', methods=['POST'])
def submit_report():
    """
    Handle user feedback and bug reports via AWS SNS.

    Validates input, sends notification via SNS to configured topic.

    Returns:
        tuple: JSON response with success/error message and HTTP status code
    """
    try:
        data = request.get_json()
        email = data.get('email', '').strip()
        report_type = data.get('type', '').strip()
        message = data.get('message', '').strip()
        timestamp = data.get('timestamp', datetime.now().isoformat())
        user_agent = data.get('user_agent', 'unknown')

        # Input validation
        if not email or not report_type or not message:
            return jsonify({'error': 'Email, type and message are required'}), 400

        # Validate email format
        email_pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        if not re.match(email_pattern, email):
            return jsonify({'error': 'Invalid email format'}), 400

        # Validate email length
        if len(email) > 100:
            return jsonify({'error': 'Email address too long'}), 400

        # Validate report type
        valid_types = ['bug', 'feature', 'feedback']
        if report_type not in valid_types:
            return jsonify({'error': f'Invalid report type. Must be one of: {", ".join(valid_types)}'}), 400

        # Validate message length
        if len(message) > 500:
            return jsonify({'error': 'Message must be 500 characters or less'}), 400
        if len(message) < 1:
            return jsonify({'error': 'Message cannot be empty'}), 400

        # Prepare SNS message in JSON format for Lambda
        sns_message = {
            'name': email.split('@')[0],  # Extract name from email
            'email': email,
            'type': report_type.title(),
            'message': message,
            'timestamp': timestamp,
            'user_agent': user_agent
        }

        # Send to SNS
        try:
            import json
            sns = boto3.client('sns', region_name='eu-west-1')
            topic_arn = os.environ.get('SNS_TOPIC_ARN')

            if not topic_arn:
                logger.warning("SNS_TOPIC_ARN not configured")
                return jsonify({'error': 'SNS not configured'}), 500

            response = sns.publish(
                TopicArn=topic_arn,
                Subject=f'CodeDetect: {report_type.upper()} Report',
                Message=json.dumps(sns_message)  # Send as JSON string
            )

            logger.info(f"SNS notification sent: {response['MessageId']}")
            return jsonify({
                'success': True,
                'message': 'Report sent successfully'
            }), 200

        except Exception as e:
            logger.error(f"SNS Error: {e}")
            return jsonify({'error': 'Failed to send notification'}), 500

    except Exception as e:
        logger.error(f"Report submission error: {e}")
        return jsonify({'error': 'Failed to process report'}), 500


@app.route('/api/stats', methods=['GET'])
def get_stats():
    """
    Get anonymous aggregate statistics for dashboard trends.

    Returns overall statistics and recent trend data without
    exposing individual user data.

    Returns:
        tuple: JSON response with statistics and HTTP status code
    """
    try:
        # Get last 10 analyses for trends
        recent_analyses = Analysis.query.order_by(
            Analysis.timestamp.desc()).limit(10).all()

        if not recent_analyses:
            return jsonify({
                'total_analyses': 0,
                'avg_score': 0,
                'total_security_issues': 0,
                'total_quality_issues': 0,
                'trend_data': []
            }), 200

        # Calculate overall stats
        total_analyses = Analysis.query.count()
        all_analyses = Analysis.query.all()

        avg_score = sum(a.score for a in all_analyses) / len(all_analyses) if all_analyses else 0
        total_security = sum(a.security_issues for a in all_analyses)
        total_quality = sum(a.total_issues for a in all_analyses)

        # Prepare trend data (last 10 in chronological order)
        # Anonymous - no filenames for privacy
        trend_data = [{
            'label': f'Analysis #{i+1}',  # Anonymous label instead of filename
            'timestamp': a.timestamp.isoformat(),
            'score': a.score,
            'total_issues': a.total_issues,
            'security_issues': a.security_issues,
            'complexity_issues': a.complexity_issues
        } for i, a in enumerate(reversed(recent_analyses))]

        return jsonify({
            'total_analyses': total_analyses,
            'avg_score': round(avg_score, 1),
            'total_security_issues': total_security,
            'total_quality_issues': total_quality,
            'trend_data': trend_data
        }), 200

    except Exception as e:
        logger.error(f"Stats retrieval error: {e}")
        return jsonify({'error': str(e)}), 500


if __name__ == '__main__':
    # SECURITY: Only enable debug mode via environment variable (default: False)
    debug_mode = os.environ.get('FLASK_DEBUG', 'False').lower() in ('true', '1', 'yes')

    logger.info("Starting CodeDetect Application...")
    logger.info(f"Debug mode: {debug_mode}")
    logger.info("Running on http://localhost:5000")
    app.run(debug=debug_mode, host='0.0.0.0', port=5000)
