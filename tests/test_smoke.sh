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

echo "Testing Rust support..."
# Expected output for Rust (sorted for comparison)
EXPECTED_RUST=$(cat <<'EOF'
Drawable	19	trait_item
Drawable	23	impl_item
GLOBAL_CONFIG	46	static_item
Point	4	struct_item
Point	9	impl_item
Result	44	type_item
Status	29	enum_item
VERSION	2	const_item
add	34	function_item
debug_print	48	macro_definition
distance	14	function_item
draw	24	function_item
format	39	function_item
main	54	function_item
new	10	function_item
utils	38	mod_item
EOF
)

# Run wat on the Rust test fixture and sort output
ACTUAL_RUST=$(./zig-out/bin/wat tests/fixtures/simple.rs 2>&1 | sort)

# Sort expected output for comparison
EXPECTED_RUST_SORTED=$(echo "$EXPECTED_RUST" | sort)

# Compare Rust outputs
if [ "$ACTUAL_RUST" = "$EXPECTED_RUST_SORTED" ]; then
    echo "✓ Rust test passed"
else
    echo "✗ Rust test failed: Output mismatch"
    echo "Expected:"
    echo "$EXPECTED_RUST_SORTED"
    echo ""
    echo "Actual:"
    echo "$ACTUAL_RUST"
    exit 1
fi

echo "Testing C support..."
# Expected output for C (sorted for comparison)
EXPECTED_C=$(cat <<'EOF'
Calculator	58	struct_specifier
Data	42	union_specifier
MAX_SIZE	6	preproc_def
PROGRAM_NAME	20	declaration
Point	11	type_definition
Status	16	type_definition
VERSION	5	preproc_def
add	23	declaration
add	27	function_definition
distance	35	function_definition
dx	36	declaration
dy	37	declaration
global_counter	19	declaration
main	49	function_definition
print_point	24	declaration
print_point	31	function_definition
EOF
)

# Run wat on the C test fixture and sort output
ACTUAL_C=$(./zig-out/bin/wat tests/fixtures/simple.c 2>&1 | sort)

# Sort expected output for comparison
EXPECTED_C_SORTED=$(echo "$EXPECTED_C" | sort)

# Compare C outputs
if [ "$ACTUAL_C" = "$EXPECTED_C_SORTED" ]; then
    echo "✓ C test passed"
else
    echo "✗ C test failed: Output mismatch"
    echo "Expected:"
    echo "$EXPECTED_C_SORTED"
    echo ""
    echo "Actual:"
    echo "$ACTUAL_C"
    exit 1
fi

echo "Testing Java support..."
# Expected output for Java (sorted for comparison)
EXPECTED_JAVA=$(cat <<'EOF'
Drawable	29	interface_declaration
ERROR	48	enum_constant
Main	51	class_declaration
OK	47	enum_constant
Point	13	constructor_declaration
Point	7	class_declaration
Shape	33	class_declaration
Shape	36	constructor_declaration
Status	46	enum_declaration
VERSION	11	field_declaration
name	34	field_declaration
add	58	method_declaration
counter	52	field_declaration
distance	22	method_declaration
draw	30	method_declaration
draw	41	method_declaration
getX	18	method_declaration
main	54	method_declaration
x	8	field_declaration
y	9	field_declaration
EOF
)

# Run wat on the Java test fixture and sort output
ACTUAL_JAVA=$(./zig-out/bin/wat tests/fixtures/simple.java 2>&1 | sort)

# Sort expected output for comparison
EXPECTED_JAVA_SORTED=$(echo "$EXPECTED_JAVA" | sort)

# Compare Java outputs
if [ "$ACTUAL_JAVA" = "$EXPECTED_JAVA_SORTED" ]; then
    echo "✓ Java test passed"
else
    echo "✗ Java test failed: Output mismatch"
    echo "Expected:"
    echo "$EXPECTED_JAVA_SORTED"
    echo ""
    echo "Actual:"
    echo "$ACTUAL_JAVA"
    exit 1
fi

echo "✓ All tests passed: Symbol extraction works correctly for all languages"
exit 0