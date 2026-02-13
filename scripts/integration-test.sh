#!/bin/bash
# Integration test for che-xcode-mcp
# Requires: ASC_KEY_ID, ASC_ISSUER_ID, ASC_PRIVATE_KEY_PATH environment variables
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== che-xcode-mcp Integration Test ==="
echo ""

# Check environment
MISSING_ENV=0
for var in ASC_KEY_ID ASC_ISSUER_ID ASC_PRIVATE_KEY_PATH; do
    if [[ -z "${!var}" ]]; then
        echo "  ✗ $var not set"
        MISSING_ENV=1
    else
        echo "  ✓ $var set"
    fi
done

if [[ $MISSING_ENV -eq 1 ]]; then
    echo ""
    echo "Missing env vars. Source your .env file first:"
    echo "  export ASC_KEY_ID=..."
    echo "  export ASC_ISSUER_ID=..."
    echo "  export ASC_PRIVATE_KEY_PATH=..."
    exit 1
fi

# Build
echo ""
echo "[1/3] Building..."
cd "$PROJECT_DIR"
swift build -c release 2>&1 | tail -1

BINARY="$PROJECT_DIR/.build/release/CheXcodeMCP"
if [[ ! -f "$BINARY" ]]; then
    echo "Error: Binary not found"
    exit 1
fi

# Test: Version flag
echo ""
echo "[2/3] Version check..."
VERSION=$("$BINARY" --version)
echo "  Version: $VERSION"

# Test: MCP protocol — send initialize + tools/list via stdin
echo ""
echo "[3/3] MCP protocol test — listing tools..."

# JSON-RPC messages
INIT='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}'
INITIALIZED='{"jsonrpc":"2.0","method":"notifications/initialized"}'
LIST_TOOLS='{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'

# Send messages to MCP server via stdin, capture stdout
RESULT=$(echo -e "${INIT}\n${INITIALIZED}\n${LIST_TOOLS}" | timeout 10 "$BINARY" 2>/dev/null || true)

if [[ -z "$RESULT" ]]; then
    echo "  ✗ No response from server"
    exit 1
fi

# Count tools in response
TOOL_COUNT=$(echo "$RESULT" | grep -o '"name"' | wc -l | tr -d ' ')
echo "  Tools registered: $TOOL_COUNT"

# Extract tool names
echo ""
echo "  Tool categories:"
echo "$RESULT" | grep -o '"name":"[^"]*"' | sed 's/"name":"//;s/"//' | cut -d_ -f1 | sort -u | while read prefix; do
    COUNT=$(echo "$RESULT" | grep -o "\"name\":\"${prefix}_[^\"]*\"" | wc -l | tr -d ' ')
    echo "    $prefix: $COUNT tools"
done

# Quick API test — list apps (read-only, safe)
echo ""
echo "[Bonus] Live API test — listing apps..."
CALL_TOOL='{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"app_list_apps","arguments":{"limit":3}}}'

API_RESULT=$(echo -e "${INIT}\n${INITIALIZED}\n${CALL_TOOL}" | timeout 15 "$BINARY" 2>/dev/null || true)

if echo "$API_RESULT" | grep -q '"isError":true'; then
    echo "  ✗ API call failed"
    echo "$API_RESULT" | grep -o '"text":"[^"]*"' | head -1
elif echo "$API_RESULT" | grep -q '"text"'; then
    echo "  ✓ API call succeeded"
    # Show first few lines of response
    echo "$API_RESULT" | grep -o '"text":"[^"]*"' | tail -1 | sed 's/"text":"//;s/"$//' | head -c 200
    echo "..."
else
    echo "  ? No API response (may need valid credentials)"
fi

echo ""
echo "=== Integration Test Complete ==="
