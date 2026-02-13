import Foundation
import MCP

// MARK: - ASC Attribute Models

struct AppClipAttributes: Decodable {
    let bundleId: String?
}

struct AppClipDefaultExperienceAttributes: Decodable {
    let action: String?
}

// MARK: - Type aliases

private typealias AppClip = ASCResource<AppClipAttributes>
private typealias AppClipDefaultExperience = ASCResource<AppClipDefaultExperienceAttributes>

// MARK: - AppClipsManager

actor AppClipsManager: ToolProvider {
    private let client: ASCClient

    init(client: ASCClient) {
        self.client = client
    }

    // MARK: - ToolProvider

    var tools: [Tool] {
        [
            Tool(
                name: "appclip_list_app_clips",
                description: "List App Clips for an app.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "app_id": .object([
                            "type": "string",
                            "description": "The App Store Connect app ID"
                        ]),
                        "limit": .object([
                            "type": "integer",
                            "description": "Maximum number of App Clips to return (default 50, max 200)"
                        ])
                    ]),
                    "required": .array([.string("app_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "appclip_get_app_clip",
                description: "Get detailed information about a specific App Clip.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "clip_id": .object([
                            "type": "string",
                            "description": "The App Clip ID"
                        ])
                    ]),
                    "required": .array([.string("clip_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "appclip_list_default_experiences",
                description: "List default experiences for an App Clip.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "clip_id": .object([
                            "type": "string",
                            "description": "The App Clip ID"
                        ]),
                        "limit": .object([
                            "type": "integer",
                            "description": "Maximum number of experiences to return (default 50, max 200)"
                        ])
                    ]),
                    "required": .array([.string("clip_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "appclip_get_default_experience",
                description: "Get detailed information about a specific App Clip default experience.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "experience_id": .object([
                            "type": "string",
                            "description": "The App Clip default experience ID"
                        ])
                    ]),
                    "required": .array([.string("experience_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "appclip_update_default_experience",
                description: "Update the action for an App Clip default experience.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "experience_id": .object([
                            "type": "string",
                            "description": "The App Clip default experience ID"
                        ]),
                        "action": .object([
                            "type": "string",
                            "description": "The action type (OPEN, VIEW, PLAY)"
                        ])
                    ]),
                    "required": .array([.string("experience_id")])
                ]),
                annotations: .init(destructiveHint: false)
            ),
        ]
    }

    func handle(_ name: String, arguments: [String: Value]) async throws -> String {
        switch name {
        case "appclip_list_app_clips":
            return try await handleListAppClips(arguments)
        case "appclip_get_app_clip":
            return try await handleGetAppClip(arguments)
        case "appclip_list_default_experiences":
            return try await handleListDefaultExperiences(arguments)
        case "appclip_get_default_experience":
            return try await handleGetDefaultExperience(arguments)
        case "appclip_update_default_experience":
            return try await handleUpdateDefaultExperience(arguments)
        default:
            throw ASCClientError.invalidResponse("Unknown App Clip tool: \(name)")
        }
    }

    // MARK: - Handler: List App Clips

    private func handleListAppClips(_ args: [String: Value]) async throws -> String {
        let appId = try requireString(args, "app_id")
        let limit = intValue(args, "limit") ?? 50

        let queryItems = [
            URLQueryItem(name: "fields[appClips]", value: "bundleId"),
            URLQueryItem(name: "limit", value: String(min(limit, 200))),
        ]

        let response: ASCListResponse<AppClip> = try await client.getList(
            path: "/v1/apps/\(appId)/appClips",
            queryItems: queryItems
        )

        if response.data.isEmpty {
            return "No App Clips found for app \(appId)."
        }

        var lines = ["App Clips for app \(appId) (\(response.data.count)):"]
        lines.append(String(repeating: "-", count: 60))
        for clip in response.data {
            lines.append(formatAppClip(clip))
        }

        if let paging = response.meta?.paging, let total = paging.total {
            lines.append("\nShowing \(response.data.count) of \(total) total App Clips.")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Handler: Get App Clip

    private func handleGetAppClip(_ args: [String: Value]) async throws -> String {
        let clipId = try requireString(args, "clip_id")

        let queryItems = [
            URLQueryItem(name: "fields[appClips]", value: "bundleId")
        ]

        let response: ASCResponse<AppClip> = try await client.get(
            path: "/v1/appClips/\(clipId)",
            queryItems: queryItems
        )

        return formatAppClipDetailed(response.data)
    }

    // MARK: - Handler: List Default Experiences

    private func handleListDefaultExperiences(_ args: [String: Value]) async throws -> String {
        let clipId = try requireString(args, "clip_id")
        let limit = intValue(args, "limit") ?? 50

        let queryItems = [
            URLQueryItem(name: "fields[appClipDefaultExperiences]", value: "action"),
            URLQueryItem(name: "limit", value: String(min(limit, 200))),
        ]

        let response: ASCListResponse<AppClipDefaultExperience> = try await client.getList(
            path: "/v1/appClips/\(clipId)/appClipDefaultExperiences",
            queryItems: queryItems
        )

        if response.data.isEmpty {
            return "No default experiences found for App Clip \(clipId)."
        }

        var lines = ["App Clip Default Experiences for clip \(clipId) (\(response.data.count)):"]
        lines.append(String(repeating: "-", count: 60))
        for experience in response.data {
            lines.append(formatDefaultExperience(experience))
        }

        if let paging = response.meta?.paging, let total = paging.total {
            lines.append("\nShowing \(response.data.count) of \(total) total experiences.")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Handler: Get Default Experience

    private func handleGetDefaultExperience(_ args: [String: Value]) async throws -> String {
        let experienceId = try requireString(args, "experience_id")

        let queryItems = [
            URLQueryItem(name: "fields[appClipDefaultExperiences]", value: "action")
        ]

        let response: ASCResponse<AppClipDefaultExperience> = try await client.get(
            path: "/v1/appClipDefaultExperiences/\(experienceId)",
            queryItems: queryItems
        )

        return formatDefaultExperienceDetailed(response.data)
    }

    // MARK: - Handler: Update Default Experience

    private func handleUpdateDefaultExperience(_ args: [String: Value]) async throws -> String {
        let experienceId = try requireString(args, "experience_id")

        var attributes: [String: Any] = [:]
        if let action = stringValue(args, "action") {
            attributes["action"] = action
        }

        let body: [String: Any] = [
            "data": [
                "type": "appClipDefaultExperiences",
                "id": experienceId,
                "attributes": attributes
            ]
        ]

        let response: ASCResponse<AppClipDefaultExperience> = try await client.patch(
            path: "/v1/appClipDefaultExperiences/\(experienceId)",
            body: body
        )

        let updatedAction = response.data.attributes?.action ?? "N/A"
        return "Successfully updated App Clip default experience \(experienceId).\nAction: \(updatedAction)"
    }

    // MARK: - Formatters

    private func formatAppClip(_ clip: AppClip) -> String {
        let attrs = clip.attributes
        let bundleId = attrs?.bundleId ?? "?"
        return "  [\(clip.id)] Bundle ID: \(bundleId)"
    }

    private func formatAppClipDetailed(_ clip: AppClip) -> String {
        let attrs = clip.attributes
        let lines = [
            "App Clip Details",
            String(repeating: "-", count: 40),
            "  ID:        \(clip.id)",
            "  Bundle ID: \(attrs?.bundleId ?? "N/A")",
        ]
        return lines.joined(separator: "\n")
    }

    private func formatDefaultExperience(_ experience: AppClipDefaultExperience) -> String {
        let attrs = experience.attributes
        let action = attrs?.action ?? "?"
        return "  [\(experience.id)] Action: \(action)"
    }

    private func formatDefaultExperienceDetailed(_ experience: AppClipDefaultExperience) -> String {
        let attrs = experience.attributes
        let lines = [
            "App Clip Default Experience Details",
            String(repeating: "-", count: 40),
            "  ID:     \(experience.id)",
            "  Action: \(attrs?.action ?? "N/A")",
        ]
        return lines.joined(separator: "\n")
    }
}
