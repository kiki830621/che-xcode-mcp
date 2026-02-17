import Foundation
import MCP

// MARK: - ASC Attribute Models

struct InAppPurchaseV2Attributes: Decodable {
    let name: String?
    let productId: String?
    let inAppPurchaseType: String?
    let state: String?
    let reviewNote: String?
    let contentHosting: Bool?
}

struct InAppPurchaseSubmissionAttributes: Decodable {
    // Minimal — mostly relationship-based
}

// MARK: - Type aliases

private typealias InAppPurchaseV2 = ASCResource<InAppPurchaseV2Attributes>
private typealias InAppPurchaseSubmission = ASCResource<InAppPurchaseSubmissionAttributes>

// MARK: - IAPManager

actor IAPManager: ToolProvider {
    private let client: ASCClient

    init(client: ASCClient) {
        self.client = client
    }

    // MARK: - ToolProvider

    var tools: [Tool] {
        [
            Tool(
                name: "iap_list_iaps",
                description: "List in-app purchases for an app. Optionally filter by IAP type.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "app_id": .object([
                            "type": "string",
                            "description": "App Store Connect app ID (required)"
                        ]),
                        "iap_type": .object([
                            "type": "string",
                            "description": "Filter by IAP type: CONSUMABLE, NON_CONSUMABLE, NON_RENEWING_SUBSCRIPTION"
                        ]),
                        "limit": .object([
                            "type": "integer",
                            "description": "Maximum number of IAPs to return (default 20, max 200)"
                        ])
                    ]),
                    "required": .array([.string("app_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "iap_get_iap",
                description: "Get detailed information about a specific in-app purchase.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "iap_id": .object([
                            "type": "string",
                            "description": "The in-app purchase ID"
                        ])
                    ]),
                    "required": .array([.string("iap_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "iap_create_iap",
                description: "Create a new in-app purchase for an app.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "app_id": .object([
                            "type": "string",
                            "description": "App Store Connect app ID"
                        ]),
                        "name": .object([
                            "type": "string",
                            "description": "Reference name for the in-app purchase"
                        ]),
                        "product_id": .object([
                            "type": "string",
                            "description": "Unique product identifier (e.g. com.example.app.product1)"
                        ]),
                        "iap_type": .object([
                            "type": "string",
                            "description": "IAP type: CONSUMABLE, NON_CONSUMABLE, NON_RENEWING_SUBSCRIPTION"
                        ]),
                        "review_note": .object([
                            "type": "string",
                            "description": "Optional note for App Review"
                        ])
                    ]),
                    "required": .array([.string("app_id"), .string("name"), .string("product_id"), .string("iap_type")])
                ]),
                annotations: .init(destructiveHint: false)
            ),
            Tool(
                name: "iap_update_iap",
                description: "Update an existing in-app purchase. Can update name and review note.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "iap_id": .object([
                            "type": "string",
                            "description": "The in-app purchase ID to update"
                        ]),
                        "name": .object([
                            "type": "string",
                            "description": "Updated reference name"
                        ]),
                        "review_note": .object([
                            "type": "string",
                            "description": "Updated note for App Review"
                        ])
                    ]),
                    "required": .array([.string("iap_id")])
                ]),
                annotations: .init(destructiveHint: false)
            ),
            Tool(
                name: "iap_delete_iap",
                description: "Delete an in-app purchase. Only works if the IAP has not yet been approved.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "iap_id": .object([
                            "type": "string",
                            "description": "The in-app purchase ID to delete"
                        ])
                    ]),
                    "required": .array([.string("iap_id")])
                ]),
                annotations: .init(destructiveHint: true)
            ),
            Tool(
                name: "iap_submit_iap",
                description: "Submit an in-app purchase for App Store review.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "iap_id": .object([
                            "type": "string",
                            "description": "The in-app purchase ID to submit for review"
                        ])
                    ]),
                    "required": .array([.string("iap_id")])
                ]),
                annotations: .init(destructiveHint: false)
            ),
        ]
    }

    func handle(_ name: String, arguments: [String: Value]) async throws -> String {
        switch name {
        case "iap_list_iaps":
            return try await handleListIAPs(arguments)
        case "iap_get_iap":
            return try await handleGetIAP(arguments)
        case "iap_create_iap":
            return try await handleCreateIAP(arguments)
        case "iap_update_iap":
            return try await handleUpdateIAP(arguments)
        case "iap_delete_iap":
            return try await handleDeleteIAP(arguments)
        case "iap_submit_iap":
            return try await handleSubmitIAP(arguments)
        default:
            throw ASCClientError.invalidResponse("Unknown IAP tool: \(name)")
        }
    }

    // MARK: - Handler: List IAPs

    private func handleListIAPs(_ args: [String: Value]) async throws -> String {
        let appId = try requireString(args, "app_id")

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "fields[inAppPurchases]", value: "name,productId,inAppPurchaseType,state,reviewNote,contentHosting"),
        ]

        if let iapType = stringValue(args, "iap_type") {
            queryItems.append(URLQueryItem(name: "filter[inAppPurchaseType]", value: iapType))
        }
        let limit = intValue(args, "limit") ?? 20
        queryItems.append(URLQueryItem(name: "limit", value: String(min(limit, 200))))

        let response: ASCListResponse<InAppPurchaseV2> = try await client.getList(
            path: "/v1/apps/\(appId)/inAppPurchasesV2",
            queryItems: queryItems
        )

        if response.data.isEmpty {
            return "No in-app purchases found."
        }

        var lines = ["In-App Purchases (\(response.data.count)):"]
        lines.append(String(repeating: "-", count: 60))
        for iap in response.data {
            lines.append(formatIAP(iap))
        }

        if let paging = response.meta?.paging, let total = paging.total {
            lines.append("\nShowing \(response.data.count) of \(total) total in-app purchases.")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Handler: Get IAP

    private func handleGetIAP(_ args: [String: Value]) async throws -> String {
        let iapId = try requireString(args, "iap_id")

        let queryItems = [
            URLQueryItem(name: "fields[inAppPurchases]", value: "name,productId,inAppPurchaseType,state,reviewNote,contentHosting")
        ]

        let response: ASCResponse<InAppPurchaseV2> = try await client.get(
            path: "/v1/inAppPurchasesV2/\(iapId)",
            queryItems: queryItems
        )

        return formatIAPDetailed(response.data)
    }

    // MARK: - Handler: Create IAP

    private func handleCreateIAP(_ args: [String: Value]) async throws -> String {
        let appId = try requireString(args, "app_id")
        let name = try requireString(args, "name")
        let productId = try requireString(args, "product_id")
        let iapType = try requireString(args, "iap_type")

        var attributes: [String: Any] = [
            "name": name,
            "productId": productId,
            "inAppPurchaseType": iapType,
        ]
        if let reviewNote = stringValue(args, "review_note") {
            attributes["reviewNote"] = reviewNote
        }

        let body: [String: Any] = [
            "data": [
                "type": "inAppPurchases",
                "attributes": attributes,
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

        let response: ASCResponse<InAppPurchaseV2> = try await client.post(
            path: "/v1/inAppPurchasesV2",
            body: body
        )

        let iap = response.data
        let displayType = formatIAPType(iapType)
        return "Successfully created in-app purchase.\nID: \(iap.id)\nName: \(name)\nProduct ID: \(productId)\nType: \(displayType)"
    }

    // MARK: - Handler: Update IAP

    private func handleUpdateIAP(_ args: [String: Value]) async throws -> String {
        let iapId = try requireString(args, "iap_id")

        var attributes: [String: Any] = [:]
        if let name = stringValue(args, "name") {
            attributes["name"] = name
        }
        if let reviewNote = stringValue(args, "review_note") {
            attributes["reviewNote"] = reviewNote
        }

        let body: [String: Any] = [
            "data": [
                "type": "inAppPurchases",
                "id": iapId,
                "attributes": attributes
            ]
        ]

        let response: ASCResponse<InAppPurchaseV2> = try await client.patch(
            path: "/v1/inAppPurchasesV2/\(iapId)",
            body: body
        )

        let iap = response.data
        let updatedName = iap.attributes?.name ?? "N/A"
        return "Successfully updated in-app purchase \(iapId).\nName: \(updatedName)"
    }

    // MARK: - Handler: Delete IAP

    private func handleDeleteIAP(_ args: [String: Value]) async throws -> String {
        let iapId = try requireString(args, "iap_id")

        try await client.delete(path: "/v1/inAppPurchasesV2/\(iapId)")

        return "Successfully deleted in-app purchase \(iapId)."
    }

    // MARK: - Handler: Submit IAP

    private func handleSubmitIAP(_ args: [String: Value]) async throws -> String {
        let iapId = try requireString(args, "iap_id")

        let body: [String: Any] = [
            "data": [
                "type": "inAppPurchaseSubmissions",
                "relationships": [
                    "inAppPurchaseV2": [
                        "data": [
                            "type": "inAppPurchases",
                            "id": iapId
                        ]
                    ]
                ]
            ]
        ]

        let response: ASCResponse<InAppPurchaseSubmission> = try await client.post(
            path: "/v1/inAppPurchaseSubmissions",
            body: body
        )

        return "In-app purchase \(iapId) submitted for review.\nSubmission ID: \(response.data.id)"
    }

    // MARK: - Formatters

    private func formatIAPType(_ type: String?) -> String {
        switch type {
        case "CONSUMABLE": return "Consumable"
        case "NON_CONSUMABLE": return "Non-Consumable"
        case "NON_RENEWING_SUBSCRIPTION": return "Non-Renewing Subscription"
        default: return type ?? "Unknown"
        }
    }

    private func formatIAP(_ iap: InAppPurchaseV2) -> String {
        let attrs = iap.attributes
        let name = attrs?.name ?? "Unnamed"
        let productId = attrs?.productId ?? "?"
        let type = formatIAPType(attrs?.inAppPurchaseType)
        let state = attrs?.state ?? "UNKNOWN"
        return "  [\(iap.id)] \(name) — \(productId) | \(type) | \(state)"
    }

    private func formatIAPDetailed(_ iap: InAppPurchaseV2) -> String {
        let attrs = iap.attributes
        var lines = [
            "In-App Purchase Details",
            String(repeating: "-", count: 40),
            "  ID:              \(iap.id)",
            "  Name:            \(attrs?.name ?? "N/A")",
            "  Product ID:      \(attrs?.productId ?? "N/A")",
            "  Type:            \(formatIAPType(attrs?.inAppPurchaseType))",
            "  State:           \(attrs?.state ?? "N/A")",
            "  Content Hosting: \(attrs?.contentHosting == true ? "Yes" : "No")",
        ]
        if let reviewNote = attrs?.reviewNote, !reviewNote.isEmpty {
            lines.append(String(repeating: "-", count: 40))
            lines.append("  Review Note: \(reviewNote)")
        }
        return lines.joined(separator: "\n")
    }
}
