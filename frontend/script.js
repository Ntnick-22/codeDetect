// Enhanced issue fix suggestions with examples
const fixSuggestions = {
    // Documentation issues
    'missing-docstring': {
        description: 'Add a docstring at the beginning of your function/class to describe what it does.',
        example: `def calculate_sum(a, b):
    """Calculate the sum of two numbers.

    Args:
        a (int): First number
        b (int): Second number

    Returns:
        int: Sum of a and b
    """
    return a + b`
    },
    'missing-module-docstring': {
        description: 'Add a docstring at the top of your module file.',
        example: `"""
This module provides utility functions for data processing.

Author: Your Name
Date: 2025-01-01
"""`
    },

    // Naming issues
    'invalid-name': {
        description: 'Use descriptive names following PEP 8 conventions: lowercase_with_underscores for variables and functions, CapitalizedWords for classes.',
        example: `# Bad
x = 5
MyVariable = 10

# Good
user_count = 5
max_retry_count = 10

class DataProcessor:  # Class names use CapWords
    pass`
    },
    'bad-whitespace': {
        description: 'Fix spacing issues around operators and commas.',
        example: `# Bad
x=5+3
my_list=[1,2,3]

# Good
x = 5 + 3
my_list = [1, 2, 3]`
    },

    // Code structure issues
    'line-too-long': {
        description: 'Break long lines into multiple lines. Maximum recommended length is 79-100 characters.',
        example: `# Bad
result = some_function(argument1, argument2, argument3, argument4, argument5)

# Good
result = some_function(
    argument1, argument2,
    argument3, argument4,
    argument5
)`
    },
    'trailing-whitespace': {
        description: 'Remove extra spaces at the end of lines. Most editors can do this automatically.',
        example: 'Configure your editor to strip trailing whitespace on save.'
    },
    'multiple-statements': {
        description: 'Put each statement on its own line for better readability.',
        example: `# Bad
x = 5; y = 10; print(x)

# Good
x = 5
y = 10
print(x)`
    },

    // Variable issues
    'unused-variable': {
        description: 'Remove unused variables or use them in your code. If intentionally unused, prefix with underscore.',
        example: `# Bad
def calculate(x, y):
    result = x + y
    temp = x * y  # unused
    return result

# Good
def calculate(x, y):
    result = x + y
    return result

# If needed for unpacking
data = get_data()
x, _unused = data  # Use _ prefix`
    },
    'undefined-variable': {
        description: 'Make sure the variable is defined before using it. Check for typos in variable names.',
        example: `# Bad
def process():
    print(value)  # value not defined

# Good
def process():
    value = 10
    print(value)`
    },
    'unused-import': {
        description: 'Remove unused imports or use them in your code.',
        example: `# Bad
import os
import sys  # unused

# Good
import os`
    },

    // Logic issues
    'consider-using-enumerate': {
        description: 'Use enumerate() when you need both index and value in a loop.',
        example: `# Bad
for i in range(len(items)):
    print(i, items[i])

# Good
for i, item in enumerate(items):
    print(i, item)`
    },
    'consider-using-with': {
        description: 'Use "with" statement for proper resource management (files, connections, etc.).',
        example: `# Bad
file = open('data.txt', 'r')
content = file.read()
file.close()

# Good
with open('data.txt', 'r') as file:
    content = file.read()`
    },
    'simplifiable-if-statement': {
        description: 'Simplify if-else statements that return boolean values.',
        example: `# Bad
if condition:
    return True
else:
    return False

# Good
return condition`
    },

    // Security issues (Bandit)
    'B105': {
        description: 'CRITICAL: Hardcoded password detected! Never store passwords in code. Use environment variables or secure vaults.',
        example: `# Bad
password = "mysecretpass123"

# Good
import os
password = os.environ.get('DB_PASSWORD')

# Or use python-dotenv
from dotenv import load_dotenv
load_env()
password = os.getenv('DB_PASSWORD')`
    },
    'B106': {
        description: 'CRITICAL: Hardcoded password in function argument. Use configuration or environment variables.',
        example: `# Bad
def connect_db(password="default123"):
    pass

# Good
def connect_db(password=None):
    password = password or os.environ.get('DB_PASSWORD')`
    },
    'B201': {
        description: 'SECURITY WARNING: Using flask with debug=True is dangerous in production. Debug mode can expose sensitive information.',
        example: `# Bad
app.run(debug=True)

# Good
debug_mode = os.environ.get('FLASK_ENV') == 'development'
app.run(debug=debug_mode)`
    },
    'B608': {
        description: 'SQL INJECTION RISK: Use parameterized queries instead of string formatting.',
        example: `# Bad
query = f"SELECT * FROM users WHERE id = {user_id}"
cursor.execute(query)

# Good - Using parameterized query
query = "SELECT * FROM users WHERE id = ?"
cursor.execute(query, (user_id,))

# Or with SQLAlchemy
query = select(User).where(User.id == user_id)`
    },
    'B301': {
        description: 'Avoid using pickle - it can execute arbitrary code. Use JSON for data serialization when possible.',
        example: `# Bad
import pickle
data = pickle.loads(untrusted_data)

# Good
import json
data = json.loads(trusted_data)

# Or use safer alternatives like msgpack`
    },
    'B303': {
        description: 'Using MD5 or SHA1 for security purposes is insecure. Use SHA256 or better.',
        example: `# Bad
import hashlib
hash = hashlib.md5(data).hexdigest()

# Good
import hashlib
hash = hashlib.sha256(data).hexdigest()

# For passwords, use proper password hashing
from werkzeug.security import generate_password_hash
hashed = generate_password_hash(password)`
    },
    'B602': {
        description: 'Shell injection risk when using shell=True. Avoid shell=True or sanitize inputs carefully.',
        example: `# Bad
subprocess.call(f"echo {user_input}", shell=True)

# Good
subprocess.call(["echo", user_input])  # No shell=True`
    },

    // Default
    'default': {
        description: 'Review this issue carefully and consider refactoring this section of code. Check the official documentation for best practices.',
        example: null
    }
};

function getSuggestion(issueSymbol) {
    const suggestion = fixSuggestions[issueSymbol] || fixSuggestions['default'];
    return typeof suggestion === 'string' ? { description: suggestion, example: null } : suggestion;
}

// Toggle details function
window.toggleDetails = function(id) {
    const details = document.getElementById(id);
    const icon = document.getElementById(`${id}-icon`);
    
    if (details && icon) {
        if (details.style.display === 'none') {
            details.style.display = 'block';
            icon.textContent = '▼';
        } else {
            details.style.display = 'none';
            icon.textContent = '▶';
        }
    }
};

// Global variables
let selectedFile = null;
let currentAnalysisData = null;

// File input handling
document.getElementById('fileInput').addEventListener('change', function(e) {
    selectedFile = e.target.files[0];
    if (selectedFile) {
        document.getElementById('fileInfo').textContent = `Selected: ${selectedFile.name}`;
        document.getElementById('analyzeBtn').disabled = false;
    }
});

// Drag and drop functionality
const uploadArea = document.getElementById('uploadArea');

uploadArea.addEventListener('dragover', (e) => {
    e.preventDefault();
    uploadArea.style.background = '#e9ecef';
});

uploadArea.addEventListener('dragleave', () => {
    uploadArea.style.background = '#f8f9fa';
});

uploadArea.addEventListener('drop', (e) => {
    e.preventDefault();
    uploadArea.style.background = '#f8f9fa';
    const file = e.dataTransfer.files[0];
    if (file && file.name.endsWith('.py')) {
        selectedFile = file;
        document.getElementById('fileInfo').textContent = `Selected: ${file.name}`;
        document.getElementById('analyzeBtn').disabled = false;
    } else {
        alert('Please upload a .py file');
    }
});

// Analyze button
document.getElementById('analyzeBtn').addEventListener('click', async () => {
    if (!selectedFile) return;

    const btn = document.getElementById('analyzeBtn');
    const btnText = document.getElementById('btnText');
    const btnSpinner = document.getElementById('btnSpinner');
    const loadingMessage = document.getElementById('loadingMessage');
    
    // Show loading state
    btn.disabled = true;
    btnSpinner.style.display = 'inline-block';
    btnText.textContent = ' Analyzing...';
    loadingMessage.style.display = 'block';

    const formData = new FormData();
    formData.append('file', selectedFile);

    try {
        const response = await fetch('/api/analyze', {
            method: 'POST',
            body: formData
        });

        const data = await response.json();

        if (response.ok) {
            // Save file_hash to localStorage for persistence
            if (data.file_hash) {
                localStorage.setItem('last_analysis_hash', data.file_hash);
                localStorage.setItem('last_analysis_time', new Date().toISOString());
            }
            displayResults(data);
        } else {
            alert('Error: ' + data.error);
        }
    } catch (error) {
        alert('Analysis failed: ' + error.message);
    } finally {
        // Hide loading state
        btn.disabled = false;
        btnSpinner.style.display = 'none';
        btnText.textContent = 'Analyze Code';
        loadingMessage.style.display = 'none';
    }
});

// Display results function
function displayResults(data) {
    // Store data for download
    currentAnalysisData = data;

    const downloadBtn = document.getElementById('downloadBtn');
    if (downloadBtn) {
        downloadBtn.style.display = 'inline-block';
    }
    
    // Show results section
    document.getElementById('results').style.display = 'block';
    
    // Update score
    const score = data.score;
    const scoreCircle = document.getElementById('scoreCircle');
    scoreCircle.textContent = score;
    
    // Color based on score
    scoreCircle.className = 'score-circle';
    if (score >= 80) {
        scoreCircle.classList.add('score-good');
        document.getElementById('scoreText').textContent = 'Excellent! Your code quality is great.';
    } else if (score >= 50) {
        scoreCircle.classList.add('score-medium');
        document.getElementById('scoreText').textContent = 'Good, but there\'s room for improvement.';
    } else {
        scoreCircle.classList.add('score-bad');
        document.getElementById('scoreText').textContent = 'Needs work. Check the issues below.';
    }

    // Update summary
    document.getElementById('totalIssues').textContent = data.summary.total_issues;
    document.getElementById('securityIssues').textContent = data.summary.security_issues;
    document.getElementById('complexityIssues').textContent = data.summary.high_complexity_functions;

    // Display issues
    displayIssues(data.analysis);

    // Create charts
    createCharts(data);

    // Note: History removed for privacy - analytics updated on dashboard instead

    // Scroll to results
    document.getElementById('results').scrollIntoView({ behavior: 'smooth' });
}

// Display issues function
function displayIssues(analysis) {
    const issuesList = document.getElementById('issuesList');
    issuesList.innerHTML = '';

    // Security issues
    if (analysis.security_issues && analysis.security_issues.length > 0) {
        issuesList.innerHTML += '<h6 class="text-danger mt-3"><i class="bi bi-shield-exclamation me-2"></i>Security Issues:</h6>';
        analysis.security_issues.forEach((issue, index) => {
            const issueId = `security-${index}`;
            const suggestion = getSuggestion(issue.test_id || 'default');
            issuesList.innerHTML += `
                <div class="alert alert-danger mb-2">
                    <span class="issue-badge severity-${issue.issue_severity}">${issue.issue_severity}</span>
                    <span class="issue-badge">Confidence: ${issue.issue_confidence}</span>
                    <br>
                    <strong>Line ${issue.line_number}:</strong> ${issue.issue_text}
                    <br>
                    <button class="btn btn-sm btn-outline-danger mt-2" onclick="toggleDetails('${issueId}')">
                        <span id="${issueId}-icon">▶</span> How to Fix
                    </button>
                    <div id="${issueId}" class="issue-details mt-2" style="display: none;">
                        <hr>
                        <strong>💡 How to Fix:</strong>
                        <p>${suggestion.description}</p>
                        ${suggestion.example ? `
                        <strong>📝 Example:</strong>
                        <pre class="bg-dark text-light p-3 rounded"><code>${suggestion.example}</code></pre>
                        ` : ''}
                    </div>
                </div>
            `;
        });
    }

    // Quality issues
    if (analysis.quality_issues && analysis.quality_issues.length > 0) {
        issuesList.innerHTML += '<h6 class="text-primary mt-3"><i class="bi bi-code-square me-2"></i>Code Quality Issues:</h6>';

        const displayIssues = analysis.quality_issues.slice(0, 10);

        displayIssues.forEach((issue, index) => {
            const issueId = `quality-${index}`;
            const alertClass = issue.type === 'error' ? 'danger' : issue.type === 'warning' ? 'warning' : 'info';
            const suggestion = getSuggestion(issue.symbol || 'default');

            issuesList.innerHTML += `
                <div class="alert alert-${alertClass} mb-2">
                    <div class="d-flex justify-content-between align-items-start">
                        <div>
                            <strong>Line ${issue.line}:</strong> ${issue.message}
                            <br>
                            <small class="text-muted"><i class="bi bi-tag me-1"></i>${issue.symbol}</small>
                        </div>
                        <span class="badge bg-${alertClass === 'danger' ? 'danger' : alertClass === 'warning' ? 'warning' : 'info'}">${issue.type}</span>
                    </div>
                    <button class="btn btn-sm btn-outline-secondary mt-2" onclick="toggleDetails('${issueId}')">
                        <span id="${issueId}-icon">▶</span> How to Fix
                    </button>
                    <div id="${issueId}" class="issue-details mt-2" style="display: none;">
                        <hr>
                        <strong>💡 How to Fix:</strong>
                        <p>${suggestion.description}</p>
                        ${suggestion.example ? `
                        <strong>📝 Example:</strong>
                        <pre class="bg-dark text-light p-3 rounded"><code>${suggestion.example}</code></pre>
                        ` : ''}
                    </div>
                </div>
            `;
        });

        if (analysis.quality_issues.length > 10) {
            issuesList.innerHTML += `
                <div class="alert alert-info">
                    <i class="bi bi-info-circle me-2"></i>
                    <strong>${analysis.quality_issues.length - 10} more issues found.</strong>
                    Showing top 10 issues. Fix these first and re-analyze for best results.
                </div>
            `;
        }
    }

    if (issuesList.innerHTML === '') {
        issuesList.innerHTML = '<p class="text-success">No major issues found! Great job!</p>';
    }
}

// Create charts function
function createCharts(data) {
    // Destroy existing chart if it exists
    if (window.issueTypeChart && typeof window.issueTypeChart.destroy === 'function') {
        window.issueTypeChart.destroy();
    }

    // Issue Type Pie Chart
    const issueTypeCtx = document.getElementById('issueTypeChart').getContext('2d');
    window.issueTypeChart = new Chart(issueTypeCtx, {
        type: 'doughnut',
        data: {
            labels: ['Quality Issues', 'Security Issues', 'Complexity Issues'],
            datasets: [{
                data: [
                    data.summary.total_issues,
                    data.summary.security_issues,
                    data.summary.high_complexity_functions
                ],
                backgroundColor: [
                    'rgba(54, 162, 235, 0.8)',
                    'rgba(255, 99, 132, 0.8)',
                    'rgba(255, 206, 86, 0.8)'
                ],
                borderColor: [
                    'rgba(54, 162, 235, 1)',
                    'rgba(255, 99, 132, 1)',
                    'rgba(255, 206, 86, 1)'
                ],
                borderWidth: 2,
                hoverOffset: 4
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: true,
            aspectRatio: 1.5,
            plugins: {
                legend: {
                    position: 'bottom',
                    labels: {
                        padding: 10,
                        font: {
                            size: 11
                        },
                        color: '#000000'
                    }
                },
                title: {
                    display: true,
                    text: 'Issue Distribution',
                    font: {
                        size: 13,
                        weight: 'bold'
                    },
                    padding: {
                        top: 5,
                        bottom: 10
                    },
                    color: '#000000'
                }
            }
        }
    });
}

// Download Report Function
function downloadReport(data) {
    const filename = data.filename.replace('.py', '');
    const timestamp = new Date().toLocaleString();

    let content = `
================================================================
              CODEDETECT ANALYSIS REPORT
================================================================

File: ${data.filename}
Analysis Date: ${timestamp}
Quality Score: ${data.score}/100

================================================================
SUMMARY
================================================================
* Total Quality Issues: ${data.summary.total_issues}
* Security Issues: ${data.summary.security_issues}
* High Complexity Functions: ${data.summary.high_complexity_functions}

`;

    if (data.analysis.security_issues && data.analysis.security_issues.length > 0) {
        content += `
================================================================
SECURITY ISSUES (${data.analysis.security_issues.length})
================================================================
`;
        data.analysis.security_issues.forEach((issue, index) => {
            content += `
${index + 1}. [${issue.issue_severity}] Line ${issue.line_number}
   ${issue.issue_text}
`;
        });
    }

    if (data.analysis.quality_issues && data.analysis.quality_issues.length > 0) {
        content += `
================================================================
CODE QUALITY ISSUES (Top 10)
================================================================
`;
        data.analysis.quality_issues.slice(0, 10).forEach((issue, index) => {
            content += `
${index + 1}. Line ${issue.line}
   ${issue.message}
`;
        });
    }

    content += `
================================================================
Report generated by CodeDetect
https://github.com/Ntnick-22/codeDetect
================================================================
`;

    const blob = new Blob([content], { type: 'text/plain; charset=utf-8' });
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `CodeDetect_Report_${filename}_${Date.now()}.txt`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    window.URL.revokeObjectURL(url);
}

// Load anonymous analytics
async function loadAnalytics() {
    try {
        const response = await fetch('/api/stats');
        const data = await response.json();

        // Update metric cards
        document.getElementById('total-analyses').textContent = data.total_analyses || 0;
        document.getElementById('avg-score').textContent = data.avg_score ? data.avg_score.toFixed(1) : '0.0';
        document.getElementById('total-security').textContent = data.total_security_issues || 0;
        document.getElementById('total-quality').textContent = data.total_quality_issues || 0;

        // Update trends chart
        if (data.trend_data && data.trend_data.length > 0) {
            createTrendsChart(data.trend_data);
        }
    } catch (error) {
        console.error('Failed to load analytics:', error);
        document.getElementById('total-analyses').textContent = 'Error';
        document.getElementById('avg-score').textContent = 'Error';
        document.getElementById('total-security').textContent = 'Error';
        document.getElementById('total-quality').textContent = 'Error';
    }
}

// Create trends chart
function createTrendsChart(trendData) {
    const ctx = document.getElementById('trendsChart');
    if (!ctx) return;

    // Destroy existing chart if any
    if (window.trendsChartInstance) {
        window.trendsChartInstance.destroy();
    }

    window.trendsChartInstance = new Chart(ctx, {
        type: 'line',
        data: {
            labels: trendData.map(d => d.label),
            datasets: [{
                label: 'Quality Score',
                data: trendData.map(d => d.score),
                borderColor: 'rgb(75, 192, 192)',
                backgroundColor: 'rgba(75, 192, 192, 0.1)',
                tension: 0.1,
                fill: true
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: true,
            plugins: {
                legend: {
                    display: true
                },
                tooltip: {
                    callbacks: {
                        afterLabel: function(context) {
                            const dataIndex = context.dataIndex;
                            const data = trendData[dataIndex];
                            return [
                                `Total Issues: ${data.total_issues}`,
                                `Security Issues: ${data.security_issues}`,
                                `Complexity Issues: ${data.complexity_issues}`
                            ];
                        }
                    }
                }
            },
            scales: {
                y: {
                    beginAtZero: true,
                    max: 100,
                    title: {
                        display: true,
                        text: 'Quality Score'
                    }
                },
                x: {
                    title: {
                        display: true,
                        text: 'Recent Analyses (Anonymous)'
                    }
                }
            }
        }
    });
}

// ============================================
// NAVIGATION & UI CONTROLS
// ============================================

// Section navigation
function showSection(sectionName) {
    // Hide all sections
    document.querySelectorAll('.content-section').forEach(section => {
        section.classList.remove('active');
    });

    // Show selected section
    const targetSection = document.getElementById(`section-${sectionName}`);
    if (targetSection) {
        targetSection.classList.add('active');
    }

    // Update sidebar active state
    document.querySelectorAll('.sidebar-item').forEach(item => {
        item.classList.remove('active');
    });
    event.target.closest('.sidebar-item')?.classList.add('active');

    // Load analytics when analytics section is opened
    if (sectionName === 'analytics') {
        loadAnalytics();
    }

    // Update dashboard stats when dashboard is opened
    if (sectionName === 'dashboard') {
        updateDashboardStats();
    }

    // Load deployment info when deployment section is opened
    if (sectionName === 'deployment') {
        loadDeploymentInfo();
    }
}

// Load deployment information from API
async function loadDeploymentInfo() {
    try {
        const response = await fetch('/api/info');
        if (!response.ok) throw new Error('Failed to fetch deployment info');

        const data = await response.json();

        // Update deployment information
        document.getElementById('docker-tag').innerHTML =
            `<code class="text-primary">${data.deployment?.docker_tag || 'unknown'}</code>`;

        // Format deployment time
        const deployedAt = data.deployment?.deployed_at || 'unknown';
        const formattedTime = deployedAt !== 'unknown' ?
            new Date(deployedAt).toLocaleString() : 'unknown';
        document.getElementById('deployed-at').textContent = formattedTime;

        document.getElementById('git-commit').innerHTML =
            `<code>${data.deployment?.git_commit || 'unknown'}</code>`;

        // Environment badge with color
        const env = data.deployment?.active_environment || 'unknown';
        const envBadge = env === 'blue' ?
            `<span class="badge bg-primary">${env.toUpperCase()}</span>` :
            env === 'green' ?
            `<span class="badge bg-success">${env.toUpperCase()}</span>` :
            `<span class="badge bg-secondary">${env.toUpperCase()}</span>`;
        document.getElementById('active-env').innerHTML = envBadge;

        document.getElementById('instance-id').innerHTML =
            `<code class="text-muted">${data.deployment?.instance_id || 'unknown'}</code>`;

        // Deployed by with icon
        const deployedBy = data.deployment?.deployed_by || 'manual';
        const deployIcon = deployedBy === 'github-actions' ?
            '<i class="bi bi-github me-1"></i>' : '<i class="bi bi-person me-1"></i>';
        document.getElementById('deployed-by').innerHTML =
            `${deployIcon}${deployedBy}`;

    } catch (error) {
        console.error('Error loading deployment info:', error);
        // Show error state
        ['docker-tag', 'deployed-at', 'git-commit', 'active-env', 'instance-id', 'deployed-by'].forEach(id => {
            document.getElementById(id).innerHTML =
                '<span class="text-danger"><i class="bi bi-exclamation-triangle"></i> Error</span>';
        });
    }
}

// Refresh deployment info
function refreshDeploymentInfo() {
    loadDeploymentInfo();
}

// Make functions global
window.showSection = showSection;
window.refreshDeploymentInfo = refreshDeploymentInfo;

// Restore last analysis from localStorage
async function restoreLastAnalysis() {
    const lastHash = localStorage.getItem('last_analysis_hash');
    const lastTime = localStorage.getItem('last_analysis_time');

    if (!lastHash) return;

    // Only restore if less than 7 days old (matching S3 file retention)
    if (lastTime) {
        const analysisTime = new Date(lastTime);
        const now = new Date();
        const daysDiff = (now - analysisTime) / (1000 * 60 * 60 * 24);

        if (daysDiff > 7) {
            // Analysis too old, clear it
            localStorage.removeItem('last_analysis_hash');
            localStorage.removeItem('last_analysis_time');
            return;
        }
    }

    try {
        const response = await fetch(`/api/analysis/${lastHash}`);
        if (response.ok) {
            const data = await response.json();

            // Reconstruct the expected data structure
            if (data.analysis) {
                const analysisData = {
                    filename: data.analysis.filename || 'Previous Analysis',
                    timestamp: data.timestamp,
                    score: data.score,
                    original_code: data.analysis.original_code || '',
                    analysis: {
                        quality_issues: data.analysis.quality_issues || [],
                        security_issues: data.analysis.security_issues || [],
                        complexity: data.analysis.complexity || {}
                    },
                    summary: data.analysis.summary || {
                        total_issues: data.total_issues,
                        security_issues: data.security_issues,
                        high_complexity_functions: data.complexity_issues
                    },
                    file_hash: data.file_hash,
                    s3_url: data.s3_url
                };

                displayResults(analysisData);

                // Show a notification that results were restored
                console.log('✅ Previous analysis restored from database');
            }
        } else {
            // Analysis not found, clear localStorage
            localStorage.removeItem('last_analysis_hash');
            localStorage.removeItem('last_analysis_time');
        }
    } catch (error) {
        console.error('Failed to restore last analysis:', error);
    }
}

// Sidebar toggle for mobile
document.addEventListener('DOMContentLoaded', () => {
    const sidebarToggle = document.getElementById('sidebarToggle');
    const sidebar = document.getElementById('sidebar');
    const mainContent = document.getElementById('mainContent');

    if (sidebarToggle) {
        sidebarToggle.addEventListener('click', () => {
            sidebar.classList.toggle('open');
            mainContent.classList.toggle('expanded');
        });
    }

    // Load initial data
    updateDashboardStats();
    loadVersionBadge();
    restoreLastAnalysis();  // Restore previous analysis if exists
    // Note: Analytics loaded when analytics section is opened

    // Download button
    const downloadBtn = document.getElementById('downloadBtn');
    if (downloadBtn) {
        downloadBtn.addEventListener('click', () => {
            if (currentAnalysisData) {
                downloadReport(currentAnalysisData);
            }
        });
    }

});

// Load version badge and region in top navigation
async function loadVersionBadge() {
    try {
        const response = await fetch('/api/info');
        if (!response.ok) throw new Error('Failed to fetch version');

        const data = await response.json();

        // Update version
        const versionText = document.getElementById('version-text');
        if (versionText && data.deployment?.docker_tag) {
            versionText.textContent = data.deployment.docker_tag;
        } else if (versionText) {
            versionText.textContent = 'local-dev';
        }

        // Update region dynamically
        const regionText = document.getElementById('region-text');
        if (regionText && data.environment?.aws_region) {
            // Format region nicely (eu-west-1 => EU-West-1)
            const region = data.environment.aws_region;
            const formatted = region.split('-').map(part =>
                part.charAt(0).toUpperCase() + part.slice(1)
            ).join('-');
            regionText.textContent = formatted;
        } else if (regionText) {
            regionText.textContent = 'Local';
        }
    } catch (error) {
        console.error('Error loading version:', error);
        const versionText = document.getElementById('version-text');
        if (versionText) {
            versionText.textContent = 'error';
        }
        const regionText = document.getElementById('region-text');
        if (regionText) {
            regionText.textContent = 'Unknown';
        }
    }
}


// Update dashboard statistics
async function updateDashboardStats() {
    try {
        const response = await fetch('/api/stats');
        const data = await response.json();

        if (data) {
            // Show stats grid if we have data
            const statsGridContainer = document.getElementById('stats-grid-container');
            if (data.total_analyses > 0 && statsGridContainer) {
                statsGridContainer.style.display = 'block';

                // Update stat cards
                document.getElementById('dashTotalAnalyses').textContent = data.total_analyses;
                document.getElementById('dashAvgScore').textContent = data.avg_score || '--';
                document.getElementById('dashSecurityIssues').textContent = data.total_security_issues;
                document.getElementById('dashQualityIssues').textContent = data.total_quality_issues;
            }

            // Create trend charts if we have data
            if (data.trend_data && data.trend_data.length > 0) {
                createDashboardTrendCharts(data.trend_data);
            } else {
                // Show "no data" message in charts
                showNoDataMessage('scoreTrendChart', 'No trend data available yet');
                showNoDataMessage('issuesTrendChart', 'No trend data available yet');
            }
        }
    } catch (error) {
        console.error('Failed to update dashboard stats:', error);
    }
}

// Create dashboard trend charts
function createDashboardTrendCharts(trendData) {
    // Destroy existing charts if they exist
    if (window.scoreTrendChart && typeof window.scoreTrendChart.destroy === 'function') {
        window.scoreTrendChart.destroy();
    }
    if (window.issuesTrendChart && typeof window.issuesTrendChart.destroy === 'function') {
        window.issuesTrendChart.destroy();
    }

    // Prepare labels (shortened filenames or indices)
    const labels = trendData.map((item, index) => `#${index + 1}`);
    const scores = trendData.map(item => item.score);
    const qualityIssues = trendData.map(item => item.total_issues);
    const securityIssues = trendData.map(item => item.security_issues);
    const complexityIssues = trendData.map(item => item.complexity_issues);

    // Score Trend Chart (Line Chart)
    const scoreTrendCtx = document.getElementById('scoreTrendChart');
    if (scoreTrendCtx) {
        window.scoreTrendChart = new Chart(scoreTrendCtx.getContext('2d'), {
            type: 'line',
            data: {
                labels: labels,
                datasets: [{
                    label: 'Quality Score',
                    data: scores,
                    borderColor: 'rgb(75, 192, 192)',
                    backgroundColor: 'rgba(75, 192, 192, 0.2)',
                    tension: 0.3,
                    fill: true,
                    pointRadius: 5,
                    pointHoverRadius: 7
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        display: true,
                        position: 'bottom'
                    },
                    tooltip: {
                        callbacks: {
                            title: function(context) {
                                const index = context[0].dataIndex;
                                return trendData[index].filename;
                            },
                            label: function(context) {
                                return `Score: ${context.parsed.y}/100`;
                            }
                        }
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        max: 100,
                        ticks: {
                            stepSize: 20
                        },
                        title: {
                            display: true,
                            text: 'Score (0-100)'
                        }
                    },
                    x: {
                        title: {
                            display: true,
                            text: 'Recent Analyses'
                        }
                    }
                }
            }
        });
    }

    // Issues Trend Chart (Stacked Bar Chart)
    const issuesTrendCtx = document.getElementById('issuesTrendChart');
    if (issuesTrendCtx) {
        window.issuesTrendChart = new Chart(issuesTrendCtx.getContext('2d'), {
            type: 'bar',
            data: {
                labels: labels,
                datasets: [
                    {
                        label: 'Quality Issues',
                        data: qualityIssues,
                        backgroundColor: 'rgba(54, 162, 235, 0.8)',
                        borderColor: 'rgb(54, 162, 235)',
                        borderWidth: 1
                    },
                    {
                        label: 'Security Issues',
                        data: securityIssues,
                        backgroundColor: 'rgba(255, 99, 132, 0.8)',
                        borderColor: 'rgb(255, 99, 132)',
                        borderWidth: 1
                    },
                    {
                        label: 'Complexity Issues',
                        data: complexityIssues,
                        backgroundColor: 'rgba(255, 206, 86, 0.8)',
                        borderColor: 'rgb(255, 206, 86)',
                        borderWidth: 1
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        display: true,
                        position: 'bottom'
                    },
                    tooltip: {
                        callbacks: {
                            title: function(context) {
                                const index = context[0].dataIndex;
                                return trendData[index].filename;
                            }
                        }
                    }
                },
                scales: {
                    x: {
                        stacked: true,
                        title: {
                            display: true,
                            text: 'Recent Analyses'
                        }
                    },
                    y: {
                        stacked: true,
                        beginAtZero: true,
                        title: {
                            display: true,
                            text: 'Number of Issues'
                        },
                        ticks: {
                            stepSize: 1,
                            precision: 0
                        }
                    }
                }
            }
        });
    }
}

// Show "no data" message in chart canvas
function showNoDataMessage(canvasId, message) {
    const canvas = document.getElementById(canvasId);
    if (canvas) {
        const ctx = canvas.getContext('2d');
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        ctx.font = '16px Arial';
        ctx.fillStyle = '#666';
        ctx.textAlign = 'center';
        ctx.fillText(message, canvas.width / 2, canvas.height / 2);
    }
}