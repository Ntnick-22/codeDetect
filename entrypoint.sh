#!/bin/bash
# Entrypoint script to fix deployment environment variables before starting Flask

# If DEPLOYMENT_TIME contains $( it means it wasn't executed, fix it
if [[ "$DEPLOYMENT_TIME" == *'$('* ]]; then
    export DEPLOYMENT_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "Fixed DEPLOYMENT_TIME: $DEPLOYMENT_TIME"
fi

# If GIT_COMMIT contains $( or ${ it means it wasn't executed, extract from DOCKER_TAG
if [[ "$GIT_COMMIT" == *'$('* ]] || [[ "$GIT_COMMIT" == *'${'* ]] || [[ "$GIT_COMMIT" == "unknown" ]]; then
    export GIT_COMMIT=$(echo "$DOCKER_TAG" | grep -o '[a-f0-9]\{7\}' | head -1 || echo "unknown")
    echo "Fixed GIT_COMMIT: $GIT_COMMIT"
fi

# If INSTANCE_ID contains $( it means it wasn't executed, try to get it
if [[ "$INSTANCE_ID" == *'$('* ]]; then
    # Try to get from EC2 metadata (works on EC2)
    if command -v ec2-metadata &> /dev/null; then
        export INSTANCE_ID=$(ec2-metadata --instance-id 2>/dev/null | cut -d " " -f 2 || echo "local")
    else
        # Try EC2 metadata API directly
        export INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null || echo "local")
    fi
    echo "Fixed INSTANCE_ID: $INSTANCE_ID"
fi

# Start the Flask application
exec python -m backend.app
