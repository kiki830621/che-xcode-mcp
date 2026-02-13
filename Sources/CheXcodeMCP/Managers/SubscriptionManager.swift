import Foundation
import MCP

// MARK: - ASC Attribute Models

struct SubscriptionGroupAttributes: Decodable {
    let referenceName: String?
}

struct SubscriptionAttributes: Decodable {
    let name: String?
    let productId: String?
    let familySharable: Bool?
    let state: String?
    let subscriptionPeriod: String?
    let reviewNote: String?
    let groupLevel: Int?
}

// MARK: - Type aliases

private typealias SubscriptionGroup = ASCResource<SubscriptionGroupAttributes>
private typealias Subscription = ASCResource<SubscriptionAttributes>

// MARK: - SubscriptionManager

actor SubscriptionManager: ToolProvider {
    private let client: ASCClient

    init(client: ASCClient) {
        self.client = client
    }

    // MARK: - ToolProvider

    var tools: [Tool] {
        [
            Tool(
                name: "subscription_list_groups",
                description: "List subscription groups for an app.",
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
                name: "subscription_get_group",
                description: "Get subscription group details.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "group_id": .object([
                            "type": "string",
                            "description": "The subscription group ID"
                        ])
                    ]),
                    "required": .array([.string("group_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "subscription_create_group",
                description: "Create a subscription group for an app.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "app_id": .object([
                            "type": "string",
                            "description": "The App Store Connect app ID"
                        ]),
                        "name": .object([
                            "type": "string",
                            "description": "The reference name for the subscription group"
                        ])
                    ]),
                    "required": .array([.string("app_id"), .string("name")])
                ]),
                annotations: .init(destructiveHint: false)
            ),
            Tool(
                name: "subscription_list_subscriptions",
                description: "List subscriptions in a subscription group.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "group_id": .object([
                            "type": "string",
                            "description": "The subscription group ID"
                        ])
                    ]),
                    "required": .array([.string("group_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "subscription_get_subscription",
                description: "Get subscription details.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "subscription_id": .object([
                            "type": "string",
                            "description": "The subscription ID"
                        ])
                    ]),
                    "required": .array([.string("subscription_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "subscription_create_subscription",
                description: "Create a subscription within a subscription group.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "group_id": .object([
                            "type": "string",
                            "description": "The subscription group ID to create the subscription in"
                        ]),
                        "name": .object([
                            "type": "string",
                            "description": "The display name of the subscription"
                        ]),
                        "product_id": .object([
                            "type": "string",
                            "description": "The product ID (reference name) for the subscription"
                        ]),
                        "family_sharable": .object([
                            "type": "boolean",
                            "description": "Whether the subscription is sharable with family (default false)"
                        ]),
                        "review_note": .object([
                            "type": "string",
                            "description": "Notes for the App Store reviewer"
                        ])
                    ]),
                    "required": .array([.string("group_id"), .string("name"), .string("product_id")])
                ]),
                annotations: .init(destructiveHint: false)
            ),
            Tool(
                name: "subscription_update_subscription",
                description: "Update a subscription's attributes.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "subscription_id": .object([
                            "type": "string",
                            "description": "The subscription ID to update"
                        ]),
                        "name": .object([
                            "type": "string",
                            "description": "New display name for the subscription"
                        ]),
                        "review_note": .object([
                            "type": "string",
                            "description": "Updated notes for the App Store reviewer"
                        ]),
                        "family_sharable": .object([
                            "type": "boolean",
                            "description": "Whether the subscription is sharable with family"
                        ])
                    ]),
                    "required": .array([.string("subscription_id")])
                ]),
                annotations: .init(destructiveHint: false)
            ),
        ]
    }

    func handle(_ name: String, arguments: [String: Value]) async throws -> String {
        switch name {
        case "subscription_list_groups":
            return try await handleListGroups(arguments)
        case "subscription_get_group":
            return try await handleGetGroup(arguments)
        case "subscription_create_group":
            return try await handleCreateGroup(arguments)
        case "subscription_list_subscriptions":
            return try await handleListSubscriptions(arguments)
        case "subscription_get_subscription":
            return try await handleGetSubscription(arguments)
        case "subscription_create_subscription":
            return try await handleCreateSubscription(arguments)
        case "subscription_update_subscription":
            return try await handleUpdateSubscription(arguments)
        default:
            throw ASCClientError.invalidResponse("Unknown Subscription tool: \(name)")
        }
    }

    // MARK: - Handler: List Groups

    private func handleListGroups(_ args: [String: Value]) async throws -> String {
        let appId = try requireString(args, "app_id")

        let queryItems = [
            URLQueryItem(name: "fields[subscriptionGroups]", value: "referenceName")
        ]

        let response: ASCListResponse<SubscriptionGroup> = try await client.getList(
            path: "/v1/apps/\(appId)/subscriptionGroups",
            queryItems: queryItems
        )

        if response.data.isEmpty {
            return "No subscription groups found for app \(appId)."
        }

        var lines = ["Subscription Groups (\(response.data.count)):"]
        lines.append(String(repeating: "-", count: 60))
        for group in response.data {
            lines.append(formatGroup(group))
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Handler: Get Group

    private func handleGetGroup(_ args: [String: Value]) async throws -> String {
        let groupId = try requireString(args, "group_id")

        let queryItems = [
            URLQueryItem(name: "fields[subscriptionGroups]", value: "referenceName")
        ]

        let response: ASCResponse<SubscriptionGroup> = try await client.get(
            path: "/v1/subscriptionGroups/\(groupId)",
            queryItems: queryItems
        )

        return formatGroupDetailed(response.data)
    }

    // MARK: - Handler: Create Group

    private func handleCreateGroup(_ args: [String: Value]) async throws -> String {
        let appId = try requireString(args, "app_id")
        let name = try requireString(args, "name")

        let body: [String: Any] = [
            "data": [
                "type": "subscriptionGroups",
                "attributes": [
                    "referenceName": name
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

        let response: ASCResponse<SubscriptionGroup> = try await client.post(
            path: "/v1/subscriptionGroups",
            body: body
        )

        let group = response.data
        let refName = group.attributes?.referenceName ?? name
        return "Successfully created subscription group '\(refName)' for app \(appId).\nGroup ID: \(group.id)"
    }

    // MARK: - Handler: List Subscriptions

    private func handleListSubscriptions(_ args: [String: Value]) async throws -> String {
        let groupId = try requireString(args, "group_id")

        let queryItems = [
            URLQueryItem(name: "fields[subscriptions]", value: "name,productId,familySharable,state,subscriptionPeriod,reviewNote,groupLevel")
        ]

        let response: ASCListResponse<Subscription> = try await client.getList(
            path: "/v1/subscriptionGroups/\(groupId)/subscriptions",
            queryItems: queryItems
        )

        if response.data.isEmpty {
            return "No subscriptions found in group \(groupId)."
        }

        var lines = ["Subscriptions in group \(groupId) (\(response.data.count)):"]
        lines.append(String(repeating: "-", count: 60))
        for subscription in response.data {
            lines.append(formatSubscription(subscription))
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Handler: Get Subscription

    private func handleGetSubscription(_ args: [String: Value]) async throws -> String {
        let subscriptionId = try requireString(args, "subscription_id")

        let queryItems = [
            URLQueryItem(name: "fields[subscriptions]", value: "name,productId,familySharable,state,subscriptionPeriod,reviewNote,groupLevel")
        ]

        let response: ASCResponse<Subscription> = try await client.get(
            path: "/v1/subscriptions/\(subscriptionId)",
            queryItems: queryItems
        )

        return formatSubscriptionDetailed(response.data)
    }

    // MARK: - Handler: Create Subscription

    private func handleCreateSubscription(_ args: [String: Value]) async throws -> String {
        let groupId = try requireString(args, "group_id")
        let name = try requireString(args, "name")
        let productId = try requireString(args, "product_id")

        var attributes: [String: Any] = [
            "name": name,
            "productId": productId
        ]

        if let familySharable = boolValue(args, "family_sharable") {
            attributes["familySharable"] = familySharable
        }
        if let reviewNote = stringValue(args, "review_note") {
            attributes["reviewNote"] = reviewNote
        }

        let body: [String: Any] = [
            "data": [
                "type": "subscriptions",
                "attributes": attributes,
                "relationships": [
                    "group": [
                        "data": [
                            "type": "subscriptionGroups",
                            "id": groupId
                        ]
                    ]
                ]
            ]
        ]

        let response: ASCResponse<Subscription> = try await client.post(
            path: "/v1/subscriptions",
            body: body
        )

        let subscription = response.data
        let displayName = subscription.attributes?.name ?? name
        return "Successfully created subscription '\(displayName)' (product: \(productId)) in group \(groupId).\nSubscription ID: \(subscription.id)"
    }

    // MARK: - Handler: Update Subscription

    private func handleUpdateSubscription(_ args: [String: Value]) async throws -> String {
        let subscriptionId = try requireString(args, "subscription_id")

        var attributes: [String: Any] = [:]
        if let name = stringValue(args, "name") {
            attributes["name"] = name
        }
        if let reviewNote = stringValue(args, "review_note") {
            attributes["reviewNote"] = reviewNote
        }
        if let familySharable = boolValue(args, "family_sharable") {
            attributes["familySharable"] = familySharable
        }

        if attributes.isEmpty {
            return "No updatable attributes provided. Updatable fields: name, review_note, family_sharable."
        }

        let body: [String: Any] = [
            "data": [
                "type": "subscriptions",
                "id": subscriptionId,
                "attributes": attributes
            ]
        ]

        let response: ASCResponse<Subscription> = try await client.patch(
            path: "/v1/subscriptions/\(subscriptionId)",
            body: body
        )

        var lines = ["Subscription updated successfully."]
        lines.append(String(repeating: "-", count: 60))
        lines.append(formatSubscriptionDetailed(response.data))
        return lines.joined(separator: "\n")
    }

    // MARK: - Formatters

    private func formatPeriod(_ period: String?) -> String {
        guard let period else { return "N/A" }
        switch period {
        case "ONE_WEEK": return "1 Week"
        case "ONE_MONTH": return "1 Month"
        case "TWO_MONTHS": return "2 Months"
        case "THREE_MONTHS": return "3 Months"
        case "SIX_MONTHS": return "6 Months"
        case "ONE_YEAR": return "1 Year"
        default: return period
        }
    }

    private func formatGroup(_ group: SubscriptionGroup) -> String {
        let refName = group.attributes?.referenceName ?? "Unnamed"
        return "  [\(group.id)] \(refName)"
    }

    private func formatGroupDetailed(_ group: SubscriptionGroup) -> String {
        let lines = [
            "Subscription Group Details",
            String(repeating: "-", count: 40),
            "  ID:              \(group.id)",
            "  Reference Name:  \(group.attributes?.referenceName ?? "N/A")",
        ]
        return lines.joined(separator: "\n")
    }

    private func formatSubscription(_ subscription: Subscription) -> String {
        let attrs = subscription.attributes
        let name = attrs?.name ?? "Unnamed"
        let productId = attrs?.productId ?? "?"
        let state = attrs?.state ?? "UNKNOWN"
        let period = formatPeriod(attrs?.subscriptionPeriod)
        let family = (attrs?.familySharable == true) ? " | Family: Yes" : ""
        return "  [\(subscription.id)] \(name) — \(productId) | \(state) | \(period)\(family)"
    }

    private func formatSubscriptionDetailed(_ subscription: Subscription) -> String {
        let attrs = subscription.attributes
        var lines = [
            "Subscription Details",
            String(repeating: "-", count: 40),
            "  ID:              \(subscription.id)",
            "  Name:            \(attrs?.name ?? "N/A")",
            "  Product ID:      \(attrs?.productId ?? "N/A")",
            "  State:           \(attrs?.state ?? "N/A")",
            "  Period:          \(formatPeriod(attrs?.subscriptionPeriod))",
            "  Family Sharable: \(attrs?.familySharable == true ? "Yes" : "No")",
        ]
        if let groupLevel = attrs?.groupLevel {
            lines.append("  Group Level:     \(groupLevel)")
        }
        if let reviewNote = attrs?.reviewNote, !reviewNote.isEmpty {
            lines.append("  Review Note:     \(reviewNote)")
        }
        return lines.joined(separator: "\n")
    }
}
