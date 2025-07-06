#!/bin/bash

# wat installation script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default installation directory
DEFAULT_INSTALL_DIR="$HOME/.local/bin"
INSTALL_DIR="${WAT_INSTALL_DIR:-$DEFAULT_INSTALL_DIR}"

echo "wat installation script"
echo "======================"
echo

# Check if wat binary exists
if [ ! -f "./zig-out/bin/wat" ]; then
    echo -e "${YELLOW}Binary not found. Building wat...${NC}"
    zig build -Doptimize=ReleaseSafe
fi

# Create install directory if it doesn't exist
mkdir -p "$INSTALL_DIR"

# Check if install directory is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo -e "${YELLOW}Warning: $INSTALL_DIR is not in your PATH${NC}"
    echo "Add this line to your shell configuration file (~/.bashrc, ~/.zshrc, etc.):"
    echo
    echo "  export PATH=\"\$PATH:$INSTALL_DIR\""
    echo
fi

# Install the binary
echo -e "Installing wat to ${GREEN}$INSTALL_DIR${NC}"
cp ./zig-out/bin/wat "$INSTALL_DIR/wat"
chmod +x "$INSTALL_DIR/wat"

# Verify installation
if command -v wat &> /dev/null; then
    echo -e "${GREEN}✓ Installation successful!${NC}"
    echo
    wat --help | head -5
else
    echo -e "${YELLOW}Installation complete, but 'wat' command not found in PATH${NC}"
    echo "You may need to:"
    echo "1. Add $INSTALL_DIR to your PATH (see warning above)"
    echo "2. Reload your shell configuration: source ~/.bashrc"
    echo "3. Or start a new terminal session"
fi

echo
echo "To uninstall, run: rm $INSTALL_DIR/wat"