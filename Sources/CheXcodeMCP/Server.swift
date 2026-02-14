import Foundation
import MCP

/// MCP Server routing tool calls to domain Managers via ToolProvider protocol.
class CheXcodeMCPServer {
    private let server: Server
    private let transport: StdioTransport
    private let providers: [String: any ToolProvider]
    private let allTools: [Tool]

    init() async throws {
        // Initialize auth and HTTP client
        let jwtManager = try JWTManager(fromEnvironment: ())
        let ascClient = ASCClient(jwtManager: jwtManager)

        // Initialize all managers
        let testFlight = TestFlightManager(client: ascClient)
        let app = AppManager(client: ascClient)
        let review = ReviewManager(client: ascClient)
        let users = UsersManager(client: ascClient)
        let metadata = MetadataManager(client: ascClient)
        let subscription = SubscriptionManager(client: ascClient)
        let provisioning = ProvisioningManager(client: ascClient)
        let pricing = PricingManager(client: ascClient)
        let iap = IAPManager(client: ascClient)
        let analytics = AnalyticsManager(client: ascClient)
        let finance = FinanceManager(client: ascClient)
        let performance = PerformanceManager(client: ascClient)
        let xcodeCloud = XcodeCloudManager(client: ascClient)
        let gameCenter = GameCenterManager(client: ascClient)
        let appClips = AppClipsManager(client: ascClient)

        // Register providers with their prefix
        providers = [
            "testflight": testFlight,
            "app": app,
            "review": review,
            "users": users,
            "metadata": metadata,
            "subscription": subscription,
            "provisioning": provisioning,
            "pricing": pricing,
            "iap": iap,
            "analytics": analytics,
            "finance": finance,
            "performance": performance,
            "ci": xcodeCloud,
            "gamecenter": gameCenter,
            "appclip": appClips,
        ]

        // Collect all tools from all providers
        var tools: [Tool] = []
        for provider in providers.values {
            let providerTools = await provider.tools
            tools.append(contentsOf: providerTools)
        }
        allTools = tools

        // Create MCP server
        server = Server(
            name: AppVersion.name,
            version: AppVersion.current,
            instructions: Self.serverInstructions,
            capabilities: .init(tools: .init())
        )
        transport = StdioTransport()

        await registerHandlers()
    }

    func run() async throws {
        try await server.start(transport: transport)
        await server.waitUntilCompleted()
    }

    // MARK: - Server Instructions

    /// Instructions sent to AI agents on initialization.
    /// Clarifies tool taxonomy, ID types, and common pitfalls.
    private static let serverInstructions = """
    # CheXcodeMCP — App Store Connect API MCP Server

    This server wraps the Apple App Store Connect API v1. All tools require JWT authentication (configured via environment).

    ## ID Types — Do NOT Confuse

    Every tool parameter ending in `_id` refers to an App Store Connect **resource UUID** (e.g., `03df8937-39b3-4fde-adfa-dfe5c1dec5b8`), NOT a human-readable identifier.

    | Parameter | What It Is | Example | Where to Get It |
    |-----------|-----------|---------|-----------------|
    | `app_id` | ASC app resource ID | `6759075868` | `app_list_apps` → each app's `id` field |
    | `build_id` | ASC build resource UUID | `03df8937-...` | `testflight_list_builds` → each build's `id` field |
    | `version_id` | ASC app store version UUID | `abc123-...` | `metadata_list_versions` → each version's `id` field |
    | `group_id` | Beta group UUID | `def456-...` | `testflight_list_groups` → each group's `id` field |
    | `tester_id` | Beta tester UUID | `789abc-...` | `testflight_list_testers` → each tester's `id` field |

    **Common mistake**: Using a build *version number* (like "7") instead of the build *UUID*. Always use the `id` field from list results.

    ## Tool Categories

    | Prefix | Domain | Key Concept |
    |--------|--------|-------------|
    | `testflight_` | TestFlight beta distribution | Builds, testers, groups, beta feedback |
    | `app_` | App management | App listing, bundle IDs, app info |
    | `metadata_` | App Store metadata | Versions, localizations, phased release |
    | `review_` | **App Store** customer reviews | User ratings/reviews on the App Store (NOT TestFlight) |
    | `iap_` | In-app purchases | IAP creation, management, submission |
    | `subscription_` | Auto-renewable subscriptions | Groups, subscriptions, pricing |
    | `users_` | Team members | Users, invitations, roles |
    | `provisioning_` | Code signing | Certificates, devices, profiles, bundle IDs |
    | `pricing_` | App pricing | Territories, price points, availability |
    | `analytics_` | App analytics reports | Multi-step: request → list → instances → segments |
    | `finance_` | Sales & financial reports | Sales reports (CSV), financial reports |
    | `performance_` | Performance diagnostics | Power metrics, crash signatures, diagnostic logs |
    | `ci_` | Xcode Cloud | CI products, workflows, build runs |
    | `gamecenter_` | Game Center | Leaderboards, achievements |
    | `appclip_` | App Clips | Clips, default experiences |

    ## Critical Distinctions

    ### "Review" vs "Feedback" — These Are DIFFERENT Things

    | Concept | Tool Prefix | What It Is |
    |---------|------------|------------|
    | **Customer Reviews** | `review_` | Ratings and reviews on the **App Store** from end users who downloaded your app |
    | **TestFlight Feedback** | `testflight_list_feedback` | Screenshots + comments from **beta testers** via TestFlight app |
    | **TestFlight Crash Feedback** | `testflight_list_crash_feedback` | Crash reports + comments from **beta testers** |
    | **Beta Review Submission** | `testflight_submit_for_review` | Submitting a build to **Apple** for external beta review approval |
    | **App Store Review Submission** | `review_submit_for_review` | Submitting a version to **Apple** for App Store review |

    ### TestFlight Feedback Requires `app_id`, Not `build_id`

    `testflight_list_feedback` and `testflight_list_crash_feedback` require `app_id` because feedback is an app-level resource. Use optional `build_id` to filter by specific build.

    ### Analytics Is Multi-Step

    Analytics data requires a pipeline:
    1. `analytics_request_report` — Request a new report (or find existing)
    2. `analytics_list_reports` — Check report status
    3. `analytics_list_instances` — Get generated report instances (by date/granularity)
    4. `analytics_list_segments` — Get downloadable URLs for report data

    ## Parameter Notes

    - `limit` parameters have server-side maximum of 200. Default varies by tool.
    - Date filters use ISO 8601 format (e.g., `2025-01-15`).
    - All list tools return results sorted by most recent first unless otherwise specified.
    """

    // MARK: - Handler Registration

    private func registerHandlers() async {
        await server.withMethodHandler(ListTools.self) { [allTools] _ in
            ListTools.Result(tools: allTools)
        }

        await server.withMethodHandler(CallTool.self) { [weak self] params in
            guard let self else {
                return CallTool.Result(content: [.text("Server unavailable")], isError: true)
            }
            return await self.handleToolCall(
                name: params.name,
                arguments: params.arguments ?? [:]
            )
        }
    }

    private func handleToolCall(
        name: String,
        arguments: [String: Value]
    ) async -> CallTool.Result {
        // Route by prefix: "testflight_list_builds" → prefix "testflight"
        let prefix = name.split(separator: "_").first.map(String.init) ?? name
        guard let provider = providers[prefix] else {
            return CallTool.Result(
                content: [.text("Unknown tool category: '\(prefix)'. Available: \(providers.keys.sorted().joined(separator: ", "))")],
                isError: true
            )
        }

        do {
            let result = try await provider.handle(name, arguments: arguments)
            return CallTool.Result(content: [.text(result)])
        } catch {
            return CallTool.Result(
                content: [.text("Error: \(error.localizedDescription)")],
                isError: true
            )
        }
    }
}
