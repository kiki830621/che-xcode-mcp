# che-xcode-mcp

Comprehensive App Store Connect MCP Server — 98 tools across 16 domain managers covering the full ASC API + Xcode Organizer crash logs.

## Features

| Category | Tools | Description |
|----------|-------|-------------|
| TestFlight | 9 | Builds, beta groups, testers, submissions |
| Apps | 5 | App listing, details, app info |
| Reviews | 6 | Customer reviews, responses, submission |
| Users | 7 | Team users, invitations, roles |
| Metadata | 7 | Versions, localizations, phased release |
| Subscriptions | 12 | Groups, subscriptions, localizations, pricing |
| Provisioning | 8 | Certificates, devices, bundle IDs, profiles |
| Pricing | 4 | Territories, prices, price points, availability |
| In-App Purchases | 8 | IAP v2 CRUD operations, localizations |
| Analytics | 5 | Report requests, instances, segments |
| Finance | 3 | Sales/finance reports |
| Performance | 4 | Power metrics, diagnostic signatures/logs |
| Xcode Cloud | 6 | CI products, workflows, build runs |
| Game Center | 5 | Leaderboards, achievements |
| App Clips | 5 | App Clips and default experiences |
| Organizer Crashes | 3 | Symbolicated crash logs from Xcode Organizer local cache |

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

- **Version**: 0.2.0
- **Platform**: macOS 14.0+
- **Language**: Swift 5.9
- **MCP SDK**: [swift-sdk](https://github.com/modelcontextprotocol/swift-sdk) 0.10.x
- **Auth**: ES256 JWT (App Store Connect API)
- **Binary**: Universal (arm64 + x86_64)

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 0.2.0 | 2026-02-18 | Fix 10 broken API tools, add subscription/IAP localization tools, subscription pricing tools |
| 0.1.0 | 2026-02-14 | Add Xcode Organizer crash log tools, fix diagnosticSignatures endpoint |
| 0.0.2 | 2026-02-14 | Fix TestFlight feedback endpoint, add crash feedback tool, server instructions for AI agents |
| 0.0.1 | 2026-02-13 | Initial release — 15 managers, 99 tools, full ASC API coverage |

## License

MIT
