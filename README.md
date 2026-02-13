# che-xcode-mcp

Comprehensive App Store Connect MCP Server — 99 tools across 15 domain managers covering the full ASC API.

## Features

| Category | Tools | Description |
|----------|-------|-------------|
| TestFlight | 9 | Builds, beta groups, testers, submissions |
| Apps | 5 | App listing, details, app info |
| Reviews | 6 | Customer reviews, responses, submission |
| Users | 7 | Team users, invitations, roles |
| Metadata | 7 | Versions, localizations, phased release |
| Subscriptions | 7 | Groups, subscriptions management |
| Provisioning | 8 | Certificates, devices, bundle IDs, profiles |
| Pricing | 4 | Territories, prices, price points, availability |
| In-App Purchases | 6 | IAP v2 CRUD operations |
| Analytics | 5 | Report requests, instances, segments |
| Finance | 3 | Sales/finance reports |
| Performance | 4 | Power metrics, diagnostic signatures/logs |
| Xcode Cloud | 6 | CI products, workflows, build runs |
| Game Center | 5 | Leaderboards, achievements |
| App Clips | 5 | App Clips and default experiences |

## Installation

### From Source

```bash
git clone https://github.com/kiki830621/che-xcode-mcp.git
cd che-xcode-mcp
swift build -c release
cp .build/release/CheXcodeMCP ~/bin/
```

### From GitHub Release

Download the universal binary from [Releases](https://github.com/kiki830621/che-xcode-mcp/releases) and copy to `~/bin/`.

## Configuration

### Environment Variables

| Variable | Description |
|----------|-------------|
| `ASC_KEY_ID` | App Store Connect API Key ID |
| `ASC_ISSUER_ID` | App Store Connect Issuer ID |
| `ASC_PRIVATE_KEY_PATH` | Path to `.p8` private key file |

### Claude Code

Add to `~/.claude/settings.json`:

```json
{
  "mcpServers": {
    "che-xcode-mcp": {
      "command": "~/bin/CheXcodeMCP",
      "env": {
        "ASC_KEY_ID": "YOUR_KEY_ID",
        "ASC_ISSUER_ID": "YOUR_ISSUER_ID",
        "ASC_PRIVATE_KEY_PATH": "~/.appstoreconnect/private_keys/AuthKey_XXXX.p8"
      }
    }
  }
}
```

## Technical Details

- **Version**: 1.0.0
- **Platform**: macOS 14.0+
- **Language**: Swift 5.9
- **MCP SDK**: [swift-sdk](https://github.com/modelcontextprotocol/swift-sdk) 0.10.x
- **Auth**: ES256 JWT (App Store Connect API)
- **Binary**: Universal (arm64 + x86_64)

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-02-13 | Initial release — 15 managers, 99 tools, full ASC API coverage |

## License

MIT
