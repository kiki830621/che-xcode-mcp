import Foundation
import MCP

// MARK: - ASC Attribute Models

struct TerritoryAttributes: Decodable {
    let currency: String?
}

struct AppPricePointAttributes: Decodable {
    let customerPrice: String?
    let proceeds: String?
}

struct AppPriceScheduleAttributes: Decodable {
    // minimal — most data is in relationships
}

struct AppAvailabilityAttributes: Decodable {
    let availableInNewTerritories: Bool?
}

// MARK: - Type aliases

private typealias Territory = ASCResource<TerritoryAttributes>
private typealias AppPricePoint = ASCResource<AppPricePointAttributes>
private typealias AppPriceSchedule = ASCResource<AppPriceScheduleAttributes>
private typealias AppAvailability = ASCResource<AppAvailabilityAttributes>

// MARK: - PricingManager

actor PricingManager: ToolProvider {
    private let client: ASCClient

    init(client: ASCClient) {
        self.client = client
    }

    // MARK: - ToolProvider

    var tools: [Tool] {
        [
            Tool(
                name: "pricing_list_territories",
                description: "List all available App Store territories.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "limit": .object([
                            "type": "integer",
                            "description": "Maximum number of territories to return (default 200, max 200)"
                        ])
                    ])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "pricing_get_app_prices",
                description: "Get app pricing schedule information including price tiers.",
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
                name: "pricing_list_price_points",
                description: "List available price points for an app. Optionally filter by territory.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "app_id": .object([
                            "type": "string",
                            "description": "The App Store Connect app ID"
                        ]),
                        "territory": .object([
                            "type": "string",
                            "description": "Filter by territory ID (e.g. \"USA\", \"TWN\")"
                        ])
                    ]),
                    "required": .array([.string("app_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "pricing_get_availability",
                description: "Get app availability and territory distribution information.",
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
        ]
    }

    func handle(_ name: String, arguments: [String: Value]) async throws -> String {
        switch name {
        case "pricing_list_territories":
            return try await handleListTerritories(arguments)
        case "pricing_get_app_prices":
            return try await handleGetAppPrices(arguments)
        case "pricing_list_price_points":
            return try await handleListPricePoints(arguments)
        case "pricing_get_availability":
            return try await handleGetAvailability(arguments)
        default:
            throw ASCClientError.invalidResponse("Unknown pricing tool: \(name)")
        }
    }

    // MARK: - Handler: List Territories

    private func handleListTerritories(_ args: [String: Value]) async throws -> String {
        let limit = intValue(args, "limit") ?? 200
        let queryItems = [
            URLQueryItem(name: "limit", value: String(min(limit, 200))),
        ]

        let response: ASCListResponse<Territory> = try await client.getList(
            path: "/v1/territories",
            queryItems: queryItems
        )

        if response.data.isEmpty {
            return "No territories found."
        }

        var lines = ["App Store Territories (\(response.data.count)):"]
        lines.append(String(repeating: "-", count: 60))

        // Compact multi-column display
        let columns = 4
        let entries = response.data.map { territory -> String in
            let currency = territory.attributes?.currency ?? "---"
            let paddedId = territory.id.padding(toLength: 5, withPad: " ", startingAt: 0)
            return "\(paddedId) (\(currency))"
        }

        var row: [String] = []
        for (index, entry) in entries.enumerated() {
            row.append(entry)
            if row.count == columns || index == entries.count - 1 {
                lines.append("  " + row.joined(separator: "  |  "))
                row = []
            }
        }

        if let paging = response.meta?.paging, let total = paging.total {
            lines.append(String(repeating: "-", count: 60))
            lines.append("Showing \(response.data.count) of \(total) total territories.")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Handler: Get App Prices

    private func handleGetAppPrices(_ args: [String: Value]) async throws -> String {
        let appId = try requireString(args, "app_id")

        let queryItems = [
            URLQueryItem(name: "include", value: "manualPrices,automaticPrices,baseTerritory"),
        ]

        let response: ASCResponse<AppPriceSchedule> = try await client.get(
            path: "/v1/apps/\(appId)/appPriceSchedule",
            queryItems: queryItems
        )

        var lines = [
            "App Price Schedule",
            String(repeating: "-", count: 60),
            "  App ID:      \(appId)",
            "  Schedule ID: \(response.data.id)",
        ]

        // Show included resources (manual prices, automatic prices, base territory)
        if let included = response.included, !included.isEmpty {
            let territories = included.filter { $0.type == "territories" }
            let otherResources = included.filter { $0.type != "territories" }

            if !otherResources.isEmpty {
                lines.append("")
                lines.append("  Price Resources (\(otherResources.count)):")
                lines.append("  " + String(repeating: "-", count: 40))
                for resource in otherResources {
                    let price = resource.attributes?["customerPrice"]?.value as? String
                    let proceeds = resource.attributes?["proceeds"]?.value as? String
                    var desc = "    [\(resource.id)] (\(resource.type))"
                    if let price { desc += " | Price: \(price)" }
                    if let proceeds { desc += " | Proceeds: \(proceeds)" }
                    lines.append(desc)
                }
            }

            if !territories.isEmpty {
                lines.append("")
                lines.append("  Base Territory: \(territories.map(\.id).joined(separator: ", "))")
            }
        }

        // Show relationships
        if let relationships = response.data.relationships {
            for (key, rel) in relationships {
                if case .many(let identifiers) = rel.data, !identifiers.isEmpty {
                    lines.append("")
                    lines.append("  \(key): \(identifiers.count) items")
                } else if case .single(let identifier) = rel.data {
                    lines.append("  \(key): \(identifier.id)")
                }
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Handler: List Price Points

    private func handleListPricePoints(_ args: [String: Value]) async throws -> String {
        let appId = try requireString(args, "app_id")

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "fields[appPricePoints]", value: "customerPrice,proceeds"),
            URLQueryItem(name: "include", value: "territory"),
            URLQueryItem(name: "limit", value: "200"),
        ]

        if let territory = stringValue(args, "territory") {
            queryItems.append(URLQueryItem(name: "filter[territory]", value: territory))
        }

        let response: ASCListResponse<AppPricePoint> = try await client.getList(
            path: "/v1/apps/\(appId)/appPricePoints",
            queryItems: queryItems
        )

        if response.data.isEmpty {
            return "No price points found for app \(appId)."
        }

        // Build territory lookup from included resources
        var territoryMap: [String: String] = [:]
        if let included = response.included {
            for resource in included where resource.type == "territories" {
                let currency = resource.attributes?["currency"]?.value as? String ?? "?"
                territoryMap[resource.id] = currency
            }
        }

        var lines = ["Price Points for app \(appId) (\(response.data.count)):"]
        lines.append(String(repeating: "-", count: 60))
        lines.append("  " + "Price".padding(toLength: 10, withPad: " ", startingAt: 0) + " " + "Proceeds".padding(toLength: 10, withPad: " ", startingAt: 0) + " Territory")
        lines.append("  " + String(repeating: "-", count: 50))

        for point in response.data {
            lines.append(formatPricePoint(point, territoryMap: territoryMap))
        }

        if let paging = response.meta?.paging, let total = paging.total {
            lines.append(String(repeating: "-", count: 60))
            lines.append("Showing \(response.data.count) of \(total) total price points.")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Handler: Get Availability

    private func handleGetAvailability(_ args: [String: Value]) async throws -> String {
        let appId = try requireString(args, "app_id")

        let queryItems = [
            URLQueryItem(name: "include", value: "territoryAvailabilities"),
            URLQueryItem(name: "limit[territoryAvailabilities]", value: "50"),
        ]

        let response: ASCResponse<AppAvailability> = try await client.get(
            path: "/v1/apps/\(appId)/appAvailabilityV2",
            queryItems: queryItems
        )

        let availability = response.data
        let availableInNew = availability.attributes?.availableInNewTerritories == true ? "Yes" : "No"

        var lines = [
            "App Availability",
            String(repeating: "-", count: 60),
            "  App ID:                        \(appId)",
            "  Availability ID:               \(availability.id)",
            "  Available in new territories:  \(availableInNew)",
        ]

        // Show territory availabilities from included resources
        if let included = response.included {
            let territoryAvailabilities = included.filter { $0.type == "territoryAvailabilities" }
            if !territoryAvailabilities.isEmpty {
                let available = territoryAvailabilities.filter {
                    ($0.attributes?["available"]?.value as? Bool) == true
                }
                lines.append("")
                lines.append("  Territory Availabilities: \(available.count) available of \(territoryAvailabilities.count) total")
            }

            let territories = included.filter { $0.type == "territories" }
            if !territories.isEmpty {
                lines.append("")
                lines.append("  Territories (\(territories.count)):")
                lines.append("  " + String(repeating: "-", count: 40))

                let columns = 5
                let codes = territories.map { $0.id }

                var row: [String] = []
                for (index, code) in codes.enumerated() {
                    row.append(code.padding(toLength: 5, withPad: " ", startingAt: 0))
                    if row.count == columns || index == codes.count - 1 {
                        lines.append("    " + row.joined(separator: "  "))
                        row = []
                    }
                }
            }
        }

        // Show territory count from relationships
        if let relationships = availability.relationships {
            if let territoryAvailabilities = relationships["territoryAvailabilities"] {
                if case .many(let identifiers) = territoryAvailabilities.data {
                    lines.append("")
                    lines.append("  Total territory availabilities: \(identifiers.count)")
                }
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Formatters

    private func formatPricePoint(_ point: AppPricePoint, territoryMap: [String: String]) -> String {
        let attrs = point.attributes
        let price = attrs?.customerPrice ?? "N/A"
        let proceeds = attrs?.proceeds ?? "N/A"

        // Resolve territory from relationship
        var territory = "?"
        if let relationships = point.relationships,
           let territoryRel = relationships["territory"],
           case .single(let identifier) = territoryRel.data {
            let currency = territoryMap[identifier.id] ?? ""
            territory = currency.isEmpty ? identifier.id : "\(identifier.id) (\(currency))"
        }

        let paddedPrice = price.padding(toLength: 10, withPad: " ", startingAt: 0)
        let paddedProceeds = proceeds.padding(toLength: 10, withPad: " ", startingAt: 0)
        return "  \(paddedPrice) \(paddedProceeds) \(territory)"
    }
}
