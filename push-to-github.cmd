@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "REPO_DIR=%~dp0"
set "REMOTE_URL=git@github.com:JetComX/QYQUpx.git"
set "BRANCH=main"
set "GIT_USER_NAME=yqynb666"
set "GIT_USER_EMAIL=3761666075@qq.com"
set "DEPLOY_KEY=%REPO_DIR%.ssh\qyqupx_deploy"

pushd "%REPO_DIR%" >nul
if errorlevel 1 (
    echo [ERROR] Cannot enter project directory: %REPO_DIR%
    exit /b 1
)

where git >nul 2>&1
if errorlevel 1 (
    echo [ERROR] git was not found in PATH.
    goto :failed
)
if not exist "%DEPLOY_KEY%" (
    echo [ERROR] Deploy key not found. Run setup-deploy-key.cmd first.
    goto :failed
)

set "GIT_SSH_COMMAND=ssh -i "%DEPLOY_KEY%" -o IdentitiesOnly=yes"

if not exist ".git" (
    echo [1/6] Initializing Git repository...
    git init
    if errorlevel 1 goto :failed
)

echo [2/6] Configuring branch, author, and remote...
for /f "delims=" %%B in ('git branch --show-current') do set "CURRENT_BRANCH=%%B"
if /i not "!CURRENT_BRANCH!"=="%BRANCH%" (
    git branch -M "%BRANCH%"
    if errorlevel 1 goto :failed
)
git config user.name "%GIT_USER_NAME%"
git config user.email "%GIT_USER_EMAIL%"
if errorlevel 1 goto :failed

git remote get-url origin >nul 2>&1
if errorlevel 1 (
    git remote add origin "%REMOTE_URL%"
) else (
    git remote set-url origin "%REMOTE_URL%"
)
if errorlevel 1 goto :failed

echo [3/6] Staging project files and local vendor sources...
git add -A
if errorlevel 1 goto :failed
git add -f vendor/bzip2 vendor/doctest vendor/lzma-sdk vendor/ucl vendor/zlib vendor/zstd
if errorlevel 1 goto :failed

git diff --cached --quiet
if errorlevel 1 (
    for /f "delims=" %%T in ('powershell.exe -NoProfile -Command "Get-Date -Format yyyyMMddHHmmss"') do set "STAMP=%%T"
    echo [4/6] Creating commit QYQUpx_!STAMP!...
    git commit -m "Update QYQUpx !STAMP!"
    if errorlevel 1 goto :failed
) else (
    echo [4/6] No new changes to commit.
)

echo [5/6] Fetching remote branch...
git fetch origin "%BRANCH%" >nul 2>&1
git show-ref --verify --quiet "refs/remotes/origin/%BRANCH%"
if not errorlevel 1 (
    echo [INFO] Merging origin/%BRANCH%...
    git merge "origin/%BRANCH%" --allow-unrelated-histories --no-edit
    if errorlevel 1 (
        echo [ERROR] Merge conflict. Resolve conflicts, commit, then rerun this script.
        goto :failed
    )
)

echo [6/6] Pushing to GitHub...
git push --set-upstream origin "%BRANCH%"
if errorlevel 1 goto :failed

echo Done: %REMOTE_URL%
popd
exit /b 0

:failed
echo [ERROR] Push script failed. Exit code: %ERRORLEVEL%
popd
exit /b 1
