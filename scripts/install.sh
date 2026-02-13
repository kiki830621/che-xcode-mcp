#!/bin/bash
# Install che-xcode-mcp to ~/bin and configure Claude Code MCP
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BINARY_NAME="CheXcodeMCP"
INSTALL_DIR="$HOME/bin"

echo "=== che-xcode-mcp Install Script ==="

# Step 1: Build release binary
echo "[1/3] Building release binary..."
cd "$PROJECT_DIR"
swift build -c release

RELEASE_BINARY="$PROJECT_DIR/.build/release/$BINARY_NAME"
if [[ ! -f "$RELEASE_BINARY" ]]; then
    echo "Error: Binary not found at $RELEASE_BINARY"
    exit 1
fi

# Step 2: Install to ~/bin
echo "[2/3] Installing to $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"
cp "$RELEASE_BINARY" "$INSTALL_DIR/$BINARY_NAME"
chmod +x "$INSTALL_DIR/$BINARY_NAME"
echo "  Installed: $INSTALL_DIR/$BINARY_NAME"

# Step 3: Show MCP config
echo "[3/3] MCP configuration..."
echo ""
echo "Add to ~/.claude/settings.json under mcpServers:"
echo ""
cat <<'JSONEOF'
{
  "che-xcode-mcp": {
    "command": "~/bin/CheXcodeMCP",
    "env": {
      "ASC_KEY_ID": "YOUR_KEY_ID",
      "ASC_ISSUER_ID": "YOUR_ISSUER_ID",
      "ASC_PRIVATE_KEY_PATH": "~/.appstoreconnect/private_keys/AuthKey_XXXX.p8"
    }
  }
}
JSONEOF

echo ""
echo "=== Install Complete ==="
echo "Binary: $INSTALL_DIR/$BINARY_NAME"
echo "Version: $($INSTALL_DIR/$BINARY_NAME --version 2>/dev/null || echo 'unknown')"
