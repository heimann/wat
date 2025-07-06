#!/bin/bash

# Simple smoke test for wat
# Tests basic symbol extraction functionality

set -e

echo "Running wat smoke test..."

# Expected output (sorted for comparison)
EXPECTED=$(cat <<'EOF'
InvalidInput	34	error_set_declaration
MyError	33	variable_declaration
Point	5	variable_declaration
Result	23	variable_declaration
Status	18	variable_declaration
VERSION	3	variable_declaration
add	10	function_declaration
privateHelper	14	function_declaration
result	29	variable_declaration
std	1	variable_declaration
EOF
)

# Run wat on the test fixture and sort output
ACTUAL=$(./zig-out/bin/wat tests/fixtures/simple.zig 2>&1 | sort)

# Sort expected output for comparison
EXPECTED_SORTED=$(echo "$EXPECTED" | sort)

# Compare outputs
if [ "$ACTUAL" = "$EXPECTED_SORTED" ]; then
    echo "✓ Test passed: Symbol extraction works correctly"
    exit 0
else
    echo "✗ Test failed: Output mismatch"
    echo "Expected:"
    echo "$EXPECTED_SORTED"
    echo ""
    echo "Actual:"
    echo "$ACTUAL"
    exit 1
fi