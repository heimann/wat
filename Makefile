.PHONY: build test clean install uninstall install-debug install-link

# Installation directory
PREFIX ?= $(HOME)/.local
BINDIR = $(PREFIX)/bin

build:
	zig build

build-release:
	zig build -Doptimize=ReleaseSafe

test: build
	@./tests/test_smoke.sh 2>&1

clean:
	rm -rf zig-out zig-cache .zig-cache

install: build-release
	@mkdir -p $(BINDIR)
	@cp ./zig-out/bin/wat $(BINDIR)/wat
	@chmod +x $(BINDIR)/wat
	@echo "Installed wat to $(BINDIR)/wat"
	@if ! echo $$PATH | grep -q "$(BINDIR)"; then \
		echo "⚠️  Warning: $(BINDIR) is not in your PATH"; \
		echo "   Add this to your shell config: export PATH=\"\$$PATH:$(BINDIR)\""; \
	fi

uninstall:
	@rm -f $(BINDIR)/wat
	@echo "Uninstalled wat from $(BINDIR)"

# For development - install debug build
install-debug: build
	@mkdir -p $(BINDIR)
	@cp ./zig-out/bin/wat $(BINDIR)/wat
	@chmod +x $(BINDIR)/wat
	@echo "Installed wat (debug) to $(BINDIR)/wat"

# Install with symlink (for development)
install-link: build
	@mkdir -p $(BINDIR)
	@ln -sf $(shell pwd)/zig-out/bin/wat $(BINDIR)/wat
	@echo "Created symlink to wat in $(BINDIR)/wat"

all: build test