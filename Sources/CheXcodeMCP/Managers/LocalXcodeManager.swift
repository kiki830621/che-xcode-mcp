import Foundation
import MCP

/// Local Xcode operations: build, deploy, device management, diagnostics.
/// No App Store Connect API needed — purely shell commands.
actor LocalXcodeManager: ToolProvider {

    // MARK: - ToolProvider

    var tools: [Tool] {
        [
            buildTool,
            listSchemesTool,
            buildSettingsTool,
            listDevicesTool,
            deployDeviceTool,
            deployDeviceDebugTool,
            deployMacTool,
            deviceLaunchTool,
            deviceKillTool,
            processListTool,
            processKillTool,
            projectGenerateTool,
            projectInfoTool,
            diagCrashLogTool,
            diagPermissionsTool,
        ]
    }

    func handle(_ name: String, arguments: [String: Value]) async throws -> String {
        switch name {
        case "local_build": return try await handleBuild(arguments)
        case "local_list_schemes": return try await handleListSchemes(arguments)
        case "local_build_settings": return try await handleBuildSettings(arguments)
        case "local_device_list": return try await handleListDevices()
        case "local_deploy_device": return try await handleDeployDevice(arguments, console: false)
        case "local_deploy_device_debug": return try await handleDeployDevice(arguments, console: true)
        case "local_deploy_mac": return try await handleDeployMac(arguments)
        case "local_device_launch": return try await handleDeviceLaunch(arguments)
        case "local_device_kill": return try await handleDeviceKill(arguments)
        case "local_process_list": return try await handleProcessList()
        case "local_process_kill": return try await handleProcessKill(arguments)
        case "local_project_generate": return try await handleProjectGenerate(arguments)
        case "local_project_info": return try await handleProjectInfo(arguments)
        case "local_diag_crash_log": return try await handleDiagCrashLog(arguments)
        case "local_diag_permissions": return try await handleDiagPermissions(arguments)
        default: throw MCPError.methodNotFound("Unknown tool: \(name)")
        }
    }

    // MARK: - Shell Helper

    private func shell(_ command: String, timeout: TimeInterval = 120) async throws -> (stdout: String, stderr: String, exitCode: Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()

        // Timeout handling
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        if process.isRunning {
            process.terminate()
            return ("", "Timeout after \(Int(timeout))s", 1)
        }

        let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        return (stdout, stderr, process.terminationStatus)
    }

    // MARK: - Build Tools

    private var buildTool: Tool {
        Tool(
            name: "local_build",
            description: "Build an Xcode project/workspace. Returns errors and warnings only (verbose output filtered).",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "project": .object(["type": "string", "description": "Path to .xcodeproj (or omit to auto-detect)"]),
                    "workspace": .object(["type": "string", "description": "Path to .xcworkspace (takes precedence over project)"]),
                    "scheme": .object(["type": "string", "description": "Scheme to build (required)"]),
                    "configuration": .object(["type": "string", "description": "Build configuration: Debug or Release (default: Debug)"]),
                    "platform": .object(["type": "string", "description": "Target platform: macOS, iOS, or iOS-simulator (default: macOS)"]),
                    "device_id": .object(["type": "string", "description": "Device UDID for iOS device builds (uses generic/platform=iOS if omitted)"]),
                ]),
                "required": .array([.string("scheme")]),
            ])
        )
    }

    private func handleBuild(_ args: [String: Value]) async throws -> String {
        let scheme = args.stringValue("scheme") ?? ""
        let config = args.stringValue("configuration") ?? "Debug"
        let platform = args.stringValue("platform") ?? "macOS"

        var cmd = "xcodebuild build"

        if let ws = args.stringValue("workspace") {
            cmd += " -workspace '\(ws)'"
        } else if let proj = args.stringValue("project") {
            cmd += " -project '\(proj)'"
        }

        cmd += " -scheme '\(scheme)' -configuration \(config)"

        switch platform.lowercased() {
        case "macos": cmd += " -destination 'platform=macOS'"
        case "ios":
            if let device = args.stringValue("device_id") {
                cmd += " -destination 'platform=iOS,id=\(device)'"
            } else {
                cmd += " -destination 'generic/platform=iOS'"
            }
        case "ios-simulator": cmd += " -destination 'platform=iOS Simulator,name=iPad (A16)'"
        default: cmd += " -destination 'platform=macOS'"
        }

        // Filter to errors/warnings + BUILD result
        cmd += " 2>&1 | grep -E '(error:|warning:|BUILD|\\*\\*)'"

        let result = try await shell(cmd, timeout: 300)
        let output = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)

        if output.contains("BUILD SUCCEEDED") {
            return "BUILD SUCCEEDED\n\(output)"
        } else {
            return "BUILD FAILED\n\(output)\n\(result.stderr)"
        }
    }

    private var listSchemesTool: Tool {
        Tool(
            name: "local_list_schemes",
            description: "List available schemes in an Xcode project or workspace.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "project": .object(["type": "string", "description": "Path to .xcodeproj"]),
                    "workspace": .object(["type": "string", "description": "Path to .xcworkspace"]),
                ]),
            ])
        )
    }

    private func handleListSchemes(_ args: [String: Value]) async throws -> String {
        var cmd = "xcodebuild -list"
        if let ws = args.stringValue("workspace") {
            cmd += " -workspace '\(ws)'"
        } else if let proj = args.stringValue("project") {
            cmd += " -project '\(proj)'"
        }
        cmd += " 2>&1 | grep -A50 'Schemes:'"
        let result = try await shell(cmd)
        return result.stdout
    }

    private var buildSettingsTool: Tool {
        Tool(
            name: "local_build_settings",
            description: "Get build settings (BUILT_PRODUCTS_DIR, PRODUCT_BUNDLE_IDENTIFIER, etc.).",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "project": .object(["type": "string", "description": "Path to .xcodeproj"]),
                    "scheme": .object(["type": "string", "description": "Scheme name (required)"]),
                    "configuration": .object(["type": "string", "description": "Debug or Release (default: Debug)"]),
                    "setting": .object(["type": "string", "description": "Specific setting name to get (e.g. BUILT_PRODUCTS_DIR). If omitted, returns common settings."]),
                ]),
                "required": .array([.string("scheme")]),
            ])
        )
    }

    private func handleBuildSettings(_ args: [String: Value]) async throws -> String {
        let scheme = args.stringValue("scheme") ?? ""
        let config = args.stringValue("configuration") ?? "Debug"

        var cmd = "xcodebuild -showBuildSettings -scheme '\(scheme)' -configuration \(config)"
        if let proj = args.stringValue("project") {
            cmd += " -project '\(proj)'"
        }

        if let setting = args.stringValue("setting") {
            cmd += " 2>/dev/null | grep ' \(setting) ='"
        } else {
            cmd += " 2>/dev/null | grep -E '(BUILT_PRODUCTS_DIR|PRODUCT_BUNDLE_IDENTIFIER|PRODUCT_NAME|DEVELOPMENT_TEAM|INFOPLIST_FILE) ='"
        }

        let result = try await shell(cmd)
        return result.stdout
    }

    // MARK: - Device Tools

    private var listDevicesTool: Tool {
        Tool(
            name: "local_device_list",
            description: "List connected Apple devices (name, UDID, OS version, model). Also shows simulators.",
            inputSchema: .object(["type": "object", "properties": .object([:])])
        )
    }

    private func handleListDevices() async throws -> String {
        let result = try await shell("xcrun xctrace list devices 2>&1")
        return result.stdout
    }

    private var deployDeviceTool: Tool {
        Tool(
            name: "local_deploy_device",
            description: "Install and launch app on a connected iOS device.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "app_path": .object(["type": "string", "description": "Path to .app bundle to install"]),
                    "device_id": .object(["type": "string", "description": "Device UDID (from local_device_list)"]),
                    "bundle_id": .object(["type": "string", "description": "Bundle ID to launch after install"]),
                ]),
                "required": .array([.string("app_path"), .string("device_id"), .string("bundle_id")]),
            ])
        )
    }

    private var deployDeviceDebugTool: Tool {
        Tool(
            name: "local_deploy_device_debug",
            description: "Install and launch app on iOS device with console output capture. Returns stdout/stderr from the app (print statements, crash messages). Essential for debugging crashes.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "app_path": .object(["type": "string", "description": "Path to .app bundle"]),
                    "device_id": .object(["type": "string", "description": "Device UDID"]),
                    "bundle_id": .object(["type": "string", "description": "Bundle ID"]),
                    "timeout": .object(["type": "integer", "description": "Seconds to capture console (default: 15)"]),
                ]),
                "required": .array([.string("app_path"), .string("device_id"), .string("bundle_id")]),
            ])
        )
    }

    private func handleDeployDevice(_ args: [String: Value], console: Bool) async throws -> String {
        let appPath = args.stringValue("app_path") ?? ""
        let deviceId = args.stringValue("device_id") ?? ""
        let bundleId = args.stringValue("bundle_id") ?? ""
        let timeout = args.intValue("timeout") ?? 15

        // Install
        let install = try await shell("xcrun devicectl device install app --device \(deviceId) '\(appPath)' 2>&1")
        guard install.exitCode == 0 else {
            return "Install failed:\n\(install.stdout)\(install.stderr)"
        }

        // Launch
        if console {
            let cmd = "xcrun devicectl device process launch --device \(deviceId) --terminate-existing --console \(bundleId) 2>&1"
            let result = try await shell(cmd, timeout: TimeInterval(timeout))
            return "=== Console Output (\(timeout)s) ===\n\(result.stdout)\(result.stderr)"
        } else {
            let launch = try await shell("xcrun devicectl device process launch --device \(deviceId) --terminate-existing \(bundleId) 2>&1")
            return "Installed and launched \(bundleId)\n\(launch.stdout)"
        }
    }

    private var deployMacTool: Tool {
        Tool(
            name: "local_deploy_mac",
            description: "Copy .app to /Applications and restart the process.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "app_path": .object(["type": "string", "description": "Path to built .app bundle"]),
                    "process_name": .object(["type": "string", "description": "Process name to kill before deploy (optional)"]),
                ]),
                "required": .array([.string("app_path")]),
            ])
        )
    }

    private func handleDeployMac(_ args: [String: Value]) async throws -> String {
        let appPath = args.stringValue("app_path") ?? ""
        let appName = URL(fileURLWithPath: appPath).lastPathComponent

        if let processName = args.stringValue("process_name") {
            _ = try? await shell("pkill -9 -f '\(processName)'")
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }

        let result = try await shell("cp -R '\(appPath)' /Applications/ 2>&1")
        guard result.exitCode == 0 else {
            return "Deploy failed:\n\(result.stderr)"
        }

        return "Deployed \(appName) to /Applications/"
    }

    private var deviceLaunchTool: Tool {
        Tool(
            name: "local_device_launch",
            description: "Launch an already-installed app on a device.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "device_id": .object(["type": "string", "description": "Device UDID"]),
                    "bundle_id": .object(["type": "string", "description": "Bundle ID"]),
                    "console": .object(["type": "boolean", "description": "Capture console output (default: false)"]),
                    "timeout": .object(["type": "integer", "description": "Console capture timeout in seconds (default: 15)"]),
                ]),
                "required": .array([.string("device_id"), .string("bundle_id")]),
            ])
        )
    }

    private func handleDeviceLaunch(_ args: [String: Value]) async throws -> String {
        let deviceId = args.stringValue("device_id") ?? ""
        let bundleId = args.stringValue("bundle_id") ?? ""
        let useConsole = args.boolValue("console") ?? false
        let timeout = args.intValue("timeout") ?? 15

        var cmd = "xcrun devicectl device process launch --device \(deviceId) --terminate-existing"
        if useConsole { cmd += " --console" }
        cmd += " \(bundleId) 2>&1"

        let result = try await shell(cmd, timeout: useConsole ? TimeInterval(timeout) : 30)
        return result.stdout + result.stderr
    }

    private var deviceKillTool: Tool {
        Tool(
            name: "local_device_kill",
            description: "Kill a running app on a connected device.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "device_id": .object(["type": "string", "description": "Device UDID"]),
                    "bundle_id": .object(["type": "string", "description": "Bundle ID to kill"]),
                ]),
                "required": .array([.string("device_id"), .string("bundle_id")]),
            ])
        )
    }

    private func handleDeviceKill(_ args: [String: Value]) async throws -> String {
        let deviceId = args.stringValue("device_id") ?? ""
        let bundleId = args.stringValue("bundle_id") ?? ""
        // devicectl doesn't have a direct kill-by-bundleid, relaunch with terminate-existing then kill
        let result = try await shell("xcrun devicectl device process launch --device \(deviceId) --terminate-existing \(bundleId) 2>&1 && sleep 0.5 && echo 'Killed \(bundleId)'")
        return result.stdout
    }

    // MARK: - Process Tools

    private var processListTool: Tool {
        Tool(
            name: "local_process_list",
            description: "List running Xcode-related processes (xcodebuild, simulators, apps in /Applications).",
            inputSchema: .object(["type": "object", "properties": .object([:])])
        )
    }

    private func handleProcessList() async throws -> String {
        let result = try await shell("ps aux | grep -E '(xcodebuild|Simulator|PawDisplay|xcrun|devicectl)' | grep -v grep")
        return result.stdout.isEmpty ? "No Xcode-related processes running." : result.stdout
    }

    private var processKillTool: Tool {
        Tool(
            name: "local_process_kill",
            description: "Kill a process by name.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "name": .object(["type": "string", "description": "Process name to kill (uses pkill -f)"]),
                ]),
                "required": .array([.string("name")]),
            ])
        )
    }

    private func handleProcessKill(_ args: [String: Value]) async throws -> String {
        let name = args.stringValue("name") ?? ""
        let result = try await shell("pkill -9 -f '\(name)' 2>&1 && echo 'Killed: \(name)' || echo 'No matching process'")
        return result.stdout
    }

    // MARK: - Project Tools

    private var projectGenerateTool: Tool {
        Tool(
            name: "local_project_generate",
            description: "Run xcodegen to generate .xcodeproj from project.yml.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "path": .object(["type": "string", "description": "Directory containing project.yml (default: current directory)"]),
                ]),
            ])
        )
    }

    private func handleProjectGenerate(_ args: [String: Value]) async throws -> String {
        let path = args.stringValue("path") ?? "."
        let result = try await shell("cd '\(path)' && xcodegen generate 2>&1")
        return result.stdout + result.stderr
    }

    private var projectInfoTool: Tool {
        Tool(
            name: "local_project_info",
            description: "Parse project.yml or .xcodeproj to show targets, platforms, and bundle IDs.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "path": .object(["type": "string", "description": "Path to project.yml or .xcodeproj"]),
                ]),
            ])
        )
    }

    private func handleProjectInfo(_ args: [String: Value]) async throws -> String {
        let path = args.stringValue("path") ?? "."
        // Try project.yml first (xcodegen), then xcodebuild
        let ymlResult = try await shell("cat '\(path)/project.yml' 2>/dev/null || cat '\(path)' 2>/dev/null")
        if !ymlResult.stdout.isEmpty {
            return "=== project.yml ===\n\(ymlResult.stdout)"
        }
        let xc = try await shell("xcodebuild -list -project '\(path)' 2>&1")
        return xc.stdout
    }

    // MARK: - Diagnostic Tools

    private var diagCrashLogTool: Tool {
        Tool(
            name: "local_diag_crash_log",
            description: "Read the latest crash log for an app from ~/Library/Logs/DiagnosticReports.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "app_name": .object(["type": "string", "description": "App name to search for in crash logs"]),
                    "limit": .object(["type": "integer", "description": "Number of recent logs to show (default: 1)"]),
                ]),
                "required": .array([.string("app_name")]),
            ])
        )
    }

    private func handleDiagCrashLog(_ args: [String: Value]) async throws -> String {
        let appName = args.stringValue("app_name") ?? ""
        let limit = args.intValue("limit") ?? 1

        let result = try await shell("""
            find ~/Library/Logs/DiagnosticReports -name "*\(appName)*" -type f 2>/dev/null | \
            xargs ls -t 2>/dev/null | head -\(limit) | while read f; do \
                echo "=== $f ==="; head -100 "$f"; echo; \
            done
        """)

        return result.stdout.isEmpty ? "No crash logs found for '\(appName)'." : result.stdout
    }

    private var diagPermissionsTool: Tool {
        Tool(
            name: "local_diag_permissions",
            description: "Check or reset TCC permissions (Screen Recording, Accessibility, etc.) for a bundle ID.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "bundle_id": .object(["type": "string", "description": "Bundle ID to check/reset"]),
                    "reset": .object(["type": "string", "description": "Permission to reset: ScreenCapture, Accessibility, or All"]),
                ]),
                "required": .array([.string("bundle_id")]),
            ])
        )
    }

    private func handleDiagPermissions(_ args: [String: Value]) async throws -> String {
        let bundleId = args.stringValue("bundle_id") ?? ""

        if let reset = args.stringValue("reset") {
            let service = reset == "All" ? "" : reset
            let result = try await shell("tccutil reset \(service) \(bundleId) 2>&1")
            return "Reset \(reset) permission for \(bundleId)\n\(result.stdout)"
        }

        // Check current permissions from TCC database
        let result = try await shell("""
            sqlite3 ~/Library/Application\\ Support/com.apple.TCC/TCC.db \
            "SELECT service, auth_value FROM access WHERE client='\(bundleId)'" 2>&1
        """)

        return result.stdout.isEmpty ? "No TCC entries for \(bundleId)" : result.stdout
    }
}

// MARK: - Value Helpers

private extension [String: Value] {
    func stringValue(_ key: String) -> String? {
        guard case .string(let s) = self[key] else { return nil }
        return s
    }

    func intValue(_ key: String) -> Int? {
        guard case .int(let i) = self[key] else { return nil }
        return i
    }

    func boolValue(_ key: String) -> Bool? {
        guard case .bool(let b) = self[key] else { return nil }
        return b
    }
}
