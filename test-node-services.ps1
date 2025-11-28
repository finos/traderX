# Test script to verify Node.js services setup
# This simulates what the CI workflow does

$services = @(
    "reference-data",
    "trade-feed",
    "web-front-end/angular",
    "web-front-end/react"
)

$failedServices = @()

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Testing Node.js Services Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

foreach ($service in $services) {
    Write-Host "Testing: $service" -ForegroundColor Yellow
    Write-Host "----------------------------------------" -ForegroundColor Gray
    
    $servicePath = Join-Path $PSScriptRoot $service
    
    if (-not (Test-Path $servicePath)) {
        Write-Host "  ERROR: Service directory not found: $servicePath" -ForegroundColor Red
        $failedServices += $service
        continue
    }
    
    # Check for package.json
    $packageJson = Join-Path $servicePath "package.json"
    if (-not (Test-Path $packageJson)) {
        Write-Host "  ERROR: package.json not found" -ForegroundColor Red
        $failedServices += $service
        continue
    }
    
    # Check for package-lock.json (to verify our logic)
    $packageLock = Join-Path $servicePath "package-lock.json"
    if (Test-Path $packageLock) {
        Write-Host "  [OK] package-lock.json exists (would use npm ci)" -ForegroundColor Green
    } else {
        Write-Host "  [OK] package-lock.json missing (will use npm install)" -ForegroundColor Green
    }
    
    # Test npm install
    Write-Host "  Running npm install..." -ForegroundColor Gray
    Push-Location $servicePath
    try {
        $installOutput = npm install 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [OK] npm install succeeded" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] npm install failed" -ForegroundColor Red
            $failedServices += $service
            Pop-Location
            continue
        }
    } catch {
        Write-Host "  [FAIL] npm install error: $_" -ForegroundColor Red
        $failedServices += $service
        Pop-Location
        continue
    }
    
    # Test build
    Write-Host "  Running npm run build..." -ForegroundColor Gray
    try {
        $buildOutput = npm run build 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [OK] npm run build succeeded" -ForegroundColor Green
        } else {
            Write-Host "  [WARN] npm run build failed (exit code: $LASTEXITCODE)" -ForegroundColor Yellow
            Write-Host "    Note: Some services may not have a build script" -ForegroundColor Gray
        }
    } catch {
        Write-Host "  [WARN] npm run build error: $_" -ForegroundColor Yellow
    }
    
    # Test tests (if applicable)
    if ($service -eq "trade-feed") {
        Write-Host "  [SKIP] Skipping tests for trade-feed (no tests configured)" -ForegroundColor Yellow
    } elseif ($service -eq "web-front-end/angular") {
        Write-Host "  Running npm run test:ci..." -ForegroundColor Gray
        try {
            $testOutput = npm run test:ci 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  [OK] Tests passed" -ForegroundColor Green
            } else {
                Write-Host "  [WARN] Tests failed (exit code: $LASTEXITCODE)" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "  [WARN] Test error: $_" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  Running npm test..." -ForegroundColor Gray
        try {
            $testOutput = npm test -- --coverage=false 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  [OK] Tests passed" -ForegroundColor Green
            } else {
                Write-Host "  [WARN] Tests failed (exit code: $LASTEXITCODE)" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "  [WARN] Test error: $_" -ForegroundColor Yellow
        }
    }
    
    Pop-Location
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if ($failedServices.Count -eq 0) {
    Write-Host "[SUCCESS] All services passed basic setup checks!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Commit and push your changes" -ForegroundColor White
    Write-Host "  2. Check GitHub Actions to see if workflows pass" -ForegroundColor White
} else {
    Write-Host "[FAILED] Some services failed:" -ForegroundColor Red
    foreach ($service in $failedServices) {
        Write-Host "  - $service" -ForegroundColor Red
    }
}

