# CodeDetect Infrastructure Overview
**Production-Grade DevOps & Cloud Architecture**

---

## 🏗️ Complete AWS Infrastructure

### **1. Compute Layer**

#### **EC2 Auto Scaling Groups (Blue-Green Deployment)**
- **Instance Type**: t3.small
- **Active Instances**: 1 instance (only one environment active at a time)
- **Inactive Instances**: 0 instances (scaled down)
- **OS**: Amazon Linux 2
- **Purpose**: Runs Docker containers with Flask application
- **Blue-Green Strategy**:
  - Two separate Auto Scaling Groups (Blue and Green)
  - Only ONE environment active at any time
  - Active environment runs 1 instance (can scale to 2)
  - Inactive environment scaled to 0 instances
  - Zero-downtime deployments by switching between environments
- **Features**:
  - Auto Scaling based on CPU/memory
  - Health checks via Load Balancer
  - Automatic instance replacement if unhealthy

**Cost**: $0/month (Free Tier 750 hours) → $15/month after (per active instance)

---

### **2. Load Balancing & High Availability**

#### **Application Load Balancer (ALB)**
- **Type**: Application Load Balancer
- **Purpose**: Distributes traffic across EC2 instances
- **Features**:
  - Health checks on `/api/health` endpoint
  - Automatic failover
  - SSL/TLS termination ready
  - Sticky sessions support

**Cost**: ~$16/month

#### **Target Groups**
- Blue environment target group
- Green environment target group
- Zero-downtime deployment switching

---

### **3. Database Layer**

#### **RDS PostgreSQL**
- **Engine**: PostgreSQL 15.10
- **Instance**: db.t3.micro
- **Storage**: 20 GB gp2 SSD
- **Deployment**: Single-AZ (cost optimized)
- **Features**:
  - Automated daily backups (7-day retention)
  - Automated security patches
  - Performance Insights enabled
  - Encrypted at rest
  - Multi-AZ ready (can upgrade)

**Cost**: $0/month (Free Tier 750 hours) → $19/month after

**Connection**: All EC2 instances connect to single RDS instance (shared database)

---

### **4. Shared Storage**

#### **Elastic File System (EFS)**
- **Purpose**: Shared file storage across EC2 instances
- **Performance Mode**: General Purpose
- **Throughput Mode**: Bursting
- **Features**:
  - Stores uploaded Python files
  - Accessible from all EC2 instances
  - Automatic backups enabled
  - Lifecycle policy (move to IA after 30 days)
  - Encrypted at rest

**Cost**: ~$0.30/GB/month (~$2/month for typical usage)

**Mount Point**: `/mnt/efs/uploads`

---

### **5. Object Storage**

#### **S3 Buckets**
1. **codedetect-nick-uploads-12345**
   - Stores uploaded files (long-term backup)
   - Versioning enabled
   - Lifecycle policies
   - Server-side encryption

2. **codedetect-terraform-state-bucket-12345**
   - Stores Terraform state files
   - Version controlled
   - Prevents concurrent modifications

**Cost**: $0.023/GB/month + requests (practically free for low usage)

---

### **6. Networking**

#### **VPC (Virtual Private Cloud)**
- **CIDR**: 10.0.0.0/16
- **Subnets**:
  - Public Subnet 1 (eu-west-1a): 10.0.1.0/24
  - Public Subnet 2 (eu-west-1b): 10.0.2.0/24
  - Private Subnet 1 (eu-west-1a): 10.0.11.0/24
  - Private Subnet 2 (eu-west-1b): 10.0.12.0/24

#### **Internet Gateway**
- Allows public internet access
- Attached to VPC

#### **Security Groups**
1. **ALB Security Group**
   - Inbound: HTTP (80), HTTPS (443) from 0.0.0.0/0
   - Outbound: All traffic

2. **EC2 Security Group**
   - Inbound: HTTP (80) from ALB only
   - Inbound: SSH (22) from your IP
   - Outbound: All traffic

3. **RDS Security Group**
   - Inbound: PostgreSQL (5432) from EC2 only
   - Outbound: None

4. **EFS Security Group**
   - Inbound: NFS (2049) from EC2 only
   - Outbound: None

---

### **7. DNS & Domain**

#### **Route 53**
- **Domain**: codedetect.nt-nick.link
- **Record Type**: ALIAS
- **Points To**: Application Load Balancer DNS
- **Features**:
  - Automatic DNS failover
  - Low latency routing

**Cost**: ~$0.50/month per hosted zone

---

### **8. Secrets Management**

#### **AWS Systems Manager Parameter Store**
- **SECRET_KEY**: Flask secret key (encrypted)
- **DB_PASSWORD**: RDS password (encrypted)
- **Purpose**: Secure credential storage
- **Access**: EC2 instances fetch at startup

**Cost**: Free (under 10,000 parameters)

---

### **9. Monitoring & Alerting**

#### **CloudWatch**
1. **Metrics**:
   - EC2 CPU utilization
   - EC2 memory usage
   - RDS CPU, storage, connections
   - ALB request count, latency
   - EFS throughput

2. **Alarms**:
   - High CPU (> 80%)
   - High memory (> 80%)
   - RDS storage space
   - ALB unhealthy targets
   - Billing alerts ($10, $20, $50)

3. **Dashboards**:
   - Application performance
   - Infrastructure health
   - Cost tracking

#### **SNS (Simple Notification Service)**
- **Topic**: codedetect-prod-alerts
- **Subscribers**: Your email
- **Notifications**:
  - CloudWatch alarms
  - User bug reports
  - Deployment status

**Cost**: $0 (Free Tier: 1000 notifications/month)

---

### **10. IAM Roles & Permissions**

#### **EC2 Instance Role**
- S3 read/write access
- Parameter Store read access
- CloudWatch metrics write
- EFS mount access

#### **GitHub Actions User**
- EC2 management
- RDS management
- Load Balancer management
- Parameter Store access
- SNS publish

**Security**: No hardcoded credentials, all IAM-based

---

## 🚀 CI/CD Pipeline

### **GitHub Actions Workflow**

**Triggers**:
- Push to `main` branch
- Manual workflow dispatch

**Steps**:
1. **Build Phase**
   - Checkout code
   - Build Docker image
   - Tag with git commit SHA
   - Push to Docker Hub

2. **Deploy Phase**
   - Pull latest Docker image on EC2
   - Update docker-compose.yml
   - Restart containers
   - Health check verification
   - Blue-Green traffic switching

3. **Verification**
   - ALB health checks
   - Application health endpoint
   - Automated rollback if failed

**Deployment Time**: ~3-5 minutes
**Downtime**: Zero (blue-green deployment)

---

## 🐳 Containerization

### **Docker**
- **Base Image**: python:3.12-slim
- **Application**: Flask app
- **Port**: 5000 (internal) → 80 (ALB)

### **Docker Compose**
- Manages application container
- Environment variable injection
- Volume mounts (EFS)
- Health checks

**Registry**: Docker Hub (nyeinthunaing/codedetect)

---

## 📊 Infrastructure as Code

### **Terraform**
**Files**:
- `main.tf` - Provider configuration
- `vpc.tf` - Network infrastructure
- `ec2.tf` - Compute resources
- `loadbalancer.tf` - ALB + Auto Scaling
- `rds.tf` - Database
- `efs.tf` - Shared storage
- `s3.tf` - Object storage
- `security_groups.tf` - Firewall rules
- `route53.tf` - DNS
- `secrets.tf` - Parameter Store
- `monitoring.tf` - CloudWatch + SNS
- `ssl.tf` - SSL certificate (ACM)
- `variables.tf` - Input variables
- `outputs.tf` - Output values

**State Management**:
- Stored in S3
- Version controlled
- Team collaboration ready

---

## 💰 Cost Breakdown

### **Monthly Costs (First 12 Months - Free Tier)**
| Service | Free Tier | After Free Tier |
|---------|-----------|----------------|
| EC2 (1x t3.small) | $0 | $15/month |
| RDS (db.t3.micro) | $0 | $19/month |
| ALB | $16/month | $16/month |
| EFS | ~$2/month | ~$2/month |
| S3 | ~$1/month | ~$1/month |
| Route 53 | $0.50/month | $0.50/month |
| CloudWatch | $0 | $3/month |
| **Total** | **~$20/month** | **~$57/month** |

### **Scaling Costs (If Needed)**
- **2 EC2 instances**: +$15/month
- **Multi-AZ RDS**: +$19/month
- **Reserved Instances**: Save 30-50%

---

## 🔐 Security Features

### **Network Security**
- ✅ VPC isolation
- ✅ Private subnets for database
- ✅ Security groups (least privilege)
- ✅ NACLs configured

### **Data Security**
- ✅ RDS encryption at rest
- ✅ EBS encryption
- ✅ EFS encryption
- ✅ S3 server-side encryption
- ✅ Secrets in Parameter Store (encrypted)

### **Application Security**
- ✅ No hardcoded credentials
- ✅ IAM roles for service access
- ✅ SSL/TLS ready (ACM certificate configured)
- ✅ Security group egress restrictions

### **Compliance**
- ✅ CloudTrail enabled (audit logging)
- ✅ Automated backups
- ✅ Version control for all code

---

## 📈 Scalability

### **Current Capacity**
- 1 EC2 instance (t3.small)
- Handles: ~100-500 concurrent users
- RPS: ~50-100 requests/second

### **Scaling Options**

#### **Horizontal Scaling (Add More Instances)**
```hcl
# In terraform/loadbalancer.tf
desired_capacity = 2  # Change from 1 to 2
max_size = 4          # Can auto-scale to 4
```

#### **Vertical Scaling (Bigger Instances)**
```hcl
# In terraform/variables.tf
instance_type = "t3.medium"  # 2 vCPU, 4GB RAM
```

#### **Database Scaling**
- Read replicas for heavy read workloads
- Multi-AZ for high availability
- Upgrade to larger instance class

---

## 🎯 High Availability Features

### **Current Setup**
- ✅ Load Balancer distributes traffic
- ✅ Auto Scaling replaces failed instances
- ✅ RDS automated backups
- ✅ Multi-AZ subnet placement
- ✅ EFS for shared storage

### **Uptime**
- **Current**: ~99.5% (single instance)
- **With 2 instances**: ~99.9%
- **With Multi-AZ RDS**: ~99.95%

### **Disaster Recovery**
- RDS: 7-day backup retention
- S3: Versioning enabled
- Terraform: Infrastructure recreatable
- Point-in-time recovery available

---

## 🛠️ DevOps Best Practices Implemented

### **✅ Infrastructure as Code**
- All infrastructure in Terraform
- Version controlled in Git
- Reproducible across environments

### **✅ CI/CD Automation**
- Automated testing
- Automated builds
- Automated deployments
- Zero-downtime releases

### **✅ Containerization**
- Docker for consistency
- Environment parity (dev/prod)
- Easy rollbacks

### **✅ Monitoring & Observability**
- CloudWatch metrics
- Application logs
- Performance tracking
- Automated alerts

### **✅ Security**
- Least privilege access
- Encrypted data
- Secrets management
- Network isolation

### **✅ Cost Optimization**
- Free tier maximization
- Right-sized instances
- Lifecycle policies
- Billing alerts

---

## 🎓 Skills Demonstrated

### **Cloud (AWS)**
- ✅ EC2, Auto Scaling
- ✅ RDS, EFS, S3
- ✅ VPC, Security Groups
- ✅ ALB, Route 53
- ✅ CloudWatch, SNS
- ✅ IAM, Parameter Store

### **DevOps**
- ✅ CI/CD (GitHub Actions)
- ✅ Infrastructure as Code (Terraform)
- ✅ Containerization (Docker)
- ✅ Blue-Green Deployment
- ✅ Automated Testing
- ✅ Monitoring & Alerting

### **Networking**
- ✅ Load Balancing
- ✅ DNS Management
- ✅ VPC Design
- ✅ Security Groups

### **Database**
- ✅ PostgreSQL (RDS)
- ✅ Database Migration
- ✅ Backup Strategies
- ✅ Performance Optimization

---

## 📊 Architecture Diagram

```
                    Internet
                       ↓
                  Route 53 DNS
               (codedetect.nt-nick.link)
                       ↓
            Application Load Balancer
                  (Port 80/443)
                       ↓
           ┌───────────┴───────────┐
           ↓                       ↓
      EC2 Instance 1          EC2 Instance 2
    (Blue Environment)      (Green Environment)
    [Docker Container]      [Docker Container]
           ↓                       ↓
           └───────────┬───────────┘
                       ↓
              ┌────────┴────────┐
              ↓                 ↓
         RDS PostgreSQL      EFS Storage
      (Shared Database)    (Shared Files)
              ↓
         S3 Backups
```

---

## 🚀 Future Enhancements

### **Performance**
- [ ] Add Redis caching
- [ ] CDN (CloudFront)
- [ ] Database read replicas

### **Scalability**
- [ ] Kubernetes (EKS)
- [ ] Serverless (Lambda)
- [ ] Global deployment (multi-region)

### **Security**
- [ ] WAF (Web Application Firewall)
- [ ] AWS Shield (DDoS protection)
- [ ] GuardDuty (threat detection)

### **Monitoring**
- [ ] Distributed tracing (X-Ray)
- [ ] Log aggregation (ELK stack)
- [ ] Performance APM

---

## 📝 Quick Reference

### **Important URLs**
- Application: http://codedetect.nt-nick.link
- GitHub: https://github.com/Ntnick-22/codeDetect
- AWS Region: eu-west-1 (Ireland)

### **Key Commands**
```bash
# Terraform
terraform plan
terraform apply
terraform destroy

# Docker
docker-compose up -d
docker logs codedetect-app
docker ps

# AWS CLI
aws ec2 describe-instances
aws rds describe-db-instances
aws s3 ls
```

### **SSH Access**
```bash
ssh -i terraform/codedetect-key ec2-user@<EC2-IP>
```

---

**Generated**: November 27, 2025
**Status**: Production-Ready
**Maintainer**: Nyein Thu Naing
