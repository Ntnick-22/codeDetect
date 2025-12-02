@echo off
REM ============================================================================
REM DEPLOY STAGING ENVIRONMENT - On-Demand Script (Windows)
REM ============================================================================
REM This script deploys a temporary staging environment for testing
REM Use before deploying to production to avoid crashes!
REM
REM Usage:
REM   deploy-staging.bat          # Deploy staging
REM   deploy-staging.bat destroy  # Destroy staging
REM
REM Cost: ~$0.50 per 3-hour testing session
REM ============================================================================

setlocal enabledelayedexpansion

REM Check if terraform directory exists
if not exist "terraform" (
    echo [ERROR] terraform/ directory not found!
    echo Please run this script from the project root directory
    exit /b 1
)

REM Navigate to terraform directory
cd terraform

REM ============================================================================
REM DESTROY MODE
REM ============================================================================
if "%1"=="destroy" goto DESTROY
if "%1"=="down" goto DESTROY
if "%1"=="stop" goto DESTROY
goto DEPLOY

:DESTROY
echo.
echo ========================================================
echo   DESTROYING STAGING ENVIRONMENT
echo ========================================================
echo.
echo This will destroy all staging resources to save costs
set /p confirm="Are you sure? (yes/no): "

if not "%confirm%"=="yes" (
    echo Cancelled.
    exit /b 0
)

echo [INFO] Switching to staging workspace...
terraform workspace select staging 2>nul
if errorlevel 1 (
    echo [WARNING] Staging workspace doesn't exist. Nothing to destroy.
    exit /b 0
)

echo [INFO] Destroying staging infrastructure...
terraform destroy -var-file="staging.tfvars" -auto-approve

echo [INFO] Switching back to default workspace...
terraform workspace select default

echo.
echo [SUCCESS] Staging environment destroyed!
echo [INFO] Cost saved: ~$0.15/hour
echo.
exit /b 0

:DEPLOY
REM ============================================================================
REM DEPLOY MODE
REM ============================================================================
echo.
echo ========================================================
echo   DEPLOYING STAGING ENVIRONMENT
echo ========================================================
echo.

REM Get current workspace
for /f "tokens=*" %%i in ('terraform workspace show') do set current_workspace=%%i
echo [INFO] Current workspace: %current_workspace%

REM Check if staging workspace exists
terraform workspace list | findstr /C:"staging" >nul
if errorlevel 1 (
    echo [INFO] Creating staging workspace...
    terraform workspace new staging
) else (
    echo [INFO] Switching to staging workspace...
    terraform workspace select staging
)

REM Verify we're in staging workspace
for /f "tokens=*" %%i in ('terraform workspace show') do set current_workspace=%%i
if not "%current_workspace%"=="staging" (
    echo [ERROR] Failed to switch to staging workspace!
    exit /b 1
)

echo [SUCCESS] Now in staging workspace

REM Check if staging.tfvars exists
if not exist "staging.tfvars" (
    echo [ERROR] staging.tfvars not found!
    echo Please create staging.tfvars file first
    exit /b 1
)

REM Initialize Terraform
echo [INFO] Initializing Terraform...
terraform init -upgrade >nul 2>&1

REM Show plan
echo.
echo ========================================================
echo   TERRAFORM PLAN
echo ========================================================
echo [INFO] Reviewing what will be created...
echo.

terraform plan -var-file="staging.tfvars"

echo.
echo [WARNING] This will create NEW resources (not modify production)
echo [INFO] Estimated cost: ~$0.50 for 3-hour session
echo.

set /p confirm="Deploy staging environment? (yes/no): "

if not "%confirm%"=="yes" (
    echo Deployment cancelled.
    terraform workspace select default
    exit /b 0
)

REM Deploy staging
echo.
echo ========================================================
echo   DEPLOYING STAGING
echo ========================================================
echo [INFO] This will take 5-10 minutes...
echo.

terraform apply -var-file="staging.tfvars" -auto-approve

REM Get staging URL
echo.
echo ========================================================
echo   STAGING DEPLOYED SUCCESSFULLY!
echo ========================================================
echo.

for /f "tokens=*" %%i in ('terraform output -raw load_balancer_url 2^>nul') do set STAGING_URL=%%i

echo [SUCCESS] Staging environment is ready!
echo.
echo Staging URL:
echo    %STAGING_URL%
echo.
echo Quick Commands:
echo    Test health:  curl %STAGING_URL%/api/health
echo    Open browser: start %STAGING_URL%
echo.
echo Usage Tips:
echo    1. Test your changes on staging URL
echo    2. If it works - Deploy to production
echo    3. If it breaks - Fix and redeploy to staging
echo    4. When done testing, run: deploy-staging.bat destroy
echo.
echo [WARNING] Don't forget to destroy staging when done to save costs!
echo.

REM Switch back to default workspace
echo [INFO] Switching back to default workspace...
terraform workspace select default

echo [SUCCESS] Done! Staging is ready for testing.
echo.

endlocal
