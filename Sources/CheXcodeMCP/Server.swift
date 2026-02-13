import Foundation
import MCP

/// MCP Server routing tool calls to domain Managers via ToolProvider protocol.
class CheXcodeMCPServer {
    private let server: Server
    private let transport: StdioTransport
    private let providers: [String: any ToolProvider]
    private let allTools: [Tool]

    init() async throws {
        // Initialize auth and HTTP client
        let jwtManager = try JWTManager(fromEnvironment: ())
        let ascClient = ASCClient(jwtManager: jwtManager)

        // Initialize all managers
        let testFlight = TestFlightManager(client: ascClient)
        // TODO: Add remaining 15 managers as they are implemented

        // Register providers with their prefix
        providers = [
            "testflight": testFlight,
        ]

        // Collect all tools from all providers
        var tools: [Tool] = []
        for provider in providers.values {
            let providerTools = await provider.tools
            tools.append(contentsOf: providerTools)
        }
        allTools = tools

        // Create MCP server
        server = Server(
            name: AppVersion.name,
            version: AppVersion.current,
            capabilities: .init(tools: .init())
        )
        transport = StdioTransport()

        await registerHandlers()
    }

    func run() async throws {
        try await server.start(transport: transport)
        await server.waitUntilCompleted()
    }

    // MARK: - Handler Registration

    private func registerHandlers() async {
        await server.withMethodHandler(ListTools.self) { [allTools] _ in
            ListTools.Result(tools: allTools)
        }

        await server.withMethodHandler(CallTool.self) { [weak self] params in
            guard let self else {
                return CallTool.Result(content: [.text("Server unavailable")], isError: true)
            }
            return await self.handleToolCall(
                name: params.name,
                arguments: params.arguments ?? [:]
            )
        }
    }

    private func handleToolCall(
        name: String,
        arguments: [String: Value]
    ) async -> CallTool.Result {
        // Route by prefix: "testflight_list_builds" → prefix "testflight"
        let prefix = name.split(separator: "_").first.map(String.init) ?? name
        guard let provider = providers[prefix] else {
            return CallTool.Result(
                content: [.text("Unknown tool category: '\(prefix)'. Available: \(providers.keys.sorted().joined(separator: ", "))")],
                isError: true
            )
        }

        do {
            let result = try await provider.handle(name, arguments: arguments)
            return CallTool.Result(content: [.text(result)])
        } catch {
            return CallTool.Result(
                content: [.text("Error: \(error.localizedDescription)")],
                isError: true
            )
        }
    }
}
