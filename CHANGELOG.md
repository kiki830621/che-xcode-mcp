# Changelog

## [0.3.0] - 2026-02-18

### Added (13 new submission automation tools)

**Build Linking**
- `metadata_get_build_for_version` — get the build linked to an App Store version
- `metadata_set_build_for_version` — link/unlink a build to a version (required before review submission)

**Review Detail**
- `metadata_get_review_detail` — get review contact info, demo account credentials, and notes
- `metadata_update_review_detail` — update contact info, demo account, and reviewer notes

**Localization**
- `metadata_create_localization` — add a new language (locale) to an App Store version

**Phased Release**
- `metadata_create_phased_release` — enable 7-day phased rollout for a version
- `metadata_update_phased_release` — pause, resume, or complete a phased release
- `metadata_delete_phased_release` — remove phased release (release to all at once)

**Release**
- `metadata_release_version` — trigger manual release for approved versions (PENDING_DEVELOPER_RELEASE)

**Screenshots**
- `metadata_list_screenshot_sets` — list screenshot sets by device type for a localization
- `metadata_list_screenshots` — list screenshots within a screenshot set

**Age Rating**
- `metadata_get_age_rating` — get age rating declaration (violence, gambling, etc.)
- `metadata_update_age_rating` — update age rating content categories

**Screenshot Upload**
- `metadata_create_screenshot_set` — create a screenshot set for a device type
- `metadata_upload_screenshot` — upload screenshot from local file (3-step: reserve → upload → commit with MD5)
- `metadata_delete_screenshot` — delete a screenshot
- `metadata_delete_screenshot_set` — delete an entire screenshot set

### Changed
- ASCClient: added `patchNoContent` for 204 No Content, `getOptional` for nullable responses
- Metadata manager: 7 → 24 tools
- Tool count: 98 → 115

### Fixed
- Gracefully handle null data from ASC API (unlinked build, missing review detail, no phased release)

## [0.2.0] - 2026-02-18

### Fixed (10 broken API tools)
- `metadata_list_versions` — removed unsupported `sort=-createdDate` parameter
- `iap_list_iaps` / `iap_get_iap` — fixed field type name from `fields[inAppPurchasesV2]` to `fields[inAppPurchases]`
- `users_list_users` / `users_get_user` — removed invalid `email` from `fields[users]` (email comes from response attributes, not a requestable field)
- `users_list_invitations` — changed invalid `sort=-expirationDate` to `sort=email`
- `provisioning_list_profiles` — changed invalid `sort=-expirationDate` to `sort=name`
- `provisioning_list_certificates` — changed invalid `sort=-expirationDate` to `sort=displayName`
- `pricing_get_app_prices` — changed invalid `include=appPrices` to `include=manualPrices,automaticPrices,baseTerritory`; updated path to use appPriceSchedule v3
- `pricing_get_availability` — changed removed `appAvailability` path to `appAvailabilityV2`; updated include to `territoryAvailabilities`
- `pricing_list_territories` — fixed crash from `NSString` + `%s` format specifier; replaced with Swift `.padding()`
- `pricing_list_price_points` — removed invalid `priceTier` field; fixed same `NSString`/`%s` crash

### Added
- `subscription_list_localizations` — list all language versions of a subscription (name, description)
- `subscription_update_localization` — update subscription display name/description for a specific locale
- `subscription_create_localization` — add a new language version for a subscription
- `iap_list_localizations` — list all language versions of an in-app purchase
- `iap_update_localization` — update IAP display name/description for a specific locale
- `subscription_list_prices` — list subscription prices across territories
- `subscription_list_price_points` — list available subscription price points for a territory

### Changed
- JWTManager: replaced `try!` with proper `do-catch` error handling
- Wrapper script now unconditionally overrides env vars from `~/.appstoreconnect/config` (fixes 401 auth caching issue)
- Tool count: 91 → 98

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
