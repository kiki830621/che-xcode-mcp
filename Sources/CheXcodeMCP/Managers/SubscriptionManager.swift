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

struct SubscriptionLocalizationAttributes: Decodable {
    let locale: String?
    let name: String?
    let description: String?
}

struct SubscriptionPriceAttributes: Decodable {
    let startDate: String?
    let preserved: Bool?
}

struct SubscriptionPricePointAttributes: Decodable {
    let customerPrice: String?
    let proceeds: String?
}

// MARK: - Type aliases

private typealias SubscriptionGroup = ASCResource<SubscriptionGroupAttributes>
private typealias Subscription = ASCResource<SubscriptionAttributes>
private typealias SubscriptionLocalization = ASCResource<SubscriptionLocalizationAttributes>
private typealias SubscriptionPrice = ASCResource<SubscriptionPriceAttributes>
private typealias SubscriptionPricePoint = ASCResource<SubscriptionPricePointAttributes>

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
            Tool(
                name: "subscription_list_localizations",
                description: "List all language versions (localizations) of a subscription. Shows display name and description for each locale.",
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
                name: "subscription_update_localization",
                description: "Update the display name and/or description for a specific subscription localization.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "localization_id": .object([
                            "type": "string",
                            "description": "The subscription localization ID (get from subscription_list_localizations)"
                        ]),
                        "name": .object([
                            "type": "string",
                            "description": "Updated display name shown to users"
                        ]),
                        "description": .object([
                            "type": "string",
                            "description": "Updated description shown to users"
                        ])
                    ]),
                    "required": .array([.string("localization_id")])
                ]),
                annotations: .init(destructiveHint: false)
            ),
            Tool(
                name: "subscription_create_localization",
                description: "Add a new language version for a subscription.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "subscription_id": .object([
                            "type": "string",
                            "description": "The subscription ID to add a localization to"
                        ]),
                        "locale": .object([
                            "type": "string",
                            "description": "Locale code (e.g. \"en-US\", \"zh-Hant\", \"ja\")"
                        ]),
                        "name": .object([
                            "type": "string",
                            "description": "Display name for this locale"
                        ]),
                        "description": .object([
                            "type": "string",
                            "description": "Description for this locale"
                        ])
                    ]),
                    "required": .array([.string("subscription_id"), .string("locale"), .string("name")])
                ]),
                annotations: .init(destructiveHint: false)
            ),
            Tool(
                name: "subscription_list_prices",
                description: "List subscription prices across territories. Shows price, territory, and start date.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "subscription_id": .object([
                            "type": "string",
                            "description": "The subscription ID"
                        ]),
                        "limit": .object([
                            "type": "integer",
                            "description": "Maximum number of prices to return (default 200, max 200)"
                        ])
                    ]),
                    "required": .array([.string("subscription_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "subscription_list_price_points",
                description: "List available price points for a subscription. Optionally filter by territory.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "subscription_id": .object([
                            "type": "string",
                            "description": "The subscription ID"
                        ]),
                        "territory": .object([
                            "type": "string",
                            "description": "Filter by territory ID (e.g. \"USA\", \"TWN\")"
                        ]),
                        "limit": .object([
                            "type": "integer",
                            "description": "Maximum number of price points to return (default 200, max 200)"
                        ])
                    ]),
                    "required": .array([.string("subscription_id")])
                ]),
                annotations: .init(readOnlyHint: true)
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
        case "subscription_list_localizations":
            return try await handleListLocalizations(arguments)
        case "subscription_update_localization":
            return try await handleUpdateLocalization(arguments)
        case "subscription_create_localization":
            return try await handleCreateLocalization(arguments)
        case "subscription_list_prices":
            return try await handleListPrices(arguments)
        case "subscription_list_price_points":
            return try await handleListPricePoints(arguments)
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

    // MARK: - Handler: List Localizations

    private func handleListLocalizations(_ args: [String: Value]) async throws -> String {
        let subscriptionId = try requireString(args, "subscription_id")

        let queryItems = [
            URLQueryItem(name: "fields[subscriptionLocalizations]", value: "locale,name,description"),
            URLQueryItem(name: "limit", value: "200"),
        ]

        let response: ASCListResponse<SubscriptionLocalization> = try await client.getList(
            path: "/v1/subscriptions/\(subscriptionId)/subscriptionLocalizations",
            queryItems: queryItems
        )

        if response.data.isEmpty {
            return "No localizations found for subscription \(subscriptionId)."
        }

        var lines = ["Subscription Localizations (\(response.data.count)):"]
        lines.append(String(repeating: "-", count: 60))
        for localization in response.data {
            lines.append(formatLocalization(localization))
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Handler: Update Localization

    private func handleUpdateLocalization(_ args: [String: Value]) async throws -> String {
        let localizationId = try requireString(args, "localization_id")

        var attributes: [String: Any] = [:]
        if let name = stringValue(args, "name") {
            attributes["name"] = name
        }
        if let description = stringValue(args, "description") {
            attributes["description"] = description
        }

        if attributes.isEmpty {
            return "No updatable attributes provided. Updatable fields: name, description."
        }

        let body: [String: Any] = [
            "data": [
                "type": "subscriptionLocalizations",
                "id": localizationId,
                "attributes": attributes
            ]
        ]

        let response: ASCResponse<SubscriptionLocalization> = try await client.patch(
            path: "/v1/subscriptionLocalizations/\(localizationId)",
            body: body
        )

        let loc = response.data
        let locale = loc.attributes?.locale ?? "?"
        let name = loc.attributes?.name ?? "N/A"
        return "Successfully updated localization \(localizationId) [\(locale)].\nName: \(name)"
    }

    // MARK: - Handler: Create Localization

    private func handleCreateLocalization(_ args: [String: Value]) async throws -> String {
        let subscriptionId = try requireString(args, "subscription_id")
        let locale = try requireString(args, "locale")
        let name = try requireString(args, "name")

        var attributes: [String: Any] = [
            "locale": locale,
            "name": name,
        ]
        if let description = stringValue(args, "description") {
            attributes["description"] = description
        }

        let body: [String: Any] = [
            "data": [
                "type": "subscriptionLocalizations",
                "attributes": attributes,
                "relationships": [
                    "subscription": [
                        "data": [
                            "type": "subscriptions",
                            "id": subscriptionId
                        ]
                    ]
                ]
            ]
        ]

        let response: ASCResponse<SubscriptionLocalization> = try await client.post(
            path: "/v1/subscriptionLocalizations",
            body: body
        )

        let loc = response.data
        return "Successfully created localization for subscription \(subscriptionId).\nLocalization ID: \(loc.id)\nLocale: \(locale)\nName: \(name)"
    }

    // MARK: - Handler: List Prices

    private func handleListPrices(_ args: [String: Value]) async throws -> String {
        let subscriptionId = try requireString(args, "subscription_id")
        let limit = intValue(args, "limit") ?? 200

        let queryItems = [
            URLQueryItem(name: "include", value: "subscriptionPricePoint,territory"),
            URLQueryItem(name: "limit", value: String(min(limit, 200))),
        ]

        let response: ASCListResponse<SubscriptionPrice> = try await client.getList(
            path: "/v1/subscriptions/\(subscriptionId)/prices",
            queryItems: queryItems
        )

        if response.data.isEmpty {
            return "No prices found for subscription \(subscriptionId)."
        }

        // Build lookup maps from included resources
        var pricePointMap: [String: (price: String, proceeds: String)] = [:]
        var territoryMap: [String: String] = [:]

        if let included = response.included {
            for resource in included {
                if resource.type == "subscriptionPricePoints" {
                    let price = resource.attributes?["customerPrice"]?.value as? String ?? "?"
                    let proceeds = resource.attributes?["proceeds"]?.value as? String ?? "?"
                    pricePointMap[resource.id] = (price: price, proceeds: proceeds)
                } else if resource.type == "territories" {
                    let currency = resource.attributes?["currency"]?.value as? String ?? "?"
                    territoryMap[resource.id] = currency
                }
            }
        }

        var lines = ["Subscription Prices (\(response.data.count)):"]
        lines.append(String(repeating: "-", count: 60))
        lines.append("  " + "Price".padding(toLength: 10, withPad: " ", startingAt: 0) + " " + "Proceeds".padding(toLength: 10, withPad: " ", startingAt: 0) + " Territory   Start Date")
        lines.append("  " + String(repeating: "-", count: 55))

        for price in response.data {
            lines.append(formatPrice(price, pricePointMap: pricePointMap, territoryMap: territoryMap))
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Handler: List Price Points

    private func handleListPricePoints(_ args: [String: Value]) async throws -> String {
        let subscriptionId = try requireString(args, "subscription_id")
        let limit = intValue(args, "limit") ?? 200

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "fields[subscriptionPricePoints]", value: "customerPrice,proceeds"),
            URLQueryItem(name: "include", value: "territory"),
            URLQueryItem(name: "limit", value: String(min(limit, 200))),
        ]

        if let territory = stringValue(args, "territory") {
            queryItems.append(URLQueryItem(name: "filter[territory]", value: territory))
        }

        let response: ASCListResponse<SubscriptionPricePoint> = try await client.getList(
            path: "/v1/subscriptions/\(subscriptionId)/pricePoints",
            queryItems: queryItems
        )

        if response.data.isEmpty {
            return "No price points found for subscription \(subscriptionId)."
        }

        // Build territory lookup from included resources
        var territoryMap: [String: String] = [:]
        if let included = response.included {
            for resource in included where resource.type == "territories" {
                let currency = resource.attributes?["currency"]?.value as? String ?? "?"
                territoryMap[resource.id] = currency
            }
        }

        var lines = ["Subscription Price Points (\(response.data.count)):"]
        lines.append(String(repeating: "-", count: 60))
        lines.append("  " + "Price".padding(toLength: 10, withPad: " ", startingAt: 0) + " " + "Proceeds".padding(toLength: 10, withPad: " ", startingAt: 0) + " Territory")
        lines.append("  " + String(repeating: "-", count: 50))

        for point in response.data {
            let price = point.attributes?.customerPrice ?? "N/A"
            let proceeds = point.attributes?.proceeds ?? "N/A"

            var territory = "?"
            if let relationships = point.relationships,
               let territoryRel = relationships["territory"],
               case .single(let identifier) = territoryRel.data {
                let currency = territoryMap[identifier.id] ?? ""
                territory = currency.isEmpty ? identifier.id : "\(identifier.id) (\(currency))"
            }

            let paddedPrice = price.padding(toLength: 10, withPad: " ", startingAt: 0)
            let paddedProceeds = proceeds.padding(toLength: 10, withPad: " ", startingAt: 0)
            lines.append("  \(paddedPrice) \(paddedProceeds) \(territory)")
        }

        if let paging = response.meta?.paging, let total = paging.total {
            lines.append(String(repeating: "-", count: 60))
            lines.append("Showing \(response.data.count) of \(total) total price points.")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Formatters

    private func formatLocalization(_ loc: SubscriptionLocalization) -> String {
        let attrs = loc.attributes
        let locale = attrs?.locale ?? "?"
        let name = attrs?.name ?? "N/A"
        let description = attrs?.description ?? "N/A"
        let truncatedDesc = description.count > 80 ? String(description.prefix(77)) + "..." : description
        return "  [\(loc.id)] \(locale) — \(name)\n    Description: \(truncatedDesc)"
    }

    private func formatPrice(_ price: SubscriptionPrice, pricePointMap: [String: (price: String, proceeds: String)], territoryMap: [String: String]) -> String {
        let startDate = price.attributes?.startDate ?? "N/A"

        // Resolve price point and territory from relationships
        var customerPrice = "?"
        var proceeds = "?"
        var territory = "?"

        if let relationships = price.relationships {
            if let ppRel = relationships["subscriptionPricePoint"],
               case .single(let ppId) = ppRel.data,
               let pp = pricePointMap[ppId.id] {
                customerPrice = pp.price
                proceeds = pp.proceeds
            }
            if let tRel = relationships["territory"],
               case .single(let tId) = tRel.data {
                let currency = territoryMap[tId.id] ?? ""
                territory = currency.isEmpty ? tId.id : "\(tId.id) (\(currency))"
            }
        }

        let paddedPrice = customerPrice.padding(toLength: 10, withPad: " ", startingAt: 0)
        let paddedProceeds = proceeds.padding(toLength: 10, withPad: " ", startingAt: 0)
        let paddedTerritory = territory.padding(toLength: 12, withPad: " ", startingAt: 0)
        return "  \(paddedPrice) \(paddedProceeds) \(paddedTerritory) \(startDate)"
    }

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
