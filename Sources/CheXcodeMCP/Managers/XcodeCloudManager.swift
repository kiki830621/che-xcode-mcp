import Foundation
import MCP

// MARK: - ASC Attribute Models

struct CiProductAttributes: Decodable {
    let name: String?
    let createdDate: Date?
    let productType: String?
}

struct CiWorkflowAttributes: Decodable {
    let name: String?
    let description: String?
    let lastModifiedDate: Date?
    let isEnabled: Bool?
    let isLockedForEditing: Bool?
}

struct CiBuildRunAttributes: Decodable {
    let number: Int?
    let createdDate: Date?
    let startedDate: Date?
    let finishedDate: Date?
    let executionProgress: String?
    let completionStatus: String?
    let sourceCommit: CiSourceCommit?
}

struct CiSourceCommit: Decodable {
    let commitSha: String?
    let message: String?
    let author: CiAuthor?
}

struct CiAuthor: Decodable {
    let displayName: String?
}

// MARK: - Type aliases

private typealias CiProduct = ASCResource<CiProductAttributes>
private typealias CiWorkflow = ASCResource<CiWorkflowAttributes>
private typealias CiBuildRun = ASCResource<CiBuildRunAttributes>

// MARK: - XcodeCloudManager

actor XcodeCloudManager: ToolProvider {
    private let client: ASCClient

    init(client: ASCClient) {
        self.client = client
    }

    // MARK: - ToolProvider

    var tools: [Tool] {
        [
            Tool(
                name: "ci_list_products",
                description: "List Xcode Cloud CI products. Optionally limit the number of results.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "limit": .object([
                            "type": "integer",
                            "description": "Maximum number of products to return (default 20, max 200)"
                        ])
                    ])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "ci_get_product",
                description: "Get detailed information about a specific Xcode Cloud CI product.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "product_id": .object([
                            "type": "string",
                            "description": "The CI product ID"
                        ])
                    ]),
                    "required": .array([.string("product_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "ci_list_workflows",
                description: "List Xcode Cloud workflows for a CI product.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "product_id": .object([
                            "type": "string",
                            "description": "The CI product ID to list workflows for"
                        ])
                    ]),
                    "required": .array([.string("product_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "ci_get_workflow",
                description: "Get detailed information about a specific Xcode Cloud workflow.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "workflow_id": .object([
                            "type": "string",
                            "description": "The CI workflow ID"
                        ])
                    ]),
                    "required": .array([.string("workflow_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "ci_list_build_runs",
                description: "List Xcode Cloud build runs. Optionally filter by product_id.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "product_id": .object([
                            "type": "string",
                            "description": "CI product ID to filter build runs"
                        ]),
                        "limit": .object([
                            "type": "integer",
                            "description": "Maximum number of build runs to return (default 20, max 200)"
                        ])
                    ])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "ci_start_build",
                description: "Start a new Xcode Cloud build run for a workflow.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "workflow_id": .object([
                            "type": "string",
                            "description": "The CI workflow ID to start a build for"
                        ]),
                        "git_reference_id": .object([
                            "type": "string",
                            "description": "Optional SCM git reference ID to build from"
                        ])
                    ]),
                    "required": .array([.string("workflow_id")])
                ]),
                annotations: .init(destructiveHint: false, idempotentHint: false)
            ),
        ]
    }

    func handle(_ name: String, arguments: [String: Value]) async throws -> String {
        switch name {
        case "ci_list_products":
            return try await handleListProducts(arguments)
        case "ci_get_product":
            return try await handleGetProduct(arguments)
        case "ci_list_workflows":
            return try await handleListWorkflows(arguments)
        case "ci_get_workflow":
            return try await handleGetWorkflow(arguments)
        case "ci_list_build_runs":
            return try await handleListBuildRuns(arguments)
        case "ci_start_build":
            return try await handleStartBuild(arguments)
        default:
            throw ASCClientError.invalidResponse("Unknown Xcode Cloud tool: \(name)")
        }
    }

    // MARK: - Handler: List Products

    private func handleListProducts(_ args: [String: Value]) async throws -> String {
        let limit = intValue(args, "limit") ?? 20
        let queryItems = [
            URLQueryItem(name: "fields[ciProducts]", value: "name,createdDate,productType"),
            URLQueryItem(name: "limit", value: String(min(limit, 200))),
        ]

        let response: ASCListResponse<CiProduct> = try await client.getList(
            path: "/v1/ciProducts",
            queryItems: queryItems
        )

        if response.data.isEmpty {
            return "No Xcode Cloud products found."
        }

        var lines = ["Xcode Cloud Products (\(response.data.count)):"]
        lines.append(String(repeating: "-", count: 60))
        for product in response.data {
            lines.append(formatProduct(product))
        }

        if let paging = response.meta?.paging, let total = paging.total {
            lines.append("\nShowing \(response.data.count) of \(total) total products.")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Handler: Get Product

    private func handleGetProduct(_ args: [String: Value]) async throws -> String {
        let productId = try requireString(args, "product_id")

        let queryItems = [
            URLQueryItem(name: "fields[ciProducts]", value: "name,createdDate,productType")
        ]

        let response: ASCResponse<CiProduct> = try await client.get(
            path: "/v1/ciProducts/\(productId)",
            queryItems: queryItems
        )

        return formatProductDetailed(response.data)
    }

    // MARK: - Handler: List Workflows

    private func handleListWorkflows(_ args: [String: Value]) async throws -> String {
        let productId = try requireString(args, "product_id")

        let queryItems = [
            URLQueryItem(name: "fields[ciWorkflows]", value: "name,description,lastModifiedDate,isEnabled,isLockedForEditing")
        ]

        let response: ASCListResponse<CiWorkflow> = try await client.getList(
            path: "/v1/ciProducts/\(productId)/workflows",
            queryItems: queryItems
        )

        if response.data.isEmpty {
            return "No workflows found for product \(productId)."
        }

        var lines = ["Xcode Cloud Workflows for product \(productId) (\(response.data.count)):"]
        lines.append(String(repeating: "-", count: 60))
        for workflow in response.data {
            lines.append(formatWorkflow(workflow))
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Handler: Get Workflow

    private func handleGetWorkflow(_ args: [String: Value]) async throws -> String {
        let workflowId = try requireString(args, "workflow_id")

        let queryItems = [
            URLQueryItem(name: "fields[ciWorkflows]", value: "name,description,lastModifiedDate,isEnabled,isLockedForEditing")
        ]

        let response: ASCResponse<CiWorkflow> = try await client.get(
            path: "/v1/ciWorkflows/\(workflowId)",
            queryItems: queryItems
        )

        return formatWorkflowDetailed(response.data)
    }

    // MARK: - Handler: List Build Runs

    private func handleListBuildRuns(_ args: [String: Value]) async throws -> String {
        let limit = intValue(args, "limit") ?? 20

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: String(min(limit, 200))),
        ]

        let path: String
        if let productId = stringValue(args, "product_id") {
            path = "/v1/ciProducts/\(productId)/buildRuns"
            queryItems.append(
                URLQueryItem(name: "fields[ciBuildRuns]", value: "number,createdDate,startedDate,finishedDate,executionProgress,completionStatus,sourceCommit")
            )
        } else {
            path = "/v1/ciBuildRuns"
            queryItems.append(
                URLQueryItem(name: "fields[ciBuildRuns]", value: "number,createdDate,startedDate,finishedDate,executionProgress,completionStatus,sourceCommit")
            )
        }

        let response: ASCListResponse<CiBuildRun> = try await client.getList(
            path: path,
            queryItems: queryItems
        )

        if response.data.isEmpty {
            return "No build runs found."
        }

        var lines = ["Xcode Cloud Build Runs (\(response.data.count)):"]
        lines.append(String(repeating: "-", count: 60))
        for run in response.data {
            lines.append(formatBuildRun(run))
        }

        if let paging = response.meta?.paging, let total = paging.total {
            lines.append("\nShowing \(response.data.count) of \(total) total build runs.")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Handler: Start Build

    private func handleStartBuild(_ args: [String: Value]) async throws -> String {
        let workflowId = try requireString(args, "workflow_id")

        var relationships: [String: Any] = [
            "workflow": [
                "data": [
                    "type": "ciWorkflows",
                    "id": workflowId
                ]
            ]
        ]

        if let gitRefId = stringValue(args, "git_reference_id") {
            relationships["sourceBranchOrTag"] = [
                "data": [
                    "type": "scmGitReferences",
                    "id": gitRefId
                ]
            ]
        }

        let body: [String: Any] = [
            "data": [
                "type": "ciBuildRuns",
                "relationships": relationships
            ]
        ]

        let response: ASCResponse<CiBuildRun> = try await client.post(
            path: "/v1/ciBuildRuns",
            body: body
        )

        let run = response.data
        let number = run.attributes?.number.map { "#\($0)" } ?? "N/A"
        let progress = run.attributes?.executionProgress ?? "PENDING"
        return "Build run started successfully.\nBuild Run ID: \(run.id)\nNumber: \(number)\nProgress: \(progress)"
    }

    // MARK: - Formatters

    private func formatProduct(_ product: CiProduct) -> String {
        let attrs = product.attributes
        let name = attrs?.name ?? "Unnamed"
        let type = attrs?.productType ?? "?"
        let created = formatDate(attrs?.createdDate)
        return "  [\(product.id)] \(name) — \(type) | Created: \(created)"
    }

    private func formatProductDetailed(_ product: CiProduct) -> String {
        let attrs = product.attributes
        let lines = [
            "CI Product Details",
            String(repeating: "-", count: 40),
            "  ID:           \(product.id)",
            "  Name:         \(attrs?.name ?? "N/A")",
            "  Product Type: \(attrs?.productType ?? "N/A")",
            "  Created:      \(formatDate(attrs?.createdDate))",
        ]
        return lines.joined(separator: "\n")
    }

    private func formatWorkflow(_ workflow: CiWorkflow) -> String {
        let attrs = workflow.attributes
        let name = attrs?.name ?? "Unnamed"
        let enabled = (attrs?.isEnabled == true) ? "Enabled" : "Disabled"
        let locked = (attrs?.isLockedForEditing == true) ? " | Locked" : ""
        let modified = formatDate(attrs?.lastModifiedDate)
        return "  [\(workflow.id)] \(name) — \(enabled)\(locked) | Modified: \(modified)"
    }

    private func formatWorkflowDetailed(_ workflow: CiWorkflow) -> String {
        let attrs = workflow.attributes
        let lines = [
            "CI Workflow Details",
            String(repeating: "-", count: 40),
            "  ID:          \(workflow.id)",
            "  Name:        \(attrs?.name ?? "N/A")",
            "  Description: \(attrs?.description ?? "N/A")",
            "  Enabled:     \(attrs?.isEnabled == true ? "Yes" : "No")",
            "  Locked:      \(attrs?.isLockedForEditing == true ? "Yes" : "No")",
            "  Modified:    \(formatDate(attrs?.lastModifiedDate))",
        ]
        return lines.joined(separator: "\n")
    }

    private func formatBuildRun(_ run: CiBuildRun) -> String {
        let attrs = run.attributes
        let number = attrs?.number.map { "#\($0)" } ?? "?"
        let progress = attrs?.executionProgress ?? "UNKNOWN"
        let status = attrs?.completionStatus ?? "N/A"
        let created = formatDate(attrs?.createdDate)
        var line = "  [\(run.id)] Build \(number) — \(progress)"
        if status != "N/A" {
            line += " (\(status))"
        }
        line += " | Created: \(created)"
        if let commit = attrs?.sourceCommit {
            let sha = commit.commitSha.map { String($0.prefix(7)) } ?? "?"
            let author = commit.author?.displayName ?? "?"
            line += "\n    Commit: \(sha) by \(author)"
            if let message = commit.message {
                let firstLine = message.split(separator: "\n").first.map(String.init) ?? message
                line += " — \(firstLine)"
            }
        }
        return line
    }
}
