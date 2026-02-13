import Foundation
import MCP

// MARK: - ASC Attribute Models

struct GameCenterDetailAttributes: Decodable {
    let arcadeEnabled: Bool?
    let challengeEnabled: Bool?
}

struct GameCenterLeaderboardAttributes: Decodable {
    let referenceName: String?
    let vendorIdentifier: String?
    let defaultFormatter: String?
    let submissionType: String?
}

struct GameCenterAchievementAttributes: Decodable {
    let referenceName: String?
    let vendorIdentifier: String?
    let points: Int?
    let showBeforeEarned: Bool?
    let repeatable: Bool?
}

// MARK: - Type aliases

private typealias GameCenterDetail = ASCResource<GameCenterDetailAttributes>
private typealias GameCenterLeaderboard = ASCResource<GameCenterLeaderboardAttributes>
private typealias GameCenterAchievement = ASCResource<GameCenterAchievementAttributes>

// MARK: - GameCenterManager

actor GameCenterManager: ToolProvider {
    private let client: ASCClient

    init(client: ASCClient) {
        self.client = client
    }

    // MARK: - ToolProvider

    var tools: [Tool] {
        [
            Tool(
                name: "gamecenter_get_detail",
                description: "Get Game Center detail and status for an app.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "app_id": .object([
                            "type": "string",
                            "description": "The App Store Connect app ID"
                        ])
                    ]),
                    "required": .array([.string("app_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "gamecenter_list_leaderboards",
                description: "List Game Center leaderboards for a Game Center detail.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "detail_id": .object([
                            "type": "string",
                            "description": "The Game Center detail ID"
                        ]),
                        "limit": .object([
                            "type": "integer",
                            "description": "Maximum number of leaderboards to return (default 50, max 200)"
                        ])
                    ]),
                    "required": .array([.string("detail_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "gamecenter_list_achievements",
                description: "List Game Center achievements for a Game Center detail.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "detail_id": .object([
                            "type": "string",
                            "description": "The Game Center detail ID"
                        ]),
                        "limit": .object([
                            "type": "integer",
                            "description": "Maximum number of achievements to return (default 50, max 200)"
                        ])
                    ]),
                    "required": .array([.string("detail_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "gamecenter_get_leaderboard",
                description: "Get detailed information about a specific Game Center leaderboard.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "leaderboard_id": .object([
                            "type": "string",
                            "description": "The Game Center leaderboard ID"
                        ])
                    ]),
                    "required": .array([.string("leaderboard_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "gamecenter_get_achievement",
                description: "Get detailed information about a specific Game Center achievement.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "achievement_id": .object([
                            "type": "string",
                            "description": "The Game Center achievement ID"
                        ])
                    ]),
                    "required": .array([.string("achievement_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
        ]
    }

    func handle(_ name: String, arguments: [String: Value]) async throws -> String {
        switch name {
        case "gamecenter_get_detail":
            return try await handleGetDetail(arguments)
        case "gamecenter_list_leaderboards":
            return try await handleListLeaderboards(arguments)
        case "gamecenter_list_achievements":
            return try await handleListAchievements(arguments)
        case "gamecenter_get_leaderboard":
            return try await handleGetLeaderboard(arguments)
        case "gamecenter_get_achievement":
            return try await handleGetAchievement(arguments)
        default:
            throw ASCClientError.invalidResponse("Unknown Game Center tool: \(name)")
        }
    }

    // MARK: - Handler: Get Detail

    private func handleGetDetail(_ args: [String: Value]) async throws -> String {
        let appId = try requireString(args, "app_id")

        let queryItems = [
            URLQueryItem(name: "fields[gameCenterDetails]", value: "arcadeEnabled,challengeEnabled")
        ]

        let response: ASCResponse<GameCenterDetail> = try await client.get(
            path: "/v1/apps/\(appId)/gameCenterDetail",
            queryItems: queryItems
        )

        return formatDetailDetailed(response.data, appId: appId)
    }

    // MARK: - Handler: List Leaderboards

    private func handleListLeaderboards(_ args: [String: Value]) async throws -> String {
        let detailId = try requireString(args, "detail_id")
        let limit = intValue(args, "limit") ?? 50

        let queryItems = [
            URLQueryItem(name: "fields[gameCenterLeaderboards]", value: "referenceName,vendorIdentifier,defaultFormatter,submissionType"),
            URLQueryItem(name: "limit", value: String(min(limit, 200))),
        ]

        let response: ASCListResponse<GameCenterLeaderboard> = try await client.getList(
            path: "/v1/gameCenterDetails/\(detailId)/gameCenterLeaderboards",
            queryItems: queryItems
        )

        if response.data.isEmpty {
            return "No leaderboards found for Game Center detail \(detailId)."
        }

        var lines = ["Game Center Leaderboards (\(response.data.count)):"]
        lines.append(String(repeating: "-", count: 60))
        for leaderboard in response.data {
            lines.append(formatLeaderboard(leaderboard))
        }

        if let paging = response.meta?.paging, let total = paging.total {
            lines.append("\nShowing \(response.data.count) of \(total) total leaderboards.")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Handler: List Achievements

    private func handleListAchievements(_ args: [String: Value]) async throws -> String {
        let detailId = try requireString(args, "detail_id")
        let limit = intValue(args, "limit") ?? 50

        let queryItems = [
            URLQueryItem(name: "fields[gameCenterAchievements]", value: "referenceName,vendorIdentifier,points,showBeforeEarned,repeatable"),
            URLQueryItem(name: "limit", value: String(min(limit, 200))),
        ]

        let response: ASCListResponse<GameCenterAchievement> = try await client.getList(
            path: "/v1/gameCenterDetails/\(detailId)/gameCenterAchievements",
            queryItems: queryItems
        )

        if response.data.isEmpty {
            return "No achievements found for Game Center detail \(detailId)."
        }

        var lines = ["Game Center Achievements (\(response.data.count)):"]
        lines.append(String(repeating: "-", count: 60))
        for achievement in response.data {
            lines.append(formatAchievement(achievement))
        }

        if let paging = response.meta?.paging, let total = paging.total {
            lines.append("\nShowing \(response.data.count) of \(total) total achievements.")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Handler: Get Leaderboard

    private func handleGetLeaderboard(_ args: [String: Value]) async throws -> String {
        let leaderboardId = try requireString(args, "leaderboard_id")

        let queryItems = [
            URLQueryItem(name: "fields[gameCenterLeaderboards]", value: "referenceName,vendorIdentifier,defaultFormatter,submissionType")
        ]

        let response: ASCResponse<GameCenterLeaderboard> = try await client.get(
            path: "/v1/gameCenterLeaderboards/\(leaderboardId)",
            queryItems: queryItems
        )

        return formatLeaderboardDetailed(response.data)
    }

    // MARK: - Handler: Get Achievement

    private func handleGetAchievement(_ args: [String: Value]) async throws -> String {
        let achievementId = try requireString(args, "achievement_id")

        let queryItems = [
            URLQueryItem(name: "fields[gameCenterAchievements]", value: "referenceName,vendorIdentifier,points,showBeforeEarned,repeatable")
        ]

        let response: ASCResponse<GameCenterAchievement> = try await client.get(
            path: "/v1/gameCenterAchievements/\(achievementId)",
            queryItems: queryItems
        )

        return formatAchievementDetailed(response.data)
    }

    // MARK: - Formatters

    private func formatDetailDetailed(_ detail: GameCenterDetail, appId: String) -> String {
        let attrs = detail.attributes
        let lines = [
            "Game Center Detail",
            String(repeating: "-", count: 40),
            "  ID:                \(detail.id)",
            "  App ID:            \(appId)",
            "  Arcade Enabled:    \(attrs?.arcadeEnabled == true ? "Yes" : "No")",
            "  Challenge Enabled: \(attrs?.challengeEnabled == true ? "Yes" : "No")",
        ]
        return lines.joined(separator: "\n")
    }

    private func formatLeaderboard(_ leaderboard: GameCenterLeaderboard) -> String {
        let attrs = leaderboard.attributes
        let name = attrs?.referenceName ?? "Unnamed"
        let vendor = attrs?.vendorIdentifier ?? "?"
        let submission = attrs?.submissionType ?? "?"
        return "  [\(leaderboard.id)] \(name) — vendor: \(vendor) | submission: \(submission)"
    }

    private func formatLeaderboardDetailed(_ leaderboard: GameCenterLeaderboard) -> String {
        let attrs = leaderboard.attributes
        let lines = [
            "Game Center Leaderboard Details",
            String(repeating: "-", count: 40),
            "  ID:                \(leaderboard.id)",
            "  Reference Name:    \(attrs?.referenceName ?? "N/A")",
            "  Vendor Identifier: \(attrs?.vendorIdentifier ?? "N/A")",
            "  Default Formatter: \(attrs?.defaultFormatter ?? "N/A")",
            "  Submission Type:   \(attrs?.submissionType ?? "N/A")",
        ]
        return lines.joined(separator: "\n")
    }

    private func formatAchievement(_ achievement: GameCenterAchievement) -> String {
        let attrs = achievement.attributes
        let name = attrs?.referenceName ?? "Unnamed"
        let vendor = attrs?.vendorIdentifier ?? "?"
        let points = attrs?.points.map { "\($0) pts" } ?? "? pts"
        var flags: [String] = []
        if attrs?.showBeforeEarned == true { flags.append("visible") }
        if attrs?.repeatable == true { flags.append("repeatable") }
        let flagStr = flags.isEmpty ? "" : " | \(flags.joined(separator: ", "))"
        return "  [\(achievement.id)] \(name) — vendor: \(vendor) | \(points)\(flagStr)"
    }

    private func formatAchievementDetailed(_ achievement: GameCenterAchievement) -> String {
        let attrs = achievement.attributes
        let lines = [
            "Game Center Achievement Details",
            String(repeating: "-", count: 40),
            "  ID:                 \(achievement.id)",
            "  Reference Name:     \(attrs?.referenceName ?? "N/A")",
            "  Vendor Identifier:  \(attrs?.vendorIdentifier ?? "N/A")",
            "  Points:             \(attrs?.points.map { "\($0)" } ?? "N/A")",
            "  Show Before Earned: \(attrs?.showBeforeEarned == true ? "Yes" : "No")",
            "  Repeatable:         \(attrs?.repeatable == true ? "Yes" : "No")",
        ]
        return lines.joined(separator: "\n")
    }
}
