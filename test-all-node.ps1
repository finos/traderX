# Test all Node.js services - simulates CI workflow behavior
# Run this from the root directory: .\test-all-node.ps1

$ErrorActionPreference = "Continue"
$rootDir = $PSScriptRoot

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Testing All Node.js Services" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Test 1: reference-data
Write-Host "[1/4] Testing reference-data..." -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray
Set-Location "$rootDir\reference-data"
if (Test-Path "package-lock.json") {
    Write-Host "  package-lock.json exists - would use npm ci" -ForegroundColor Green
} else {
    Write-Host "  package-lock.json missing - will use npm install" -ForegroundColor Green
}
npm install
if ($LASTEXITCODE -eq 0) {
    Write-Host "  [OK] npm install succeeded" -ForegroundColor Green
    npm test -- --coverage=false
    npm run build
} else {
    Write-Host "  [FAIL] npm install failed" -ForegroundColor Red
}
Write-Host ""

# Test 2: trade-feed
Write-Host "[2/4] Testing trade-feed..." -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray
Set-Location "$rootDir\trade-feed"
if (Test-Path "package-lock.json") {
    Write-Host "  package-lock.json exists - would use npm ci" -ForegroundColor Green
} else {
    Write-Host "  package-lock.json missing - will use npm install" -ForegroundColor Green
}
npm install
if ($LASTEXITCODE -eq 0) {
    Write-Host "  [OK] npm install succeeded" -ForegroundColor Green
    npm run build
    Write-Host "  [SKIP] No tests configured for trade-feed" -ForegroundColor Yellow
} else {
    Write-Host "  [FAIL] npm install failed" -ForegroundColor Red
}
Write-Host ""

# Test 3: web-front-end/angular
Write-Host "[3/4] Testing web-front-end/angular..." -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray
Set-Location "$rootDir\web-front-end\angular"
if (Test-Path "package-lock.json") {
    Write-Host "  package-lock.json exists - would use npm ci" -ForegroundColor Green
} else {
    Write-Host "  package-lock.json missing - will use npm install" -ForegroundColor Green
}
npm install
if ($LASTEXITCODE -eq 0) {
    Write-Host "  [OK] npm install succeeded" -ForegroundColor Green
    npm run build
    npm run test:ci
} else {
    Write-Host "  [FAIL] npm install failed" -ForegroundColor Red
}
Write-Host ""

# Test 4: web-front-end/react
Write-Host "[4/4] Testing web-front-end/react..." -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray
Set-Location "$rootDir\web-front-end\react"
if (Test-Path "package-lock.json") {
    Write-Host "  package-lock.json exists - would use npm ci" -ForegroundColor Green
} else {
    Write-Host "  package-lock.json missing - will use npm install" -ForegroundColor Green
}
npm install
if ($LASTEXITCODE -eq 0) {
    Write-Host "  [OK] npm install succeeded" -ForegroundColor Green
    npm run build
    npm test -- --coverage=false
} else {
    Write-Host "  [FAIL] npm install failed" -ForegroundColor Red
}
Write-Host ""

# Return to root
Set-Location $rootDir

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Testing Complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "If npm install succeeded for all services, the fix is working!" -ForegroundColor Green
Write-Host "You can now commit and push the workflow changes." -ForegroundColor Cyan

