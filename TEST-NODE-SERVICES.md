# Testing Node.js Services

This document contains all the test commands to verify the Node.js setup fix.

## Quick Test (PowerShell)

Run from the root directory:
```powershell
.\test-all-node.ps1
```

## Quick Test (Bash/Linux/Mac)

Run from the root directory:
```bash
chmod +x test-all-node.sh
./test-all-node.sh
```

## Manual Test Commands

If you prefer to run commands manually, here are all the tests in one place:

### 1. Test reference-data
```powershell
cd reference-data
npm install
npm test -- --coverage=false
npm run build
cd ..
```

### 2. Test trade-feed
```powershell
cd trade-feed
npm install
npm run build
cd ..
```

### 3. Test web-front-end/angular
```powershell
cd web-front-end\angular
npm install
npm run build
npm run test:ci
cd ..\..
```

### 4. Test web-front-end/react
```powershell
cd web-front-end\react
npm install
npm run build
npm test -- --coverage=false
cd ..\..
```

## All-in-One Command Block (PowerShell)

Copy and paste this entire block:

```powershell
# Test reference-data
Write-Host "Testing reference-data..." -ForegroundColor Yellow
cd reference-data
npm install
npm test -- --coverage=false
npm run build
cd ..

# Test trade-feed
Write-Host "Testing trade-feed..." -ForegroundColor Yellow
cd trade-feed
npm install
npm run build
cd ..

# Test angular
Write-Host "Testing web-front-end/angular..." -ForegroundColor Yellow
cd web-front-end\angular
npm install
npm run build
npm run test:ci
cd ..\..

# Test react
Write-Host "Testing web-front-end/react..." -ForegroundColor Yellow
cd web-front-end\react
npm install
npm run build
npm test -- --coverage=false
cd ..\..

Write-Host "All tests completed!" -ForegroundColor Green
```

## What to Verify

✅ **Main Fix**: `npm install` should work for all services (no errors about missing package-lock.json)

✅ **Builds**: All services should build successfully

⚠️ **Tests**: Some test failures are expected (Angular/React may need additional CI setup), but the install step should work

## Next Steps

Once `npm install` works for all services:
1. Commit the workflow changes
2. Push to GitHub
3. Check GitHub Actions to verify the CI workflows pass

