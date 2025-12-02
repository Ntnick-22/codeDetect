 Quick Reference:

  # Build staging image
  docker build -t nyeinthunaing/codedetect:staging-latest .

  # Push staging image
  docker push nyeinthunaing/codedetect:staging-latest

  # Pull on staging server
  docker pull nyeinthunaing/codedetect:staging-latest

  # Tag for docker-compose
  docker tag nyeinthunaing/codedetect:staging-latest codedetect-app:latest

  # Restart
  docker-compose down && docker-compose up -d
