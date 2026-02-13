import Foundation
import MCP

// MARK: - ASC Attribute Models

struct CustomerReviewAttributes: Decodable {
    let rating: Int?
    let title: String?
    let body: String?
    let reviewerNickname: String?
    let createdDate: Date?
    let territory: String?
}

struct CustomerReviewResponseAttributes: Decodable {
    let responseBody: String?
    let lastModifiedDate: Date?
    let state: String?
}

struct AppStoreVersionSubmissionAttributes: Decodable {
    // This resource has no attributes in the API
}

// MARK: - Type aliases

private typealias CustomerReview = ASCResource<CustomerReviewAttributes>
private typealias CustomerReviewResponse = ASCResource<CustomerReviewResponseAttributes>
private typealias AppStoreVersionSubmission = ASCResource<AppStoreVersionSubmissionAttributes>

// MARK: - ReviewManager

actor ReviewManager: ToolProvider {
    private let client: ASCClient

    init(client: ASCClient) {
        self.client = client
    }

    // MARK: - ToolProvider

    var tools: [Tool] {
        [
            Tool(
                name: "review_list_customer_reviews",
                description: "List customer reviews for an app. Optionally filter by star rating and sort order.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "app_id": .object([
                            "type": "string",
                            "description": "App Store Connect app ID (required)"
                        ]),
                        "rating": .object([
                            "type": "integer",
                            "description": "Filter by star rating (1-5)"
                        ]),
                        "sort": .object([
                            "type": "string",
                            "description": "Sort order: rating, -rating, createdDate, -createdDate"
                        ]),
                        "limit": .object([
                            "type": "integer",
                            "description": "Maximum number of reviews to return (default 20, max 200)"
                        ])
                    ]),
                    "required": .array([.string("app_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "review_get_customer_review",
                description: "Get a specific customer review by ID.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "review_id": .object([
                            "type": "string",
                            "description": "The customer review ID"
                        ])
                    ]),
                    "required": .array([.string("review_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "review_respond_to_review",
                description: "Respond to a customer review. Creates a new developer response.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "review_id": .object([
                            "type": "string",
                            "description": "The customer review ID to respond to"
                        ]),
                        "response_body": .object([
                            "type": "string",
                            "description": "The response text to post"
                        ])
                    ]),
                    "required": .array([.string("review_id"), .string("response_body")])
                ]),
                annotations: .init(destructiveHint: false)
            ),
            Tool(
                name: "review_update_response",
                description: "Update an existing developer response to a customer review.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "response_id": .object([
                            "type": "string",
                            "description": "The customer review response ID to update"
                        ]),
                        "response_body": .object([
                            "type": "string",
                            "description": "The updated response text"
                        ])
                    ]),
                    "required": .array([.string("response_id"), .string("response_body")])
                ]),
                annotations: .init(destructiveHint: false)
            ),
            Tool(
                name: "review_delete_response",
                description: "Delete a developer response to a customer review.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "response_id": .object([
                            "type": "string",
                            "description": "The customer review response ID to delete"
                        ])
                    ]),
                    "required": .array([.string("response_id")])
                ]),
                annotations: .init(destructiveHint: true)
            ),
            Tool(
                name: "review_submit_for_review",
                description: "Submit an app store version for App Store review.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "version_id": .object([
                            "type": "string",
                            "description": "The app store version ID to submit for review"
                        ])
                    ]),
                    "required": .array([.string("version_id")])
                ]),
                annotations: .init(destructiveHint: false, idempotentHint: true)
            ),
        ]
    }

    func handle(_ name: String, arguments: [String: Value]) async throws -> String {
        switch name {
        case "review_list_customer_reviews":
            return try await handleListCustomerReviews(arguments)
        case "review_get_customer_review":
            return try await handleGetCustomerReview(arguments)
        case "review_respond_to_review":
            return try await handleRespondToReview(arguments)
        case "review_update_response":
            return try await handleUpdateResponse(arguments)
        case "review_delete_response":
            return try await handleDeleteResponse(arguments)
        case "review_submit_for_review":
            return try await handleSubmitForReview(arguments)
        default:
            throw ASCClientError.invalidResponse("Unknown Review tool: \(name)")
        }
    }

    // MARK: - Handler: List Customer Reviews

    private func handleListCustomerReviews(_ args: [String: Value]) async throws -> String {
        let appId = try requireString(args, "app_id")

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "fields[customerReviews]", value: "rating,title,body,reviewerNickname,createdDate,territory"),
        ]

        if let rating = intValue(args, "rating") {
            queryItems.append(URLQueryItem(name: "filter[rating]", value: String(rating)))
        }
        if let sort = stringValue(args, "sort") {
            queryItems.append(URLQueryItem(name: "sort", value: sort))
        } else {
            queryItems.append(URLQueryItem(name: "sort", value: "-createdDate"))
        }
        let limit = intValue(args, "limit") ?? 20
        queryItems.append(URLQueryItem(name: "limit", value: String(min(limit, 200))))

        let response: ASCListResponse<CustomerReview> = try await client.getList(
            path: "/v1/apps/\(appId)/customerReviews",
            queryItems: queryItems
        )

        if response.data.isEmpty {
            return "No customer reviews found."
        }

        var lines = ["Customer Reviews (\(response.data.count)):"]
        lines.append(String(repeating: "-", count: 60))
        for review in response.data {
            lines.append(formatReview(review))
        }

        if let paging = response.meta?.paging, let total = paging.total {
            lines.append("\nShowing \(response.data.count) of \(total) total reviews.")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Handler: Get Customer Review

    private func handleGetCustomerReview(_ args: [String: Value]) async throws -> String {
        let reviewId = try requireString(args, "review_id")

        let queryItems = [
            URLQueryItem(name: "fields[customerReviews]", value: "rating,title,body,reviewerNickname,createdDate,territory")
        ]

        let response: ASCResponse<CustomerReview> = try await client.get(
            path: "/v1/customerReviews/\(reviewId)",
            queryItems: queryItems
        )

        return formatReviewDetailed(response.data)
    }

    // MARK: - Handler: Respond to Review

    private func handleRespondToReview(_ args: [String: Value]) async throws -> String {
        let reviewId = try requireString(args, "review_id")
        let responseBody = try requireString(args, "response_body")

        let body: [String: Any] = [
            "data": [
                "type": "customerReviewResponses",
                "attributes": [
                    "responseBody": responseBody
                ],
                "relationships": [
                    "review": [
                        "data": [
                            "type": "customerReviews",
                            "id": reviewId
                        ]
                    ]
                ]
            ]
        ]

        let response: ASCResponse<CustomerReviewResponse> = try await client.post(
            path: "/v1/customerReviewResponses",
            body: body
        )

        let state = response.data.attributes?.state ?? "UNKNOWN"
        return "Successfully responded to review \(reviewId).\nResponse ID: \(response.data.id)\nState: \(state)\n\nResponse:\n\(responseBody)"
    }

    // MARK: - Handler: Update Response

    private func handleUpdateResponse(_ args: [String: Value]) async throws -> String {
        let responseId = try requireString(args, "response_id")
        let responseBody = try requireString(args, "response_body")

        let body: [String: Any] = [
            "data": [
                "type": "customerReviewResponses",
                "id": responseId,
                "attributes": [
                    "responseBody": responseBody
                ]
            ]
        ]

        let response: ASCResponse<CustomerReviewResponse> = try await client.patch(
            path: "/v1/customerReviewResponses/\(responseId)",
            body: body
        )

        let state = response.data.attributes?.state ?? "UNKNOWN"
        return "Successfully updated response \(responseId).\nState: \(state)\n\nUpdated response:\n\(responseBody)"
    }

    // MARK: - Handler: Delete Response

    private func handleDeleteResponse(_ args: [String: Value]) async throws -> String {
        let responseId = try requireString(args, "response_id")

        try await client.delete(path: "/v1/customerReviewResponses/\(responseId)")

        return "Successfully deleted review response \(responseId)."
    }

    // MARK: - Handler: Submit for Review

    private func handleSubmitForReview(_ args: [String: Value]) async throws -> String {
        let versionId = try requireString(args, "version_id")

        let body: [String: Any] = [
            "data": [
                "type": "appStoreVersionSubmissions",
                "relationships": [
                    "appStoreVersion": [
                        "data": [
                            "type": "appStoreVersions",
                            "id": versionId
                        ]
                    ]
                ]
            ]
        ]

        let response: ASCResponse<AppStoreVersionSubmission> = try await client.post(
            path: "/v1/appStoreVersionSubmissions",
            body: body
        )

        return "App store version \(versionId) submitted for review.\nSubmission ID: \(response.data.id)"
    }

    // MARK: - Formatters

    private func starRating(_ rating: Int?) -> String {
        guard let rating, rating >= 1, rating <= 5 else { return "?" }
        return String(repeating: "\u{2605}", count: rating) + String(repeating: "\u{2606}", count: 5 - rating)
    }

    private func formatReview(_ review: CustomerReview) -> String {
        let attrs = review.attributes
        let stars = starRating(attrs?.rating)
        let nickname = attrs?.reviewerNickname ?? "Anonymous"
        let title = attrs?.title ?? ""
        let date = formatDate(attrs?.createdDate)
        let territory = attrs?.territory ?? "?"
        var line = "  [\(review.id)] \(stars) by \(nickname) | \(date) | \(territory)"
        if !title.isEmpty {
            line += "\n    \"\(title)\""
        }
        return line
    }

    private func formatReviewDetailed(_ review: CustomerReview) -> String {
        let attrs = review.attributes
        var lines = [
            "Customer Review",
            String(repeating: "-", count: 40),
            "  ID:        \(review.id)",
            "  Rating:    \(starRating(attrs?.rating))",
            "  Title:     \(attrs?.title ?? "N/A")",
            "  Reviewer:  \(attrs?.reviewerNickname ?? "Anonymous")",
            "  Territory: \(attrs?.territory ?? "N/A")",
            "  Date:      \(formatDate(attrs?.createdDate))",
        ]
        if let body = attrs?.body, !body.isEmpty {
            lines.append(String(repeating: "-", count: 40))
            lines.append("  \(body)")
        }
        return lines.joined(separator: "\n")
    }
}
