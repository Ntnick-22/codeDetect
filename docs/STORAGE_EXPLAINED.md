# Storage Architecture - S3 vs EFS vs RDS

## 🤔 The Confusion: Which Stores What?

You have 3 storage systems, but they do **different jobs**:

---

## 📦 1. S3 (Simple Storage Service)

### **What It Stores:**
- User uploaded Python code files (.py files)

### **The Flow:**
```
User uploads code.py
    ↓
Flask receives file
    ↓
Flask uploads to S3 bucket
    ↓
Code stored in: s3://codedetect-prod-uploads-2025/uploads/abc123.py
    ↓
Bandit & Radon read from S3 to analyze
    ↓
Results saved to database
```

### **Why S3?**
- ✅ Cheap ($0.023/GB/month)
- ✅ Unlimited storage
- ✅ Accessible from all EC2 instances
- ✅ Built for file storage
- ✅ Automatic backups and versioning

### **What's Actually Stored:**
```
s3://codedetect-prod-uploads-2025/
├── uploads/
│   ├── user123_code.py
│   ├── user456_script.py
│   ├── test789_app.py
│   └── ...
```

### **Your Code (app.py):**
```python
# Upload to S3
s3_client.upload_file(
    file_path,                          # Local temp file
    S3_BUCKET_NAME,                     # codedetect-prod-uploads-2025
    f'uploads/{unique_filename}'        # uploads/abc123.py
)
```

---

## 📂 2. EFS (Elastic File System)

### **What It Stores:**
- SQLite database file (`codedetect.db`)
- Shared between ALL instances

### **The Flow:**
```
User uploads code
    ↓
Flask analyzes code
    ↓
Results saved to SQLite
    ↓
SQLite file stored on: /mnt/efs/database/codedetect.db
    ↓
All instances read/write to SAME file
```

### **Why EFS?**
- ✅ Shared file system (multiple instances access same files)
- ✅ Both instances read/write to same database
- ✅ No sync needed - it's the same file
- ✅ Mounted like a regular folder

### **What's Actually Stored:**
```
/mnt/efs/
├── database/
│   └── codedetect.db  ← SQLite database (shared)
└── uploads/
    └── (optional backup location)
```

### **The Magic:**
```
Instance 1 (us-east-1a):           Instance 2 (us-east-1b):
/mnt/efs/database/codedetect.db    /mnt/efs/database/codedetect.db
         ↓                                     ↓
         └──────── SAME FILE ──────────────────┘
```

When Instance 1 writes to database, Instance 2 sees it immediately.

### **Your Code:**
```python
DATABASE_PATH = '/mnt/efs/database/codedetect.db'

# Both instances connect to same file
conn = sqlite3.connect(DATABASE_PATH)
```

---

## 🗄️ 3. RDS (Relational Database Service)

### **What It Stores:**
- **NOTHING** (in your current setup)

### **Why Not Used?**
You configured RDS but **disabled it** because:
- ❌ Costs more (~$15-30/month for smallest instance)
- ❌ SQLite on EFS works fine for this use case
- ❌ Not worth the cost for small project

### **Your Terraform:**
```hcl
enable_rds = false  # RDS is disabled
```

### **What WOULD Be Stored (if enabled):**
- Analysis results (same data as SQLite)
- User sessions
- Scan history
- All database tables

### **When You'd Need RDS:**
- Handling 100+ concurrent users
- Need advanced features (stored procedures, triggers)
- Need automatic backups and replication
- Have budget for it

---

## 🎯 COMPLETE DATA FLOW (Your Current Setup)

### **Scenario: User Uploads Python Code**

```
1. USER ACTION
   User uploads "my_code.py" via web interface
   ↓

2. FLASK RECEIVES FILE
   File temporarily saved to: /tmp/my_code.py
   ↓

3. S3 UPLOAD (Permanent File Storage)
   Flask uploads to S3:
   s3://codedetect-prod-uploads-2025/uploads/abc123_my_code.py
   ✅ File is now safe even if instance crashes
   ↓

4. ANALYSIS RUNS
   Bandit reads from S3 → Scans for security issues
   Radon reads from S3 → Calculates code quality
   ↓

5. DATABASE WRITE (EFS)
   Results saved to SQLite:
   /mnt/efs/database/codedetect.db

   INSERT INTO scans (filename, s3_path, security_score, quality_score)
   VALUES ('my_code.py', 's3://...abc123...', 85, 7.2);
   ↓

6. USER SEES RESULTS
   Flask reads from SQLite (on EFS)
   Displays dashboard with:
   - Security score: 85/100
   - Quality score: 7.2/10
   - Issues found
   ↓

7. USER VIEWS CODE (Optional)
   If user wants to see original code:
   Flask downloads from S3
   Displays in browser
```

---

## 📊 Storage Comparison Table

| Storage | What's Stored | Why | Cost | Shared? |
|---------|--------------|-----|------|---------|
| **S3** | Python code files (.py) | File storage, cheap, unlimited | ~$1/month | ✅ Yes |
| **EFS** | SQLite database (codedetect.db) | Shared filesystem between instances | ~$3/month | ✅ Yes |
| **RDS** | Nothing (disabled) | Would store DB data but too expensive | $0 (disabled) | ✅ Yes |

---

## 🔍 Why This Architecture?

### **Why Not Store Everything in S3?**
❌ S3 is not a filesystem (can't run SQLite on it)
❌ S3 has high latency for small reads/writes
✅ S3 is perfect for large files (uploaded code)

### **Why Not Store Code Files on EFS?**
✅ Could work, but S3 is cheaper for file storage
✅ S3 has better durability (99.999999999% vs 99.9%)
✅ S3 has built-in versioning

### **Why SQLite on EFS Instead of RDS?**
✅ Cheaper ($3/month EFS vs $15+/month RDS)
✅ Simpler (no separate DB server)
✅ Good enough for small traffic
❌ But limited to ~100 concurrent users

---

## 💡 Real-World Example

Let's say 2 users upload code at the same time:

```
TIME: 10:00 AM

User A uploads "app.py" → Instance 1 (eu-west-1a)
   ↓
   Instance 1 saves to S3: s3://.../user_a_app.py
   Instance 1 writes to DB: /mnt/efs/database/codedetect.db
   ✅ Record inserted: scan_id=1, user_a_app.py, score=90

User B uploads "test.py" → Instance 2 (eu-west-1b)
   ↓
   Instance 2 saves to S3: s3://.../user_b_test.py
   Instance 2 writes to DB: /mnt/efs/database/codedetect.db
   ✅ Record inserted: scan_id=2, user_b_test.py, score=75

TIME: 10:05 AM

User A refreshes page → Load Balancer sends to Instance 2
   ↓
   Instance 2 reads DB: /mnt/efs/database/codedetect.db
   ✅ Sees scan_id=1 (their old scan)
   ✅ Works! Because both instances share same DB file
```

**Without EFS:**
- User A's scan only on Instance 1
- User A refreshes → Goes to Instance 2
- ❌ Can't find their scan (not on Instance 2)
- 😡 User angry!

**With EFS:**
- User A's scan on shared EFS
- User A refreshes → Goes to Instance 2
- ✅ Instance 2 reads same EFS file
- 😊 User happy!

---

## 🎓 Summary for Presentation

**Simple Explanation:**

> "We use 3 storage systems:
>
> **S3** stores uploaded Python files - cheap, unlimited storage.
>
> **EFS** stores the database - shared between all instances so users see consistent data.
>
> **RDS** is disabled - would be the database, but SQLite on EFS is cheaper and good enough.
>
> When you upload code, the file goes to S3. We analyze it, save results to SQLite on EFS.
> Both instances read from the same database file, so no matter which instance serves you,
> you see your data."

**One-Line Version:**

> "S3 stores code files, EFS stores the shared database, RDS is disabled to save cost."

---

## 🤓 Technical Deep Dive (For Nerds)

### **Database Locking with SQLite on EFS:**

SQLite uses file locking. When Instance 1 writes:
```python
conn = sqlite3.connect('/mnt/efs/database/codedetect.db')
cursor.execute("INSERT INTO scans VALUES (...)")
conn.commit()  # ← Locks file, writes, unlocks
```

Instance 2 waiting to read:
```python
conn = sqlite3.connect('/mnt/efs/database/codedetect.db')
cursor.execute("SELECT * FROM scans")  # Waits for lock to release
```

EFS handles the locking via NFS protocol.

### **S3 Read Flow:**

```python
# Download from S3 to analyze
s3_client.download_file(
    'codedetect-prod-uploads-2025',
    'uploads/abc123.py',
    '/tmp/abc123.py'
)

# Analyze local copy
bandit_results = analyze_with_bandit('/tmp/abc123.py')

# Clean up
os.remove('/tmp/abc123.py')
```

---

Created by: Nyein Thu Naing
Project: CodeDetect
Date: December 2025
