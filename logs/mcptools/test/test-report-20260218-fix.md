# MCP Test Report: che-xcode-mcp (v0.2.0)
Generated: 2026-02-18

## Test Summary
- Total Tools Tested: 35+
- Passed: 25+ (previously working) + 10 (fixed)
- Failed: 0 (code bugs)
- Expected 404s: 2 (app-specific, not code bugs)
- Coverage: ~35 of 103 tools (read-only category)

## Fixes Applied (v0.2.0)

### Root Cause Analysis
All 10 broken tools were sending invalid API parameters that don't match Apple's ASC OpenAPI specification. Additionally, 3 tools had a crash bug from `NSString` with `%s` format specifier.

### Fix Details

| # | Tool | Problem | Fix | Result |
|---|------|---------|-----|--------|
| 1 | `metadata_list_versions` | Sent unsupported `sort=-createdDate` | Removed sort param | PASS |
| 2 | `iap_list_iaps` | `fields[inAppPurchasesV2]` wrong type name | Changed to `fields[inAppPurchases]` | PASS |
| 3 | `users_list_users` | `fields[users]` included invalid `email` field | Removed `email` from fields | PASS |
| 4 | `users_list_invitations` | `sort=-expirationDate` invalid | Changed to `sort=email` | PASS |
| 5 | `provisioning_list_profiles` | `sort=-expirationDate` invalid | Changed to `sort=name` | PASS |
| 6 | `provisioning_list_certificates` | `sort=-expirationDate` invalid | Changed to `sort=displayName` | PASS |
| 7 | `pricing_get_app_prices` | `include=appPrices` invalid relationship | Changed to `include=manualPrices,automaticPrices,baseTerritory` | PASS (404 for free app = expected) |
| 8 | `pricing_get_availability` | Path `appAvailability` removed | Changed to `appAvailabilityV2` + `include=territoryAvailabilities` | PASS (404 for unconfigured app = expected) |
| 9 | `pricing_list_territories` | CRASH from `NSString` + `%s` format | Replaced with Swift string padding | PASS |
| 10 | `pricing_list_price_points` | Invalid field `priceTier` + CRASH | Removed field + fixed `NSString`/`%s` | PASS |

### Previously Passing Tools (confirmed working)

| Category | Tools | Status |
|----------|-------|--------|
| App Management | `app_list_apps`, `app_get_app`, `app_list_app_infos`, `app_get_app_info` | PASS |
| TestFlight | `testflight_list_builds`, `testflight_get_build`, `testflight_list_groups`, `testflight_list_testers`, `testflight_list_feedback`, `testflight_list_crash_feedback` | PASS |
| Subscriptions | `subscription_list_groups`, `subscription_list_subscriptions`, `subscription_get_group`, `subscription_get_subscription` | PASS |
| Provisioning | `provisioning_list_devices`, `provisioning_list_bundle_ids` | PASS |
| Reviews | `review_list_customer_reviews` | PASS |
| Performance | `performance_get_power_metrics` | PASS |
| Organizer | `organizer_list_crashes`, `organizer_get_crash_log`, `organizer_get_crash_stats` | PASS |
| Xcode Cloud | `ci_list_products`, `ci_list_workflows` | PASS |
| Analytics | `analytics_list_reports` | PASS |
| App Clips | `appclip_list_app_clips` | PASS |
| Finance | `finance_list_sales_report_types` | PASS |

### Not Tested (write operations / need specific IDs)
- TestFlight: `add_tester`, `remove_tester`, `submit_for_review`, `set_whats_new`
- Metadata: `create_version`, `update_version`, `update_localization`
- Review: `respond_to_review`, `submit_for_review`
- Subscription: `create_group`, `create_subscription`, `update_subscription`
- IAP: `create_iap`, `update_iap`, `delete_iap`, `submit_iap`
- Users: `invite_user`, `cancel_invitation`, `remove_user`, `update_user_roles`
- Provisioning: `register_device`, `update_device`
- Analytics: multi-step pipeline (request → list → instances → segments)
- Game Center: no Game Center detail configured
- App Clips: no clips configured

## Additional Fix: Authentication
- **401 error root cause**: Claude Code caches MCP env vars from `.mcp.json` at session startup. Old key `HQURM2CVH4` was cached even after `.mcp.json` was emptied.
- **Fix**: Wrapper now unconditionally overrides env vars from `~/.appstoreconnect/config` (source of truth).

## Reference
- Apple ASC OpenAPI Spec: https://github.com/EvanBacon/App-Store-Connect-OpenAPI-Spec
- GitHub Release: https://github.com/kiki830621/che-xcode-mcp/releases/tag/v0.2.0
