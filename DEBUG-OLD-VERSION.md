# Debugging Old Version Issue - Quick Checklist

## Run These Commands on Your EC2 Instance

SSH to your EC2 instance and run these commands one by one:

```bash
# 1. CHECK WHAT'S ACTUALLY RUNNING
echo "=== Checking Running Containers ==="
docker ps

# 2. CHECK DOCKER IMAGES
echo "=== Checking Docker Images ==="
docker images | grep codedetect

# 3. CHECK WHAT THE APP REPORTS
echo "=== Checking App Version ==="
curl localhost/api/info

# 4. CHECK DOCKER COMPOSE
echo "=== Checking Docker Compose ==="
cd /home/ec2-user/app
cat docker-compose.yml | grep image

# 5. CHECK ENVIRONMENT VARIABLES
echo "=== Checking Environment ==="
cat .env | grep DOCKER_TAG

# 6. CHECK NGINX IS RUNNING
echo "=== Checking Nginx ==="
docker logs codedetect-nginx --tail 20

# 7. CHECK APP LOGS
echo "=== Checking App Logs ==="
docker logs codedetect-app --tail 50
```

Copy the output and share with me!

---

## Common Issues & Quick Fixes

### Issue 1: Browser Cache
**Symptom:** Old version in browser, but `curl localhost/api/info` shows new version

**Fix:**
```bash
# Hard refresh browser:
# Chrome/Edge: Ctrl + Shift + R
# Firefox: Ctrl + F5
# Or open incognito/private window
```

---

### Issue 2: Multiple EC2 Instances (ALB Load Balancing)
**Symptom:** Sometimes old version, sometimes new version

**Fix:**
```bash
# Check how many instances are running
# On your LOCAL machine:
cd terraform
terraform output

# Check target group health - you might have 2 instances!
# One updated, one still old!
```

**Solution:** Update ALL instances:
```bash
# Get all instance IPs from terraform output
# SSH to EACH instance and update
ssh -i codedetect-key ec2-user@<INSTANCE-1-IP>
# Update...

ssh -i codedetect-key ec2-user@<INSTANCE-2-IP>
# Update...
```

---

### Issue 3: Docker Compose Using Old Image Name
**Symptom:** `docker pull` worked, but compose still uses old image

**Fix:**
```bash
cd /home/ec2-user/app

# Check what docker-compose.yml says
cat docker-compose.yml | grep "image:"

# If it says:
#   image: codedetect-app:latest  ← Wrong!
# Should be:
#   image: nyeinthunaing/codedetect:latest  ← Correct!

# Force recreate with correct image
docker-compose down
docker pull nyeinthunaing/codedetect:latest
docker tag nyeinthunaing/codedetect:latest codedetect-app:latest
docker-compose up -d --force-recreate
```

---

### Issue 4: Old Image Cached
**Symptom:** `docker images` shows old timestamp

**Fix:**
```bash
# Remove old images and pull fresh
docker-compose down
docker rmi nyeinthunaing/codedetect:latest
docker pull nyeinthunaing/codedetect:latest
docker tag nyeinthunaing/codedetect:latest codedetect-app:latest
docker-compose up -d
```

---

### Issue 5: Nginx Caching
**Symptom:** API shows new version, but web page shows old

**Fix:**
```bash
# Restart nginx
docker restart codedetect-nginx

# Or clear browser cache
```

---

### Issue 6: Static Files Not Updated
**Symptom:** Backend works, but frontend CSS/JS is old

**Fix:**
```bash
# Check if static files are mounted
cd /home/ec2-user/app
docker-compose down
docker-compose up -d --force-recreate
```

---

## Nuclear Option (If Nothing Else Works)

```bash
# FULL RESET - This will definitely work!

# 1. Stop everything
cd /home/ec2-user/app
docker-compose down

# 2. Remove ALL images
docker rmi $(docker images -q)

# 3. Remove ALL volumes (CAUTION: Deletes database!)
# docker volume prune -f  # UNCOMMENT ONLY IF SAFE

# 4. Pull fresh image
docker pull nyeinthunaing/codedetect:latest

# 5. Tag it
docker tag nyeinthunaing/codedetect:latest codedetect-app:latest

# 6. Start fresh
docker-compose up -d

# 7. Check logs
docker-compose logs -f
```

---

## Verification Steps

After updating, verify it worked:

```bash
# 1. Check container is running
docker ps | grep codedetect

# 2. Check image timestamp (should be recent)
docker images | grep codedetect

# 3. Check app version
curl localhost/api/info

# 4. Check via ALB (from your computer)
curl http://YOUR-ALB-DNS/api/info

# 5. Check in browser with hard refresh
# Ctrl + Shift + R
```

---

## What Version Are You Expecting?

Check Docker Hub to see what's actually "latest":
https://hub.docker.com/r/nyeinthunaing/codedetect/tags

Make sure "latest" tag actually has your new code!
