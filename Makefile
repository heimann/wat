.PHONY: build test clean

build:
	zig build

test: build
	@./tests/test_smoke.sh 2>&1

clean:
	rm -rf zig-out zig-cache .zig-cache

all: build test