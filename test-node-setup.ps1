# Test script to verify Node.js setup fixes
# This simulates what the CI workflow will do

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Testing Node.js Setup for CI Workflows" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

$services = @(
    "reference-data",
    "trade-feed",
    "web-front-end/angular",
    "web-front-end/react"
)

foreach ($service in $services) {
    Write-Host "----------------------------------------" -ForegroundColor Yellow
    Write-Host "Testing: $service" -ForegroundColor Yellow
    Write-Host "----------------------------------------" -ForegroundColor Yellow
    
    $servicePath = Join-Path $PSScriptRoot $service
    
    if (-not (Test-Path $servicePath)) {
        Write-Host "  ERROR: Service directory not found: $servicePath" -ForegroundColor Red
        continue
    }
    
    # Check for package.json
    $packageJson = Join-Path $servicePath "package.json"
    if (-not (Test-Path $packageJson)) {
        Write-Host "  ERROR: package.json not found" -ForegroundColor Red
        continue
    }
    
    # Check for package-lock.json
    $packageLock = Join-Path $servicePath "package-lock.json"
    if (Test-Path $packageLock) {
        Write-Host "  ✓ package-lock.json exists - will use 'npm ci'" -ForegroundColor Green
    } else {
        Write-Host "  ✓ package-lock.json NOT found - will use 'npm install'" -ForegroundColor Green
    }
    
    # Test npm install (dry run or actual install)
    Write-Host "  Testing dependency installation..." -ForegroundColor Cyan
    Push-Location $servicePath
    try {
        # Just check if npm install would work (don't actually install to save time)
        Write-Host "  Running: npm install --dry-run" -ForegroundColor Gray
        $result = npm install --dry-run 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ npm install would succeed" -ForegroundColor Green
        } else {
            Write-Host "  ✗ npm install failed" -ForegroundColor Red
            Write-Host $result -ForegroundColor Red
        }
    } catch {
        Write-Host "  ✗ Error: $_" -ForegroundColor Red
    } finally {
        Pop-Location
    }
    
    Write-Host ""
}

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Test Complete!" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Commit and push your changes" -ForegroundColor White
Write-Host "2. Check GitHub Actions to see if workflows pass" -ForegroundColor White
Write-Host "3. Or run actual tests locally with: npm test (in each service directory)" -ForegroundColor White

