import Foundation
import MCP

// MARK: - ASC Attribute Models

struct BuildAttributes: Decodable {
    let version: String?
    let uploadedDate: Date?
    let processingState: String?
    let buildAudienceType: String?
    let minOsVersion: String?
    let expirationDate: Date?
}

struct BetaTesterAttributes: Decodable {
    let firstName: String?
    let lastName: String?
    let email: String?
    let inviteType: String?
    let state: String?
}

struct BetaGroupAttributes: Decodable {
    let name: String?
    let isInternalGroup: Bool?
    let publicLinkEnabled: Bool?
    let publicLinkLimit: Int?
    let publicLink: String?
    let feedbackEnabled: Bool?
}

struct BetaBuildLocalizationAttributes: Decodable {
    let whatsNew: String?
    let locale: String?
}

struct BetaAppReviewSubmissionAttributes: Decodable {
    let betaReviewState: String?
    let submittedDate: Date?
}

// MARK: - Type aliases

private typealias Build = ASCResource<BuildAttributes>
private typealias BetaTester = ASCResource<BetaTesterAttributes>
private typealias BetaGroup = ASCResource<BetaGroupAttributes>
private typealias BetaBuildLocalization = ASCResource<BetaBuildLocalizationAttributes>
private typealias BetaAppReviewSubmission = ASCResource<BetaAppReviewSubmissionAttributes>

// MARK: - TestFlightManager

actor TestFlightManager: ToolProvider {
    private let client: ASCClient

    init(client: ASCClient) {
        self.client = client
    }

    // MARK: - ToolProvider

    var tools: [Tool] {
        [
            Tool(
                name: "testflight_list_builds",
                description: "List TestFlight builds. Optionally filter by app_id and processing_state.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "app_id": .object([
                            "type": "string",
                            "description": "App Store Connect app ID to filter builds"
                        ]),
                        "processing_state": .object([
                            "type": "string",
                            "description": "Filter by processing state (PROCESSING, FAILED, INVALID, VALID)"
                        ]),
                        "limit": .object([
                            "type": "integer",
                            "description": "Maximum number of builds to return (default 20, max 200)"
                        ])
                    ])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "testflight_get_build",
                description: "Get detailed information about a specific TestFlight build.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "build_id": .object([
                            "type": "string",
                            "description": "The ASC build ID"
                        ])
                    ]),
                    "required": .array([.string("build_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "testflight_list_testers",
                description: "List beta testers. Optionally filter by email or beta group.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "email": .object([
                            "type": "string",
                            "description": "Filter testers by email address"
                        ]),
                        "group_id": .object([
                            "type": "string",
                            "description": "Beta group ID to list testers from"
                        ]),
                        "limit": .object([
                            "type": "integer",
                            "description": "Maximum number of testers to return (default 50, max 200)"
                        ])
                    ])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "testflight_add_tester",
                description: "Add a beta tester to a beta group by email. Creates the tester if they don't exist.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "email": .object([
                            "type": "string",
                            "description": "Email address of the tester to add"
                        ]),
                        "first_name": .object([
                            "type": "string",
                            "description": "First name of the tester"
                        ]),
                        "last_name": .object([
                            "type": "string",
                            "description": "Last name of the tester"
                        ]),
                        "group_id": .object([
                            "type": "string",
                            "description": "Beta group ID to add the tester to"
                        ])
                    ]),
                    "required": .array([.string("email"), .string("group_id")])
                ]),
                annotations: .init(destructiveHint: false, idempotentHint: true)
            ),
            Tool(
                name: "testflight_remove_tester",
                description: "Remove a beta tester from a beta group.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "tester_id": .object([
                            "type": "string",
                            "description": "Beta tester ID to remove"
                        ]),
                        "group_id": .object([
                            "type": "string",
                            "description": "Beta group ID to remove the tester from"
                        ])
                    ]),
                    "required": .array([.string("tester_id"), .string("group_id")])
                ]),
                annotations: .init(destructiveHint: true)
            ),
            Tool(
                name: "testflight_list_groups",
                description: "List beta groups. Optionally filter by app_id or internal/external type.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "app_id": .object([
                            "type": "string",
                            "description": "App Store Connect app ID to filter groups"
                        ]),
                        "is_internal": .object([
                            "type": "boolean",
                            "description": "Filter by internal (true) or external (false) groups"
                        ]),
                        "limit": .object([
                            "type": "integer",
                            "description": "Maximum number of groups to return (default 50, max 200)"
                        ])
                    ])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "testflight_list_feedback",
                description: "List beta app review submissions (feedback) for a specific build.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "build_id": .object([
                            "type": "string",
                            "description": "The build ID to get feedback for"
                        ])
                    ]),
                    "required": .array([.string("build_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "testflight_submit_for_review",
                description: "Submit a build for external beta testing review.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "build_id": .object([
                            "type": "string",
                            "description": "The build ID to submit for review"
                        ])
                    ]),
                    "required": .array([.string("build_id")])
                ]),
                annotations: .init(destructiveHint: false, idempotentHint: true)
            ),
            Tool(
                name: "testflight_set_whats_new",
                description: "Set the 'What to Test' text for a build localization.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "build_id": .object([
                            "type": "string",
                            "description": "The build ID to set What to Test for"
                        ]),
                        "whats_new": .object([
                            "type": "string",
                            "description": "The 'What to Test' text content"
                        ]),
                        "locale": .object([
                            "type": "string",
                            "description": "Locale code (default: en-US)"
                        ])
                    ]),
                    "required": .array([.string("build_id"), .string("whats_new")])
                ])
            ),
        ]
    }

    func handle(_ name: String, arguments: [String: Value]) async throws -> String {
        switch name {
        case "testflight_list_builds":
            return try await handleListBuilds(arguments)
        case "testflight_get_build":
            return try await handleGetBuild(arguments)
        case "testflight_list_testers":
            return try await handleListTesters(arguments)
        case "testflight_add_tester":
            return try await handleAddTester(arguments)
        case "testflight_remove_tester":
            return try await handleRemoveTester(arguments)
        case "testflight_list_groups":
            return try await handleListGroups(arguments)
        case "testflight_list_feedback":
            return try await handleListFeedback(arguments)
        case "testflight_submit_for_review":
            return try await handleSubmitForReview(arguments)
        case "testflight_set_whats_new":
            return try await handleSetWhatsNew(arguments)
        default:
            throw ASCClientError.invalidResponse("Unknown TestFlight tool: \(name)")
        }
    }

    // MARK: - Handler: List Builds

    private func handleListBuilds(_ args: [String: Value]) async throws -> String {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "fields[builds]", value: "version,uploadedDate,processingState,buildAudienceType,minOsVersion,expirationDate"),
            URLQueryItem(name: "sort", value: "-uploadedDate"),
        ]

        if let appId = stringValue(args, "app_id") {
            queryItems.append(URLQueryItem(name: "filter[app]", value: appId))
        }
        if let state = stringValue(args, "processing_state") {
            queryItems.append(URLQueryItem(name: "filter[processingState]", value: state))
        }
        let limit = intValue(args, "limit") ?? 20
        queryItems.append(URLQueryItem(name: "limit", value: String(min(limit, 200))))

        let response: ASCListResponse<Build> = try await client.getList(
            path: "/v1/builds",
            queryItems: queryItems
        )

        if response.data.isEmpty {
            return "No builds found."
        }

        var lines = ["TestFlight Builds (\(response.data.count)):"]
        lines.append(String(repeating: "-", count: 60))
        for build in response.data {
            lines.append(formatBuild(build))
        }

        if let paging = response.meta?.paging, let total = paging.total {
            lines.append("\nShowing \(response.data.count) of \(total) total builds.")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Handler: Get Build

    private func handleGetBuild(_ args: [String: Value]) async throws -> String {
        let buildId = try requireString(args, "build_id")

        let queryItems = [
            URLQueryItem(name: "fields[builds]", value: "version,uploadedDate,processingState,buildAudienceType,minOsVersion,expirationDate")
        ]

        let response: ASCResponse<Build> = try await client.get(
            path: "/v1/builds/\(buildId)",
            queryItems: queryItems
        )

        return formatBuildDetailed(response.data)
    }

    // MARK: - Handler: List Testers

    private func handleListTesters(_ args: [String: Value]) async throws -> String {
        let limit = intValue(args, "limit") ?? 50

        // If a group_id is provided, list testers within that group
        if let groupId = stringValue(args, "group_id") {
            var queryItems: [URLQueryItem] = [
                URLQueryItem(name: "fields[betaTesters]", value: "firstName,lastName,email,inviteType,state"),
                URLQueryItem(name: "limit", value: String(min(limit, 200))),
            ]

            if let email = stringValue(args, "email") {
                queryItems.append(URLQueryItem(name: "filter[email]", value: email))
            }

            let response: ASCListResponse<BetaTester> = try await client.getList(
                path: "/v1/betaGroups/\(groupId)/betaTesters",
                queryItems: queryItems
            )

            if response.data.isEmpty {
                return "No testers found in group \(groupId)."
            }

            var lines = ["Beta Testers in group \(groupId) (\(response.data.count)):"]
            lines.append(String(repeating: "-", count: 60))
            for tester in response.data {
                lines.append(formatTester(tester))
            }
            return lines.joined(separator: "\n")
        }

        // Otherwise, list all testers (optionally filtered by email)
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "fields[betaTesters]", value: "firstName,lastName,email,inviteType,state"),
            URLQueryItem(name: "limit", value: String(min(limit, 200))),
        ]

        if let email = stringValue(args, "email") {
            queryItems.append(URLQueryItem(name: "filter[email]", value: email))
        }

        let response: ASCListResponse<BetaTester> = try await client.getList(
            path: "/v1/betaTesters",
            queryItems: queryItems
        )

        if response.data.isEmpty {
            return "No testers found."
        }

        var lines = ["Beta Testers (\(response.data.count)):"]
        lines.append(String(repeating: "-", count: 60))
        for tester in response.data {
            lines.append(formatTester(tester))
        }

        if let paging = response.meta?.paging, let total = paging.total {
            lines.append("\nShowing \(response.data.count) of \(total) total testers.")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Handler: Add Tester

    private func handleAddTester(_ args: [String: Value]) async throws -> String {
        let email = try requireString(args, "email")
        let groupId = try requireString(args, "group_id")
        let firstName = stringValue(args, "first_name")
        let lastName = stringValue(args, "last_name")

        var attributes: [String: Any] = ["email": email]
        if let firstName { attributes["firstName"] = firstName }
        if let lastName { attributes["lastName"] = lastName }

        let body: [String: Any] = [
            "data": [
                "type": "betaTesters",
                "attributes": attributes,
                "relationships": [
                    "betaGroups": [
                        "data": [
                            ["type": "betaGroups", "id": groupId]
                        ]
                    ]
                ]
            ]
        ]

        let response: ASCResponse<BetaTester> = try await client.post(
            path: "/v1/betaTesters",
            body: body
        )

        let tester = response.data
        let name = [tester.attributes?.firstName, tester.attributes?.lastName]
            .compactMap { $0 }
            .joined(separator: " ")
        let displayName = name.isEmpty ? email : "\(name) (\(email))"

        return "Successfully added tester \(displayName) to beta group \(groupId).\nTester ID: \(tester.id)"
    }

    // MARK: - Handler: Remove Tester

    private func handleRemoveTester(_ args: [String: Value]) async throws -> String {
        let testerId = try requireString(args, "tester_id")
        let groupId = try requireString(args, "group_id")

        let body: [String: Any] = [
            "data": [
                ["type": "betaTesters", "id": testerId]
            ]
        ]

        try await client.deleteWithBody(
            path: "/v1/betaGroups/\(groupId)/relationships/betaTesters",
            body: body
        )

        return "Successfully removed tester \(testerId) from beta group \(groupId)."
    }

    // MARK: - Handler: List Groups

    private func handleListGroups(_ args: [String: Value]) async throws -> String {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "fields[betaGroups]", value: "name,isInternalGroup,publicLinkEnabled,publicLinkLimit,publicLink,feedbackEnabled"),
        ]

        if let appId = stringValue(args, "app_id") {
            queryItems.append(URLQueryItem(name: "filter[app]", value: appId))
        }
        if let isInternal = boolValue(args, "is_internal") {
            queryItems.append(URLQueryItem(name: "filter[isInternalGroup]", value: isInternal ? "true" : "false"))
        }
        let limit = intValue(args, "limit") ?? 50
        queryItems.append(URLQueryItem(name: "limit", value: String(min(limit, 200))))

        let response: ASCListResponse<BetaGroup> = try await client.getList(
            path: "/v1/betaGroups",
            queryItems: queryItems
        )

        if response.data.isEmpty {
            return "No beta groups found."
        }

        var lines = ["Beta Groups (\(response.data.count)):"]
        lines.append(String(repeating: "-", count: 60))
        for group in response.data {
            lines.append(formatGroup(group))
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Handler: List Feedback

    private func handleListFeedback(_ args: [String: Value]) async throws -> String {
        let buildId = try requireString(args, "build_id")

        let response: ASCListResponse<BetaAppReviewSubmission> = try await client.getList(
            path: "/v1/builds/\(buildId)/betaAppReviewSubmissions"
        )

        if response.data.isEmpty {
            return "No beta review submissions found for build \(buildId)."
        }

        var lines = ["Beta Review Submissions for build \(buildId) (\(response.data.count)):"]
        lines.append(String(repeating: "-", count: 60))
        for submission in response.data {
            lines.append(formatReviewSubmission(submission))
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Handler: Submit for Review

    private func handleSubmitForReview(_ args: [String: Value]) async throws -> String {
        let buildId = try requireString(args, "build_id")

        let body: [String: Any] = [
            "data": [
                "type": "betaAppReviewSubmissions",
                "relationships": [
                    "build": [
                        "data": [
                            "type": "builds",
                            "id": buildId
                        ]
                    ]
                ]
            ]
        ]

        let response: ASCResponse<BetaAppReviewSubmission> = try await client.post(
            path: "/v1/betaAppReviewSubmissions",
            body: body
        )

        let state = response.data.attributes?.betaReviewState ?? "UNKNOWN"
        return "Build \(buildId) submitted for external beta review.\nSubmission ID: \(response.data.id)\nReview state: \(state)"
    }

    // MARK: - Handler: Set What's New

    private func handleSetWhatsNew(_ args: [String: Value]) async throws -> String {
        let buildId = try requireString(args, "build_id")
        let whatsNew = try requireString(args, "whats_new")
        let locale = stringValue(args, "locale") ?? "en-US"

        let body: [String: Any] = [
            "data": [
                "type": "betaBuildLocalizations",
                "attributes": [
                    "whatsNew": whatsNew,
                    "locale": locale
                ],
                "relationships": [
                    "build": [
                        "data": [
                            "type": "builds",
                            "id": buildId
                        ]
                    ]
                ]
            ]
        ]

        let response: ASCResponse<BetaBuildLocalization> = try await client.post(
            path: "/v1/betaBuildLocalizations",
            body: body
        )

        let savedLocale = response.data.attributes?.locale ?? locale
        return "Set 'What to Test' for build \(buildId) (locale: \(savedLocale)):\n\(whatsNew)"
    }

    // MARK: - Argument Helpers

    private func requireString(_ args: [String: Value], _ key: String) throws -> String {
        guard let value = args[key]?.stringValue else {
            throw ASCClientError.missingParameter(key)
        }
        return value
    }

    private func stringValue(_ args: [String: Value], _ key: String) -> String? {
        args[key]?.stringValue
    }

    private func intValue(_ args: [String: Value], _ key: String) -> Int? {
        if let v = args[key] {
            return Int(v, strict: false)
        }
        return nil
    }

    private func boolValue(_ args: [String: Value], _ key: String) -> Bool? {
        if let v = args[key] {
            return Bool(v, strict: false)
        }
        return nil
    }

    // MARK: - Formatters

    private static let displayDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private func formatDate(_ date: Date?) -> String {
        guard let date else { return "N/A" }
        return Self.displayDateFormatter.string(from: date)
    }

    private func formatBuild(_ build: Build) -> String {
        let attrs = build.attributes
        let version = attrs?.version ?? "?"
        let state = attrs?.processingState ?? "UNKNOWN"
        let uploaded = formatDate(attrs?.uploadedDate)
        let audience = attrs?.buildAudienceType ?? "?"
        return "  [\(build.id)] v\(version) — \(state) | \(audience) | Uploaded: \(uploaded)"
    }

    private func formatBuildDetailed(_ build: Build) -> String {
        let attrs = build.attributes
        var lines = [
            "Build Details",
            String(repeating: "-", count: 40),
            "  ID:               \(build.id)",
            "  Version:          \(attrs?.version ?? "N/A")",
            "  Processing State: \(attrs?.processingState ?? "N/A")",
            "  Audience Type:    \(attrs?.buildAudienceType ?? "N/A")",
            "  Min OS Version:   \(attrs?.minOsVersion ?? "N/A")",
            "  Uploaded:         \(formatDate(attrs?.uploadedDate))",
        ]
        if let expiry = attrs?.expirationDate {
            lines.append("  Expires:          \(formatDate(expiry))")
        }
        return lines.joined(separator: "\n")
    }

    private func formatTester(_ tester: BetaTester) -> String {
        let attrs = tester.attributes
        let name = [attrs?.firstName, attrs?.lastName]
            .compactMap { $0 }
            .joined(separator: " ")
        let email = attrs?.email ?? "?"
        let state = attrs?.state ?? "UNKNOWN"
        let invite = attrs?.inviteType ?? "?"
        let displayName = name.isEmpty ? email : "\(name) <\(email)>"
        return "  [\(tester.id)] \(displayName) — \(state) (\(invite))"
    }

    private func formatGroup(_ group: BetaGroup) -> String {
        let attrs = group.attributes
        let name = attrs?.name ?? "Unnamed"
        let type = (attrs?.isInternalGroup == true) ? "Internal" : "External"
        var details = "  [\(group.id)] \(name) — \(type)"
        if attrs?.publicLinkEnabled == true {
            details += " | Public link: ON"
            if let limit = attrs?.publicLinkLimit {
                details += " (limit: \(limit))"
            }
        }
        if attrs?.feedbackEnabled == true {
            details += " | Feedback: ON"
        }
        return details
    }

    private func formatReviewSubmission(_ submission: BetaAppReviewSubmission) -> String {
        let attrs = submission.attributes
        let state = attrs?.betaReviewState ?? "UNKNOWN"
        let submitted = formatDate(attrs?.submittedDate)
        return "  [\(submission.id)] State: \(state) | Submitted: \(submitted)"
    }
}
