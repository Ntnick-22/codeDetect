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

# Flask setup
app = Flask(
    __name__,
    static_folder='../frontend',
    static_url_path='',
    template_folder='../frontend'
)
CORS(app)

# ============================================================
# Database Configuration (works both locally and on AWS)
# ============================================================
app.config['SQLALCHEMY_DATABASE_URI'] = os.environ.get(
    'DATABASE_URL', 'sqlite:///codedetect.db')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db = SQLAlchemy(app)


# ============================================================
# Database Model
# ============================================================
class Analysis(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    filename = db.Column(db.String(255), nullable=False)
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)
    score = db.Column(db.Integer, nullable=False)
    total_issues = db.Column(db.Integer, default=0)
    security_issues = db.Column(db.Integer, default=0)
    complexity_issues = db.Column(db.Integer, default=0)
    analysis_data = db.Column(db.Text)

    def to_dict(self):
        return {
            'id': self.id,
            'filename': self.filename,
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
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS


def upload_to_s3(filepath, bucket_name, s3_key):
    """Upload file to AWS S3"""
    s3 = boto3.client('s3')
    try:
        s3.upload_file(filepath, bucket_name, s3_key)
        print(f"✅ Uploaded {s3_key} to {bucket_name}")
        return True
    except FileNotFoundError:
        print("❌ File not found for upload.")
        return False
    except NoCredentialsError:
        print("❌ AWS credentials not available.")
        return False
    except Exception as e:
        print(f"❌ Upload failed: {e}")
        return False


def run_pylint(filepath):
    """Run Pylint analysis"""
    try:
        result = subprocess.run(
            ['pylint', filepath, '--output-format=json'],
            capture_output=True, text=True, timeout=30
        )
        if result.stdout:
            return json.loads(result.stdout)
        return []
    except Exception as e:
        print(f"Pylint error: {e}")
        return []


def run_bandit(filepath):
    """Run Bandit security analysis"""
    try:
        result = subprocess.run(
            ['bandit', filepath, '-f', 'json'],
            capture_output=True, text=True, timeout=30
        )
        if result.stdout:
            data = json.loads(result.stdout)
            return data.get('results', [])
        return []
    except Exception as e:
        print(f"Bandit error: {e}")
        return []


def run_radon(filepath):
    """Run Radon complexity analysis"""
    try:
        result = subprocess.run(
            ['radon', 'cc', filepath, '-j'],
            capture_output=True, text=True, timeout=30
        )
        if result.stdout:
            return json.loads(result.stdout)
        return {}
    except Exception as e:
        print(f"Radon error: {e}")
        return {}


def calculate_score(pylint_issues, bandit_issues, complexity_data):
    """Calculate overall code quality score"""
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
    """Main endpoint for file analysis"""
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

        # === Upload to S3 before analyzing ===
        bucket_name = os.environ.get(
            'S3_BUCKET_NAME', 'codedetect-nick-uploads-12345')
        s3_key = f"uploads/{unique_filename}"
        upload_success = upload_to_s3(filepath, bucket_name, s3_key)
        if not upload_success:
            print("⚠️ S3 upload failed — continuing analysis anyway.")

        # Run analyses
        pylint_results = run_pylint(filepath)
        bandit_results = run_bandit(filepath)
        complexity_results = run_radon(filepath)
        score = calculate_score(
            pylint_results, bandit_results, complexity_results)

        response = {
            'filename': filename,
            'timestamp': timestamp,
            'score': score,
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
            print(f"Failed to create presigned URL: {e}")

        # Save to DB
        try:
            new_analysis = Analysis(
                filename=filename,
                score=score,
                total_issues=len(pylint_results),
                security_issues=len(bandit_results),
                complexity_issues=response['summary']['high_complexity_functions'],
                analysis_data=json.dumps(response)
            )
            db.session.add(new_analysis)
            db.session.commit()
        except Exception as e:
            print(f"Database save error: {e}")

        os.remove(filepath)  # cleanup local file
        return jsonify(response), 200

    except Exception as e:
        print(f"Analysis error: {e}")
        return jsonify({'error': 'Analysis failed', 'details': str(e)}), 500


@app.route('/api/health', methods=['GET'])
def health_check():
    return jsonify({
        'status': 'healthy',
        'service': 'CodeDetect API',
        'timestamp': datetime.now().isoformat()
    }), 200


@app.route('/api/history', methods=['GET'])
def get_history():
    try:
        analyses = Analysis.query.order_by(
            Analysis.timestamp.desc()).limit(5).all()
        return jsonify([analysis.to_dict() for analysis in analyses]), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500


if __name__ == '__main__':
    print("🚀 Starting CodeDetect Application...")
    print("🌐 Running on http://localhost:5000")
    app.run(debug=True, host='0.0.0.0', port=5000)
