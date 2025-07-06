#!/bin/bash

# Simple smoke test for wat
# Tests basic symbol extraction functionality

set -e

echo "Running wat smoke test..."

echo "Testing Zig support..."
# Expected output for Zig (sorted for comparison)
EXPECTED_ZIG=$(cat <<'EOF'
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

# Run wat on the Zig test fixture and sort output
ACTUAL_ZIG=$(./zig-out/bin/wat tests/fixtures/simple.zig 2>&1 | sort)

# Sort expected output for comparison
EXPECTED_ZIG_SORTED=$(echo "$EXPECTED_ZIG" | sort)

# Compare Zig outputs
if [ "$ACTUAL_ZIG" = "$EXPECTED_ZIG_SORTED" ]; then
    echo "✓ Zig test passed"
else
    echo "✗ Zig test failed: Output mismatch"
    echo "Expected:"
    echo "$EXPECTED_ZIG_SORTED"
    echo ""
    echo "Actual:"
    echo "$ACTUAL_ZIG"
    exit 1
fi

echo "Testing Go support..."
# Expected output for Go (sorted for comparison)
EXPECTED_GO=$(cat <<'EOF'
Point	7	type_declaration
Status	20	type_declaration
StatusError	24	const_declaration
StatusOK	23	const_declaration
VERSION	5	const_declaration
add	12	function_declaration
globalConfig	27	var_declaration
main	16	function_declaration
EOF
)

# Run wat on the Go test fixture and sort output
ACTUAL_GO=$(./zig-out/bin/wat tests/fixtures/simple.go 2>&1 | sort)

# Sort expected output for comparison
EXPECTED_GO_SORTED=$(echo "$EXPECTED_GO" | sort)

# Compare Go outputs
if [ "$ACTUAL_GO" = "$EXPECTED_GO_SORTED" ]; then
    echo "✓ Go test passed"
else
    echo "✗ Go test failed: Output mismatch"
    echo "Expected:"
    echo "$EXPECTED_GO_SORTED"
    echo ""
    echo "Actual:"
    echo "$ACTUAL_GO"
    exit 1
fi

echo "Testing Python support..."
# Expected output for Python (sorted for comparison)
EXPECTED_PYTHON=$(cat <<'EOF'
ERROR	21	assignment
OK	20	assignment
Point	5	class_definition
Status	19	class_definition
VERSION	3	assignment
__init__	6	function_definition
add	13	function_definition
distance	10	function_definition
fetch_data	27	function_definition
global_config	23	assignment
main	16	function_definition
EOF
)

# Run wat on the Python test fixture and sort output
ACTUAL_PYTHON=$(./zig-out/bin/wat tests/fixtures/simple.py 2>&1 | sort)

# Sort expected output for comparison
EXPECTED_PYTHON_SORTED=$(echo "$EXPECTED_PYTHON" | sort)

# Compare Python outputs
if [ "$ACTUAL_PYTHON" = "$EXPECTED_PYTHON_SORTED" ]; then
    echo "✓ Python test passed"
else
    echo "✗ Python test failed: Output mismatch"
    echo "Expected:"
    echo "$EXPECTED_PYTHON_SORTED"
    echo ""
    echo "Actual:"
    echo "$ACTUAL_PYTHON"
    exit 1
fi

echo "Testing JavaScript support..."
# Expected output for JavaScript (sorted for comparison)
EXPECTED_JS=$(cat <<'EOF'
Point	3	class_declaration
Status	24	class_declaration
VERSION	1	lexical_declaration
add	14	function_declaration
fetchData	35	function_declaration
globalConfig	29	lexical_declaration
main	20	function_declaration
multiply	18	lexical_declaration
oldStyle	33	variable_declaration
response	36	lexical_declaration
EOF
)

# Run wat on the JavaScript test fixture and sort output
ACTUAL_JS=$(./zig-out/bin/wat tests/fixtures/simple.js 2>&1 | sort)

# Sort expected output for comparison
EXPECTED_JS_SORTED=$(echo "$EXPECTED_JS" | sort)

# Compare JavaScript outputs
if [ "$ACTUAL_JS" = "$EXPECTED_JS_SORTED" ]; then
    echo "✓ JavaScript test passed"
else
    echo "✗ JavaScript test failed: Output mismatch"
    echo "Expected:"
    echo "$EXPECTED_JS_SORTED"
    echo ""
    echo "Actual:"
    echo "$ACTUAL_JS"
    exit 1
fi

echo "Testing TypeScript support..."
# Expected output for TypeScript (sorted for comparison)
EXPECTED_TS=$(cat <<'EOF'
Color	11	enum_declaration
ComplexType	41	type_alias_declaration
DefaultExport	50	class_declaration
Point	4	interface_declaration
Shape	17	class_declaration
Status	9	type_alias_declaration
Utils	35	internal_module
VERSION	2	lexical_declaration
VERSION	51	public_field_definition
add	25	function_declaration
format	36	function_declaration
globalConfig	46	lexical_declaration
main	31	function_declaration
multiply	29	lexical_declaration
EOF
)

# Run wat on the TypeScript test fixture and sort output
ACTUAL_TS=$(./zig-out/bin/wat tests/fixtures/simple.ts 2>&1 | sort)

# Sort expected output for comparison
EXPECTED_TS_SORTED=$(echo "$EXPECTED_TS" | sort)

# Compare TypeScript outputs
if [ "$ACTUAL_TS" = "$EXPECTED_TS_SORTED" ]; then
    echo "✓ TypeScript test passed"
else
    echo "✗ TypeScript test failed: Output mismatch"
    echo "Expected:"
    echo "$EXPECTED_TS_SORTED"
    echo ""
    echo "Actual:"
    echo "$ACTUAL_TS"
    exit 1
fi

echo "✓ All tests passed: Symbol extraction works correctly for all languages"
exit 0