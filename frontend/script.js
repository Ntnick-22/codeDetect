// Issue fix suggestions
const fixSuggestions = {
    'missing-docstring': 'Add a docstring at the beginning of your function/class. Example: """This function does X"""',
    'line-too-long': 'Break long lines into multiple lines. Maximum recommended length is 79-100 characters.',
    'trailing-whitespace': 'Remove extra spaces at the end of lines.',
    'unused-variable': 'Remove unused variables or use them in your code.',
    'undefined-variable': 'Make sure the variable is defined before using it. Check for typos.',
    'invalid-name': 'Use descriptive names. Variables: lowercase_with_underscores',
    'hardcoded-password': 'CRITICAL: Never hardcode passwords! Use environment variables.',
    'sql-injection': 'CRITICAL: Use parameterized queries. Never concatenate user input into SQL.',
    'default': 'Review the issue and consider refactoring this section of code.'
};

function getSuggestion(issueSymbol) {
    return fixSuggestions[issueSymbol] || fixSuggestions['default'];
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
    
    // Reload history
    loadHistory();

    // Scroll to results
    document.getElementById('results').scrollIntoView({ behavior: 'smooth' });
}

// Display issues function
function displayIssues(analysis) {
    const issuesList = document.getElementById('issuesList');
    issuesList.innerHTML = '';

    // Security issues
    if (analysis.security_issues && analysis.security_issues.length > 0) {
        issuesList.innerHTML += '<h6 class="text-danger mt-3">Security Issues:</h6>';
        analysis.security_issues.forEach((issue, index) => {
            const issueId = `security-${index}`;
            issuesList.innerHTML += `
                <div class="alert alert-danger mb-2">
                    <span class="issue-badge severity-${issue.issue_severity}">${issue.issue_severity}</span>
                    <span class="issue-badge">Confidence: ${issue.issue_confidence}</span>
                    <br>
                    <strong>Line ${issue.line_number}:</strong> ${issue.issue_text}
                    <br>
                    <button class="btn btn-sm btn-outline-danger mt-2" onclick="toggleDetails('${issueId}')">
                        <span id="${issueId}-icon">▶</span> Show Details
                    </button>
                    <div id="${issueId}" class="issue-details mt-2" style="display: none;">
                        <hr>
                        <strong>💡 How to Fix:</strong>
                        <p class="mb-0">${getSuggestion(issue.test_id || 'default')}</p>
                    </div>
                </div>
            `;
        });
    }

    // Quality issues
    if (analysis.quality_issues && analysis.quality_issues.length > 0) {
        issuesList.innerHTML += '<h6 class="text-primary mt-3">Code Quality Issues:</h6>';
        
        const displayIssues = analysis.quality_issues.slice(0, 10);
        
        displayIssues.forEach((issue, index) => {
            const issueId = `quality-${index}`;
            const alertClass = issue.type === 'error' ? 'danger' : issue.type === 'warning' ? 'warning' : 'info';
            
            issuesList.innerHTML += `
                <div class="alert alert-${alertClass} mb-2">
                    <strong>Line ${issue.line}:</strong> ${issue.message}
                    <br>
                    <small class="text-muted">Type: ${issue.symbol}</small>
                    <br>
                    <button class="btn btn-sm btn-outline-secondary mt-2" onclick="toggleDetails('${issueId}')">
                        <span id="${issueId}-icon">▶</span> How to Fix
                    </button>
                    <div id="${issueId}" class="issue-details mt-2" style="display: none;">
                        <hr>
                        <strong>💡 Suggestion:</strong>
                        <p class="mb-0">${getSuggestion(issue.symbol || 'default')}</p>
                    </div>
                </div>
            `;
        });
        
        if (analysis.quality_issues.length > 10) {
            issuesList.innerHTML += `<p class="text-muted"><small>... and ${analysis.quality_issues.length - 10} more issues</small></p>`;
        }
    }

    if (issuesList.innerHTML === '') {
        issuesList.innerHTML = '<p class="text-success">No major issues found! Great job!</p>';
    }
}

// Create charts function
function createCharts(data) {
    // Destroy existing charts if they exist
    if (window.issueTypeChart && typeof window.issueTypeChart.destroy === 'function') {
        window.issueTypeChart.destroy();
    }
    if (window.severityChart && typeof window.severityChart.destroy === 'function') {
        window.severityChart.destroy();
    }

    // Issue Type Pie Chart
    const issueTypeCtx = document.getElementById('issueTypeChart').getContext('2d');
    window.issueTypeChart = new Chart(issueTypeCtx, {
        type: 'pie',
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
                borderWidth: 2
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: true,
            plugins: {
                legend: {
                    position: 'bottom'
                },
                title: {
                    display: true,
                    text: 'Issue Distribution'
                }
            }
        }
    });

    // Severity Bar Chart
    const severityCtx = document.getElementById('severityChart').getContext('2d');
    
    let highCount = 0, mediumCount = 0, lowCount = 0;
    if (data.analysis.security_issues) {
        data.analysis.security_issues.forEach(issue => {
            const severity = issue.issue_severity;
            if (severity === 'HIGH') highCount++;
            else if (severity === 'MEDIUM') mediumCount++;
            else lowCount++;
        });
    }

    window.severityChart = new Chart(severityCtx, {
        type: 'bar',
        data: {
            labels: ['High', 'Medium', 'Low'],
            datasets: [{
                label: 'Security Issue Severity',
                data: [highCount, mediumCount, lowCount],
                backgroundColor: [
                    'rgba(255, 99, 132, 0.8)',
                    'rgba(255, 206, 86, 0.8)',
                    'rgba(75, 192, 192, 0.8)'
                ],
                borderWidth: 2
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: true,
            plugins: {
                legend: {
                    display: false
                },
                title: {
                    display: true,
                    text: 'Security Issue Severity'
                }
            },
            scales: {
                y: {
                    beginAtZero: true,
                    ticks: {
                        stepSize: 1
                    }
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
╔════════════════════════════════════════════════════════════╗
║              CODEDETECT ANALYSIS REPORT                    ║
╚════════════════════════════════════════════════════════════╝

File: ${data.filename}
Analysis Date: ${timestamp}
Quality Score: ${data.score}/100

═══════════════════════════════════════════════════════════════
📊 SUMMARY
═══════════════════════════════════════════════════════════════
• Total Quality Issues: ${data.summary.total_issues}
• Security Issues: ${data.summary.security_issues}
• High Complexity Functions: ${data.summary.high_complexity_functions}

`;

    if (data.analysis.security_issues && data.analysis.security_issues.length > 0) {
        content += `
═══════════════════════════════════════════════════════════════
🔒 SECURITY ISSUES (${data.analysis.security_issues.length})
═══════════════════════════════════════════════════════════════
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
═══════════════════════════════════════════════════════════════
📝 CODE QUALITY ISSUES (Top 10)
═══════════════════════════════════════════════════════════════
`;
        data.analysis.quality_issues.slice(0, 10).forEach((issue, index) => {
            content += `
${index + 1}. Line ${issue.line}
   ${issue.message}
`;
        });
    }

    content += `
═══════════════════════════════════════════════════════════════
Report generated by CodeDetect
═══════════════════════════════════════════════════════════════
`;

    const blob = new Blob([content], { type: 'text/plain' });
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `CodeDetect_Report_${filename}_${Date.now()}.txt`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    window.URL.revokeObjectURL(url);
}

// Load analysis history
async function loadHistory() {
    try {
        const response = await fetch('/api/history');
        const data = await response.json();
        
        const historyCard = document.getElementById('historyCard');
        if (data && data.length > 0 && historyCard) {
            historyCard.style.display = 'block';
            const historyList = document.getElementById('historyList');
            
            historyList.innerHTML = data.map(item => `
                <div class="alert alert-secondary mb-2">
                    <div class="d-flex justify-content-between align-items-center">
                        <div>
                            <strong>${item.filename}</strong>
                            <br>
                            <small class="text-muted">${new Date(item.timestamp).toLocaleString()}</small>
                        </div>
                        <div class="text-end">
                            <span class="badge ${item.score >= 80 ? 'bg-success' : item.score >= 50 ? 'bg-warning' : 'bg-danger'}" style="font-size: 16px;">
                                ${item.score}
                            </span>
                            <br>
                            <small>Issues: ${item.total_issues}</small>
                        </div>
                    </div>
                </div>
            `).join('');
        }
    } catch (error) {
        console.error('Failed to load history:', error);
    }
}

// Initialize on page load
document.addEventListener('DOMContentLoaded', () => {
    loadHistory();
    
    const downloadBtn = document.getElementById('downloadBtn');
    if (downloadBtn) {
        downloadBtn.addEventListener('click', () => {
            if (currentAnalysisData) {
                downloadReport(currentAnalysisData);
            }
        });
    }
});