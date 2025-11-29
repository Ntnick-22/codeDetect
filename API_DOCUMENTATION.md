# CodeDetect API Documentation

## Overview

CodeDetect uses a **RESTful API** architecture where the frontend (HTML/JavaScript) communicates with the backend (Flask/Python) through HTTP requests.

---

## How Your APIs Work

```
┌─────────────────────────────────────────────────────────────┐
│                    User's Browser                           │
│  ┌────────────────────────────────────────────────┐         │
│  │  Frontend (HTML/JavaScript)                    │         │
│  │  - index.html                                  │         │
│  │  - Sends AJAX/fetch requests                   │         │
│  └────────────┬───────────────────────────────────┘         │
└───────────────┼─────────────────────────────────────────────┘
                │
                │ HTTP Request
                │ POST /api/analyze
                │ (with uploaded file)
                ↓
┌─────────────────────────────────────────────────────────────┐
│                    Flask Backend                            │
│  ┌────────────────────────────────────────────────┐         │
│  │  app.py - API Endpoints                        │         │
│  │  - @app.route('/api/analyze')                  │         │
│  │  - Receives file                               │         │
│  │  - Runs Pylint + Bandit                        │         │
│  │  - Returns JSON response                       │         │
│  └────────────┬───────────────────────────────────┘         │
└───────────────┼─────────────────────────────────────────────┘
                │
                │ JSON Response
                │ {"score": 85, "issues": [...]}
                ↓
┌─────────────────────────────────────────────────────────────┐
│                    User's Browser                           │
│  JavaScript receives JSON and displays results              │
└─────────────────────────────────────────────────────────────┘
```

---

## Your Current APIs ✅

### 1. **POST /api/analyze** - Main Analysis Endpoint
**Purpose:** Upload Python file for code quality analysis

**Request:**
```http
POST /api/analyze HTTP/1.1
Content-Type: multipart/form-data

file: [Python file binary data]
```

**Response:**
```json
{
  "score": 85,
  "total_issues": 12,
  "security_issues": 2,
  "complexity_issues": 3,
  "issues": [
    {
      "type": "security",
      "severity": "HIGH",
      "message": "SQL injection vulnerability detected",
      "line": 42,
      "code": "cursor.execute(f\"SELECT * FROM users WHERE id={user_id}\")"
    },
    {
      "type": "complexity",
      "severity": "MEDIUM",
      "message": "Cyclomatic complexity too high (15)",
      "line": 78,
      "function": "process_data"
    }
  ],
  "analysis_time": "2.3s"
}
```

**How Frontend Uses It:**
```javascript
// In your frontend JavaScript
const formData = new FormData();
formData.append('file', fileInput.files[0]);

fetch('/api/analyze', {
    method: 'POST',
    body: formData
})
.then(response => response.json())
.then(data => {
    // Display score, issues, charts
    document.getElementById('score').textContent = data.score;
    displayIssues(data.issues);
});
```

---

### 2. **GET /api/health** - Health Check Endpoint
**Purpose:** Check if application is running (used by Load Balancer)

**Request:**
```http
GET /api/health HTTP/1.1
```

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2025-11-27T20:30:00Z",
  "database": "connected"
}
```

**Who Uses It:**
- AWS Load Balancer (checks every 30 seconds)
- Monitoring systems
- DevOps health checks

---

### 3. **GET /api/info** - Application Info Endpoint
**Purpose:** Show deployment information

**Request:**
```http
GET /api/info HTTP/1.1
```

**Response:**
```json
{
  "app_name": "CodeDetect",
  "version": "1.0",
  "docker_tag": "v20251127-9c6ed5f",
  "deployment_time": "2025-11-27T19:45:00Z",
  "deployed_by": "github-actions",
  "environment": "production",
  "instance_id": "i-0123456789abcdef",
  "git_commit": "9c6ed5f"
}
```

**How to Use:**
```javascript
// Show deployment info in footer
fetch('/api/info')
.then(response => response.json())
.then(data => {
    document.getElementById('version').textContent = data.version;
    document.getElementById('deployed').textContent = data.deployment_time;
});
```

---

### 4. **GET /api/stats** - Statistics Endpoint
**Purpose:** Get aggregate statistics for dashboard

**Request:**
```http
GET /api/stats HTTP/1.1
```

**Response:**
```json
{
  "total_analyses": 1247,
  "avg_score": 78.5,
  "total_security_issues": 342,
  "total_complexity_issues": 589,
  "analyses_today": 45,
  "top_issues": [
    {
      "type": "unused-variable",
      "count": 234
    },
    {
      "type": "complexity-too-high",
      "count": 156
    }
  ]
}
```

---

### 5. **POST /api/report** - Bug Report Endpoint
**Purpose:** Submit user feedback/bug reports

**Request:**
```http
POST /api/report HTTP/1.1
Content-Type: application/json

{
  "email": "user@example.com",
  "message": "Found a bug when uploading large files",
  "severity": "medium"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Report submitted successfully",
  "report_id": "abc123"
}
```

**Backend Integration:**
- Sends report to AWS SNS topic
- You receive email notification
- Stored for tracking

---

### 6. **GET /api/history** - Analysis History (Deprecated)
**Purpose:** Previously showed user's analysis history

**Status:** Removed for privacy (no user tracking)

---

## API Architecture Patterns You're Using ✅

### 1. **RESTful API**
- Uses HTTP methods (GET, POST)
- Resource-based URLs (/api/analyze, /api/stats)
- Returns JSON responses
- Stateless communication

### 2. **AJAX/Fetch API**
- Frontend makes asynchronous requests
- No page reload needed
- Modern single-page application feel

### 3. **JSON Data Format**
- Structured data exchange
- Easy to parse in JavaScript
- Human-readable

### 4. **Separation of Concerns**
```
Frontend (HTML/CSS/JS)
  ↕ API (HTTP/JSON)
Backend (Flask/Python)
  ↕ Database (PostgreSQL)
Storage (AWS S3)
```

---

## How APIs Make Your App Work

**Example: User Uploads a File**

1. **Frontend (JavaScript):**
   ```javascript
   // User clicks "Analyze" button
   const file = document.getElementById('fileInput').files[0];

   // JavaScript sends file to API
   fetch('/api/analyze', {
       method: 'POST',
       body: formData
   })
   ```

2. **API Route (Flask):**
   ```python
   @app.route('/api/analyze', methods=['POST'])
   def analyze_code():
       file = request.files['file']

       # Save file
       filepath = save_file(file)

       # Run analysis
       results = run_pylint(filepath)

       # Return JSON
       return jsonify({
           'score': results.score,
           'issues': results.issues
       })
   ```

3. **Frontend Receives Response:**
   ```javascript
   .then(response => response.json())
   .then(data => {
       // Update UI with results
       showScore(data.score);
       showIssues(data.issues);
   })
   ```

---

## Why APIs Are Important

### Without API (Old Way):
```
User submits form
  ↓
Page refreshes (full reload)
  ↓
Server generates new HTML
  ↓
Entire page sent to browser
  ↓
Slow, clunky experience
```

### With API (Your Way):
```
User submits form
  ↓
JavaScript sends data to API
  ↓
Server processes, returns JSON
  ↓
JavaScript updates page (no reload)
  ↓
Fast, modern experience
```

---

## API Best Practices You're Following ✅

1. ✅ **Versioned URLs** (`/api/...` namespace)
2. ✅ **RESTful naming** (resources, not actions)
3. ✅ **JSON responses** (standard format)
4. ✅ **HTTP methods** (GET, POST correctly used)
5. ✅ **Error handling** (try/catch blocks)
6. ✅ **Health checks** (for monitoring)

---

## What You Could Add (For Presentation)

### 1. **API Documentation UI** (Swagger)
Interactive documentation that shows all your APIs

**Add to backend/app.py:**
```python
from flask_swagger_ui import get_swaggerui_blueprint

SWAGGER_URL = '/api/docs'
API_URL = '/static/swagger.json'

swaggerui_blueprint = get_swaggerui_blueprint(SWAGGER_URL, API_URL)
app.register_blueprint(swaggerui_blueprint)
```

**Visit:** `http://your-app.com/api/docs`

**Shows:** Interactive API testing interface

---

### 2. **API Rate Limiting**
Prevent abuse by limiting requests

```python
from flask_limiter import Limiter

limiter = Limiter(app, key_func=get_remote_address)

@app.route('/api/analyze', methods=['POST'])
@limiter.limit("10 per minute")  # Max 10 uploads/minute
def analyze_code():
    ...
```

---

### 3. **API Authentication**
Protect APIs with tokens

```python
@app.route('/api/analyze', methods=['POST'])
@require_api_key  # Only authenticated users
def analyze_code():
    ...
```

---

## Common API Interview Questions (Be Prepared!)

**Q: What is a REST API?**
A: "REST (Representational State Transfer) is an architectural style where clients communicate with servers using HTTP requests. My app uses RESTful APIs - for example, POST /api/analyze to upload files, GET /api/stats to retrieve statistics."

**Q: What's the difference between GET and POST?**
A: "GET retrieves data (like /api/stats), POST sends data to server (like /api/analyze for file uploads). GET is idempotent (safe to repeat), POST can change server state."

**Q: Why use JSON instead of HTML?**
A: "JSON is lightweight, structured, and language-independent. It separates data from presentation - the API returns data, the frontend decides how to display it. This allows mobile apps, other services to use the same API."

**Q: How do you handle API errors?**
A: "I use try-catch blocks and return appropriate HTTP status codes: 200 for success, 400 for bad requests, 500 for server errors. The response includes error messages in JSON format."

---

## For Your Presentation 🎤

**When explaining APIs, say:**

"CodeDetect uses a modern RESTful API architecture. The frontend communicates with the backend through HTTP APIs that return JSON data. For example:

1. User uploads a Python file
2. Frontend sends POST request to `/api/analyze`
3. Backend runs Pylint and Bandit
4. Returns JSON with score and issues
5. Frontend displays results dynamically

This separation allows the same backend to serve web browsers, mobile apps, or other services - it's a scalable, industry-standard approach."

**Show this diagram:**
```
Browser ──(HTTP/JSON)──> Flask API ──> Analysis Engine
   ↑                        │              │
   │                        ↓              ↓
   └───────(JSON)───── PostgreSQL      AWS S3
```

---

## Summary

✅ **Yes, you ARE using APIs!** You have 6 API endpoints
✅ **You're using industry-standard RESTful patterns**
✅ **Your architecture separates frontend/backend (good practice)**
✅ **JSON for data exchange (modern approach)**

**Your API architecture is solid!** Just be able to explain it clearly in your presentation.

---

Generated: November 27, 2025
