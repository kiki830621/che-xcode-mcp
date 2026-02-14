# Changelog

## [0.1.0] - 2026-02-14

### Added
- `organizer_list_crashes` — list crash signatures from Xcode Organizer's local cache (no ASC API needed)
- `organizer_get_crash_log` — read full symbolicated crash backtraces from Xcode Organizer cache
- `organizer_get_crash_stats` — get crash statistics (version/OS/device/distribution breakdown)
- Server instructions: added `organizer_` tool category and crash data source documentation
- Tool count: 100 → 103

### Fixed
- `performance_list_diagnostic_signatures` — was using non-existent `/v1/apps/{id}/diagnosticSignatures` (404). Fixed to correct endpoint `/v1/builds/{id}/diagnosticSignatures`. Parameter changed from `app_id` to `build_id`.

### Changed
- `performance_list_diagnostic_signatures` now requires `build_id` (was `app_id`). Get build UUIDs from `testflight_list_builds`.

## [0.0.2] - 2026-02-14

### Fixed
- Fix `testflight_list_feedback` — was using non-existent `/v1/builds/{id}/betaAppReviewSubmissions` endpoint (404 error). Replaced with correct `/v1/apps/{id}/betaFeedbackScreenshotSubmissions` endpoint (WWDC25 new API)

### Added
- `testflight_list_crash_feedback` — new tool for crash feedback from beta testers via `/v1/apps/{id}/betaFeedbackCrashSubmissions`
- Server-level `instructions` — comprehensive AI agent guide covering ID types, tool categories, critical distinctions (review vs feedback), and multi-step workflows
- Improved tool descriptions across TestFlight, Review, Analytics, Metadata, and App managers with cross-references and disambiguation

### Changed
- `testflight_list_feedback` now requires `app_id` (was `build_id`) — feedback is an app-level resource, optional `build_id` filter added
- Tool count: 99 → 100 (added `testflight_list_crash_feedback`)

## [0.0.1] - 2026-02-13

### Added
- Initial release with 15 domain managers covering the full App Store Connect API
- 99 MCP tools across 16 categories
- JWT authentication (ES256) for App Store Connect API
- Generic HTTP client with JSON:API parsing, pagination, error handling
- ToolProvider protocol for modular manager architecture
- **TestFlight**: builds, beta groups, testers, submissions (9 tools)
- **Apps**: app listing, details, app info (5 tools)
- **Reviews**: customer reviews, responses, submission (6 tools)
- **Users**: team users, invitations, roles (7 tools)
- **Metadata**: versions, localizations, phased release (7 tools)
- **Subscriptions**: groups, subscriptions management (7 tools)
- **Provisioning**: certificates, devices, bundle IDs, profiles (8 tools)
- **Pricing**: territories, prices, price points, availability (4 tools)
- **In-App Purchases**: IAP v2 CRUD operations (6 tools)
- **Analytics**: report requests, instances, segments (5 tools)
- **Finance**: sales/finance reports (3 tools)
- **Performance**: power metrics, diagnostic signatures/logs (4 tools)
- **Xcode Cloud**: CI products, workflows, build runs (6 tools)
- **Game Center**: leaderboards, achievements (5 tools)
- **App Clips**: App Clips and default experiences (5 tools)
- Universal Binary (arm64 + x86_64) support
- Build scripts and integration test
