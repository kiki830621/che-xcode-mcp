import Foundation
import MCP

// MARK: - ASC Attribute Models

struct AppStoreVersionAttributes: Decodable {
    let versionString: String?
    let platform: String?
    let appStoreState: String?
    let copyright: String?
    let releaseType: String?
    let earliestReleaseDate: Date?
    let createdDate: Date?
}

struct AppStoreVersionLocalizationAttributes: Decodable {
    let locale: String?
    let description: String?
    let keywords: String?
    let whatsNew: String?
    let promotionalText: String?
    let marketingUrl: String?
    let supportUrl: String?
}

struct AppStoreVersionPhasedReleaseAttributes: Decodable {
    let phasedReleaseState: String?
    let startDate: Date?
    let totalPauseDuration: Int?
    let currentDayNumber: Int?
}

// MARK: - Type aliases

private typealias AppStoreVersion = ASCResource<AppStoreVersionAttributes>
private typealias AppStoreVersionLocalization = ASCResource<AppStoreVersionLocalizationAttributes>
private typealias AppStoreVersionPhasedRelease = ASCResource<AppStoreVersionPhasedReleaseAttributes>

// MARK: - MetadataManager

actor MetadataManager: ToolProvider {
    private let client: ASCClient

    init(client: ASCClient) {
        self.client = client
    }

    // MARK: - ToolProvider

    var tools: [Tool] {
        [
            Tool(
                name: "metadata_list_versions",
                description: "List App Store versions for an app. Shows version string, platform, and review state.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "app_id": .object([
                            "type": "string",
                            "description": "App Store Connect app ID (required)"
                        ]),
                        "platform": .object([
                            "type": "string",
                            "description": "Filter by platform (IOS, MAC_OS)"
                        ]),
                        "version_state": .object([
                            "type": "string",
                            "description": "Filter by version state (e.g. READY_FOR_SALE, PREPARE_FOR_SUBMISSION, WAITING_FOR_REVIEW)"
                        ])
                    ]),
                    "required": .array([.string("app_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "metadata_get_version",
                description: "Get detailed information about a specific App Store version.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "version_id": .object([
                            "type": "string",
                            "description": "The App Store version ID"
                        ])
                    ]),
                    "required": .array([.string("version_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "metadata_create_version",
                description: "Create a new App Store version for an app.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "app_id": .object([
                            "type": "string",
                            "description": "App Store Connect app ID"
                        ]),
                        "version_string": .object([
                            "type": "string",
                            "description": "Version string (e.g. 1.2.0)"
                        ]),
                        "platform": .object([
                            "type": "string",
                            "description": "Platform (default: IOS). Options: IOS, MAC_OS"
                        ])
                    ]),
                    "required": .array([.string("app_id"), .string("version_string")])
                ]),
                annotations: .init(destructiveHint: false)
            ),
            Tool(
                name: "metadata_update_version",
                description: "Update App Store version attributes such as copyright, release type, or earliest release date.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "version_id": .object([
                            "type": "string",
                            "description": "The App Store version ID to update"
                        ]),
                        "version_string": .object([
                            "type": "string",
                            "description": "New version string"
                        ]),
                        "copyright": .object([
                            "type": "string",
                            "description": "Copyright text (e.g. 2025 My Company)"
                        ]),
                        "release_type": .object([
                            "type": "string",
                            "description": "Release type: MANUAL, AFTER_APPROVAL, or SCHEDULED"
                        ]),
                        "earliest_release_date": .object([
                            "type": "string",
                            "description": "Earliest release date in ISO 8601 format (for SCHEDULED release type)"
                        ])
                    ]),
                    "required": .array([.string("version_id")])
                ]),
                annotations: .init(destructiveHint: false)
            ),
            Tool(
                name: "metadata_list_localizations",
                description: "List all localizations for an App Store version. Shows locale, description, keywords, and what's new.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "version_id": .object([
                            "type": "string",
                            "description": "The App Store version ID"
                        ])
                    ]),
                    "required": .array([.string("version_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "metadata_update_localization",
                description: "Update an App Store version localization (description, keywords, what's new, etc.).",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "localization_id": .object([
                            "type": "string",
                            "description": "The localization ID to update"
                        ]),
                        "description": .object([
                            "type": "string",
                            "description": "App description text"
                        ]),
                        "keywords": .object([
                            "type": "string",
                            "description": "Search keywords (comma-separated)"
                        ]),
                        "whatsNew": .object([
                            "type": "string",
                            "description": "What's New in This Version text"
                        ]),
                        "promotionalText": .object([
                            "type": "string",
                            "description": "Promotional text (can be updated without a new version)"
                        ]),
                        "marketingUrl": .object([
                            "type": "string",
                            "description": "Marketing URL"
                        ]),
                        "supportUrl": .object([
                            "type": "string",
                            "description": "Support URL"
                        ])
                    ]),
                    "required": .array([.string("localization_id")])
                ]),
                annotations: .init(destructiveHint: false)
            ),
            Tool(
                name: "metadata_get_phased_release",
                description: "Get phased release status for an App Store version. Shows rollout day, state, and pause duration.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "version_id": .object([
                            "type": "string",
                            "description": "The App Store version ID"
                        ])
                    ]),
                    "required": .array([.string("version_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
        ]
    }

    func handle(_ name: String, arguments: [String: Value]) async throws -> String {
        switch name {
        case "metadata_list_versions":
            return try await handleListVersions(arguments)
        case "metadata_get_version":
            return try await handleGetVersion(arguments)
        case "metadata_create_version":
            return try await handleCreateVersion(arguments)
        case "metadata_update_version":
            return try await handleUpdateVersion(arguments)
        case "metadata_list_localizations":
            return try await handleListLocalizations(arguments)
        case "metadata_update_localization":
            return try await handleUpdateLocalization(arguments)
        case "metadata_get_phased_release":
            return try await handleGetPhasedRelease(arguments)
        default:
            throw ASCClientError.invalidResponse("Unknown metadata tool: \(name)")
        }
    }

    // MARK: - Handler: List Versions

    private func handleListVersions(_ args: [String: Value]) async throws -> String {
        let appId = try requireString(args, "app_id")

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "fields[appStoreVersions]", value: "versionString,platform,appStoreState,copyright,releaseType,earliestReleaseDate,createdDate"),
            URLQueryItem(name: "sort", value: "-createdDate"),
        ]

        if let platform = stringValue(args, "platform") {
            queryItems.append(URLQueryItem(name: "filter[platform]", value: platform))
        }
        if let state = stringValue(args, "version_state") {
            queryItems.append(URLQueryItem(name: "filter[appStoreState]", value: state))
        }

        let response: ASCListResponse<AppStoreVersion> = try await client.getList(
            path: "/v1/apps/\(appId)/appStoreVersions",
            queryItems: queryItems
        )

        if response.data.isEmpty {
            return "No App Store versions found for app \(appId)."
        }

        var lines = ["App Store Versions (\(response.data.count)):"]
        lines.append(String(repeating: "-", count: 60))
        for version in response.data {
            lines.append(formatVersion(version))
        }

        if let paging = response.meta?.paging, let total = paging.total {
            lines.append("\nShowing \(response.data.count) of \(total) total versions.")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Handler: Get Version

    private func handleGetVersion(_ args: [String: Value]) async throws -> String {
        let versionId = try requireString(args, "version_id")

        let queryItems = [
            URLQueryItem(name: "fields[appStoreVersions]", value: "versionString,platform,appStoreState,copyright,releaseType,earliestReleaseDate,createdDate")
        ]

        let response: ASCResponse<AppStoreVersion> = try await client.get(
            path: "/v1/appStoreVersions/\(versionId)",
            queryItems: queryItems
        )

        return formatVersionDetailed(response.data)
    }

    // MARK: - Handler: Create Version

    private func handleCreateVersion(_ args: [String: Value]) async throws -> String {
        let appId = try requireString(args, "app_id")
        let versionString = try requireString(args, "version_string")
        let platform = stringValue(args, "platform") ?? "IOS"

        let body: [String: Any] = [
            "data": [
                "type": "appStoreVersions",
                "attributes": [
                    "versionString": versionString,
                    "platform": platform
                ],
                "relationships": [
                    "app": [
                        "data": [
                            "type": "apps",
                            "id": appId
                        ]
                    ]
                ]
            ]
        ]

        let response: ASCResponse<AppStoreVersion> = try await client.post(
            path: "/v1/appStoreVersions",
            body: body
        )

        let version = response.data
        let state = version.attributes?.appStoreState ?? "UNKNOWN"
        return "Created App Store version \(versionString) (\(platform)).\nVersion ID: \(version.id)\nState: \(stateEmoji(state)) \(state)"
    }

    // MARK: - Handler: Update Version

    private func handleUpdateVersion(_ args: [String: Value]) async throws -> String {
        let versionId = try requireString(args, "version_id")

        var attributes: [String: Any] = [:]
        if let versionString = stringValue(args, "version_string") {
            attributes["versionString"] = versionString
        }
        if let copyright = stringValue(args, "copyright") {
            attributes["copyright"] = copyright
        }
        if let releaseType = stringValue(args, "release_type") {
            attributes["releaseType"] = releaseType
        }
        if let earliestReleaseDate = stringValue(args, "earliest_release_date") {
            attributes["earliestReleaseDate"] = earliestReleaseDate
        }

        if attributes.isEmpty {
            return "No attributes provided to update. Specify at least one of: version_string, copyright, release_type, earliest_release_date."
        }

        let body: [String: Any] = [
            "data": [
                "type": "appStoreVersions",
                "id": versionId,
                "attributes": attributes
            ]
        ]

        let response: ASCResponse<AppStoreVersion> = try await client.patch(
            path: "/v1/appStoreVersions/\(versionId)",
            body: body
        )

        let version = response.data
        let updatedFields = attributes.keys.sorted().joined(separator: ", ")
        return "Updated App Store version \(versionId).\nUpdated fields: \(updatedFields)\nVersion: \(version.attributes?.versionString ?? "N/A")\nState: \(stateEmoji(version.attributes?.appStoreState ?? "UNKNOWN")) \(version.attributes?.appStoreState ?? "UNKNOWN")"
    }

    // MARK: - Handler: List Localizations

    private func handleListLocalizations(_ args: [String: Value]) async throws -> String {
        let versionId = try requireString(args, "version_id")

        let queryItems = [
            URLQueryItem(name: "fields[appStoreVersionLocalizations]", value: "locale,description,keywords,whatsNew,promotionalText,marketingUrl,supportUrl")
        ]

        let response: ASCListResponse<AppStoreVersionLocalization> = try await client.getList(
            path: "/v1/appStoreVersions/\(versionId)/appStoreVersionLocalizations",
            queryItems: queryItems
        )

        if response.data.isEmpty {
            return "No localizations found for version \(versionId)."
        }

        var lines = ["App Store Version Localizations (\(response.data.count)):"]
        lines.append(String(repeating: "-", count: 60))
        for localization in response.data {
            lines.append(formatLocalization(localization))
            lines.append(String(repeating: "-", count: 60))
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Handler: Update Localization

    private func handleUpdateLocalization(_ args: [String: Value]) async throws -> String {
        let localizationId = try requireString(args, "localization_id")

        var attributes: [String: Any] = [:]
        if let description = stringValue(args, "description") {
            attributes["description"] = description
        }
        if let keywords = stringValue(args, "keywords") {
            attributes["keywords"] = keywords
        }
        if let whatsNew = stringValue(args, "whatsNew") {
            attributes["whatsNew"] = whatsNew
        }
        if let promotionalText = stringValue(args, "promotionalText") {
            attributes["promotionalText"] = promotionalText
        }
        if let marketingUrl = stringValue(args, "marketingUrl") {
            attributes["marketingUrl"] = marketingUrl
        }
        if let supportUrl = stringValue(args, "supportUrl") {
            attributes["supportUrl"] = supportUrl
        }

        if attributes.isEmpty {
            return "No attributes provided to update. Specify at least one of: description, keywords, whatsNew, promotionalText, marketingUrl, supportUrl."
        }

        let body: [String: Any] = [
            "data": [
                "type": "appStoreVersionLocalizations",
                "id": localizationId,
                "attributes": attributes
            ]
        ]

        let response: ASCResponse<AppStoreVersionLocalization> = try await client.patch(
            path: "/v1/appStoreVersionLocalizations/\(localizationId)",
            body: body
        )

        let loc = response.data
        let locale = loc.attributes?.locale ?? "unknown"
        let updatedFields = attributes.keys.sorted().joined(separator: ", ")
        return "Updated localization \(localizationId) (locale: \(locale)).\nUpdated fields: \(updatedFields)"
    }

    // MARK: - Handler: Get Phased Release

    private func handleGetPhasedRelease(_ args: [String: Value]) async throws -> String {
        let versionId = try requireString(args, "version_id")

        let response: ASCResponse<AppStoreVersionPhasedRelease> = try await client.get(
            path: "/v1/appStoreVersions/\(versionId)/appStoreVersionPhasedRelease"
        )

        return formatPhasedReleaseDetailed(response.data)
    }

    // MARK: - Formatters

    private func stateEmoji(_ state: String) -> String {
        switch state {
        case "READY_FOR_SALE": return "[LIVE]"
        case "PREPARE_FOR_SUBMISSION": return "[DRAFT]"
        case "WAITING_FOR_REVIEW": return "[REVIEW]"
        case "IN_REVIEW": return "[REVIEW]"
        case "DEVELOPER_REJECTED": return "[REJECTED]"
        case "REJECTED": return "[REJECTED]"
        case "PENDING_DEVELOPER_RELEASE": return "[PENDING]"
        case "PROCESSING_FOR_APP_STORE": return "[PROCESSING]"
        case "DEVELOPER_REMOVED_FROM_SALE": return "[REMOVED]"
        case "REMOVED_FROM_SALE": return "[REMOVED]"
        case "REPLACED_WITH_NEW_VERSION": return "[REPLACED]"
        default: return "[\(state)]"
        }
    }

    private func formatVersion(_ version: AppStoreVersion) -> String {
        let attrs = version.attributes
        let versionString = attrs?.versionString ?? "?"
        let platform = attrs?.platform ?? "?"
        let state = attrs?.appStoreState ?? "UNKNOWN"
        let created = formatDate(attrs?.createdDate)
        return "  [\(version.id)] v\(versionString) — \(stateEmoji(state)) \(state) | \(platform) | Created: \(created)"
    }

    private func formatVersionDetailed(_ version: AppStoreVersion) -> String {
        let attrs = version.attributes
        let state = attrs?.appStoreState ?? "UNKNOWN"
        var lines = [
            "App Store Version Details",
            String(repeating: "-", count: 40),
            "  ID:              \(version.id)",
            "  Version:         \(attrs?.versionString ?? "N/A")",
            "  Platform:        \(attrs?.platform ?? "N/A")",
            "  State:           \(stateEmoji(state)) \(state)",
            "  Copyright:       \(attrs?.copyright ?? "N/A")",
            "  Release Type:    \(attrs?.releaseType ?? "N/A")",
            "  Created:         \(formatDate(attrs?.createdDate))",
        ]
        if let earliestRelease = attrs?.earliestReleaseDate {
            lines.append("  Earliest Release: \(formatDate(earliestRelease))")
        }
        return lines.joined(separator: "\n")
    }

    private func formatLocalization(_ loc: AppStoreVersionLocalization) -> String {
        let attrs = loc.attributes
        let locale = attrs?.locale ?? "unknown"
        var lines = ["  [\(loc.id)] Locale: \(locale)"]

        if let description = attrs?.description, !description.isEmpty {
            let preview = description.count > 120 ? String(description.prefix(120)) + "..." : description
            lines.append("    Description: \(preview)")
        }
        if let keywords = attrs?.keywords, !keywords.isEmpty {
            let preview = keywords.count > 100 ? String(keywords.prefix(100)) + "..." : keywords
            lines.append("    Keywords:    \(preview)")
        }
        if let whatsNew = attrs?.whatsNew, !whatsNew.isEmpty {
            let preview = whatsNew.count > 120 ? String(whatsNew.prefix(120)) + "..." : whatsNew
            lines.append("    What's New:  \(preview)")
        }
        if let promo = attrs?.promotionalText, !promo.isEmpty {
            let preview = promo.count > 100 ? String(promo.prefix(100)) + "..." : promo
            lines.append("    Promo Text:  \(preview)")
        }
        if let marketing = attrs?.marketingUrl, !marketing.isEmpty {
            lines.append("    Marketing:   \(marketing)")
        }
        if let support = attrs?.supportUrl, !support.isEmpty {
            lines.append("    Support:     \(support)")
        }

        return lines.joined(separator: "\n")
    }

    private func formatPhasedReleaseDetailed(_ release: AppStoreVersionPhasedRelease) -> String {
        let attrs = release.attributes
        let state = attrs?.phasedReleaseState ?? "UNKNOWN"
        var lines = [
            "Phased Release Status",
            String(repeating: "-", count: 40),
            "  ID:              \(release.id)",
            "  State:           \(state)",
            "  Current Day:     \(attrs?.currentDayNumber.map(String.init) ?? "N/A")",
            "  Start Date:      \(formatDate(attrs?.startDate))",
        ]
        if let pauseDuration = attrs?.totalPauseDuration {
            lines.append("  Pause Duration:  \(pauseDuration) day(s)")
        }

        // Show rollout percentage guide
        lines.append("")
        lines.append("  Phased Rollout Schedule:")
        lines.append("    Day 1:  1%   | Day 2:  2%   | Day 3:  5%")
        lines.append("    Day 4: 10%   | Day 5: 20%   | Day 6: 50%")
        lines.append("    Day 7: 100%")

        return lines.joined(separator: "\n")
    }
}
