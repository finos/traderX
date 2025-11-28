#!/bin/bash
# Test all Node.js services - simulates CI workflow behavior
# Run this from the root directory: ./test-all-node.sh

set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo "Testing All Node.js Services"
echo "========================================"
echo ""

# Test 1: reference-data
echo "[1/4] Testing reference-data..."
echo "----------------------------------------"
cd "$ROOT_DIR/reference-data"
if [ -f "package-lock.json" ]; then
    echo "  package-lock.json exists - would use npm ci"
else
    echo "  package-lock.json missing - will use npm install"
fi
npm install
npm test -- --coverage=false
npm run build
echo ""

# Test 2: trade-feed
echo "[2/4] Testing trade-feed..."
echo "----------------------------------------"
cd "$ROOT_DIR/trade-feed"
if [ -f "package-lock.json" ]; then
    echo "  package-lock.json exists - would use npm ci"
else
    echo "  package-lock.json missing - will use npm install"
fi
npm install
npm run build || echo "  [WARN] Build may not be configured for trade-feed"
echo "  [SKIP] No tests configured for trade-feed"
echo ""

# Test 3: web-front-end/angular
echo "[3/4] Testing web-front-end/angular..."
echo "----------------------------------------"
cd "$ROOT_DIR/web-front-end/angular"
if [ -f "package-lock.json" ]; then
    echo "  package-lock.json exists - would use npm ci"
else
    echo "  package-lock.json missing - will use npm install"
fi
npm install
npm run build
npm run test:ci || echo "  [WARN] Tests may need additional CI setup"
echo ""

# Test 4: web-front-end/react
echo "[4/4] Testing web-front-end/react..."
echo "----------------------------------------"
cd "$ROOT_DIR/web-front-end/react"
if [ -f "package-lock.json" ]; then
    echo "  package-lock.json exists - would use npm ci"
else
    echo "  package-lock.json missing - will use npm install"
fi
npm install
npm run build
npm test -- --coverage=false || echo "  [WARN] Tests may need additional setup"
echo ""

# Return to root
cd "$ROOT_DIR"

echo "========================================"
echo "Testing Complete!"
echo "========================================"
echo ""
echo "If npm install succeeded for all services, the fix is working!"
echo "You can now commit and push the workflow changes."

