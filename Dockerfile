# Multi-stage build for smaller image size
FROM python:3.12-slim as builder

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first (for caching)
COPY backend/requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir --user -r requirements.txt

# Final stage
FROM python:3.12-slim

# Set working directory
WORKDIR /app

# Install runtime dependencies only
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install AWS CLI v2 (for fetching secrets from Parameter Store)
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf aws awscliv2.zip

# Copy Python packages from builder
COPY --from=builder /root/.local /root/.local

# Make sure scripts in .local are usable
ENV PATH=/root/.local/bin:$PATH

# Copy application code
COPY backend/ ./backend/
COPY frontend/ ./frontend/

# Create necessary directories with proper permissions
RUN mkdir -p /app/uploads && \
    mkdir -p /app/instance && \
    chmod -R 777 /app/uploads && \
    chmod -R 777 /app/instance

# Copy and set entrypoint script permissions
COPY backend/entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Set environment variables
ENV FLASK_APP=backend/app.py
ENV PYTHONUNBUFFERED=1
ENV DATABASE_URL=sqlite:////app/instance/codedetect.db
ENV AWS_REGION=eu-west-1
ENV PROJECT_NAME=codedetect
ENV ENVIRONMENT=prod

# Expose port
EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5000/api/health || exit 1

# Use entrypoint script to fetch secrets and start app
ENTRYPOINT ["/app/entrypoint.sh"]