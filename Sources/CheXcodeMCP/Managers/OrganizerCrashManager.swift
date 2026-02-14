import Foundation
import MCP

// MARK: - OrganizerCrashManager

/// Reads crash data from Xcode Organizer's local cache.
///
/// Xcode downloads crash reports from Apple's crash reporting service
/// and caches them at:
///   ~/Library/Developer/Xcode/Products/{bundle_id}/Crashes/
///
/// This data is NOT available through the ASC REST API.
actor OrganizerCrashManager: ToolProvider {

    private let productsDir: URL

    init() {
        self.productsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Developer/Xcode/Products")
    }

    // MARK: - ToolProvider

    var tools: [Tool] {
        [
            Tool(
                name: "organizer_list_crashes",
                description: """
                    List crash signatures from Xcode Organizer's local cache. \
                    Returns crash point names, affected versions, device counts, and whether feedback exists. \
                    This reads locally cached data — open Xcode Organizer first to ensure data is up to date.
                    """,
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "bundle_id": .object([
                            "type": "string",
                            "description": "App bundle identifier (e.g. 'com.chekeeper.ai4o'). If omitted, lists all available apps."
                        ])
                    ]),
                    "required": .array([])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "organizer_get_crash_log",
                description: """
                    Read a specific symbolicated crash log from Xcode Organizer's local cache. \
                    Returns the full .crash file content including backtrace, thread state, and binary images. \
                    Use organizer_list_crashes first to discover available crash points.
                    """,
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "bundle_id": .object([
                            "type": "string",
                            "description": "App bundle identifier (required, e.g. 'com.chekeeper.ai4o')"
                        ]),
                        "point_id": .object([
                            "type": "string",
                            "description": "Crash point identifier from organizer_list_crashes (optional — if omitted, returns the most recent crash log)"
                        ]),
                        "include_threads": .object([
                            "type": "boolean",
                            "description": "Include full thread backtraces (default: false, shows only Last Exception Backtrace and crashing thread)"
                        ])
                    ]),
                    "required": .array([.string("bundle_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "organizer_get_crash_stats",
                description: """
                    Get crash statistics for a specific crash point — version distribution, \
                    OS distribution, device families, and time series. \
                    Use organizer_list_crashes first to get the point_id.
                    """,
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "bundle_id": .object([
                            "type": "string",
                            "description": "App bundle identifier (required)"
                        ]),
                        "point_id": .object([
                            "type": "string",
                            "description": "Crash point identifier (required)"
                        ])
                    ]),
                    "required": .array([.string("bundle_id"), .string("point_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
        ]
    }

    func handle(_ name: String, arguments: [String: Value]) async throws -> String {
        switch name {
        case "organizer_list_crashes":
            return try handleListCrashes(arguments)
        case "organizer_get_crash_log":
            return try handleGetCrashLog(arguments)
        case "organizer_get_crash_stats":
            return try handleGetCrashStats(arguments)
        default:
            throw ASCClientError.invalidResponse("Unknown Organizer tool: \(name)")
        }
    }

    // MARK: - List Crashes

    private func handleListCrashes(_ args: [String: Value]) throws -> String {
        let bundleId = stringValue(args, "bundle_id")

        // If no bundle_id, list all available apps
        guard let bundleId else {
            return try listAvailableApps()
        }

        let crashesDir = productsDir
            .appendingPathComponent(bundleId)
            .appendingPathComponent("Crashes")

        let listableFile = crashesDir.appendingPathComponent("ListablePoints.json")
        guard FileManager.default.fileExists(atPath: listableFile.path) else {
            return "No crash data found for \(bundleId). Open Xcode Organizer to sync crash data from Apple."
        }

        let data = try Data(contentsOf: listableFile)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

        guard let recentItems = json["recentItems"] as? [[String: Any]],
              recentItems.count >= 2,
              let valueItem = recentItems[1]["value"] as? [String: Any],
              let crashPoints = valueItem["crashPoints"] as? [[String: Any]] else {
            return "No crash points found for \(bundleId)."
        }

        if crashPoints.isEmpty {
            return "No crashes recorded for \(bundleId)."
        }

        // Extract header info
        let header = valueItem["header"] as? [String: Any]
        let refreshDate = header?["refreshDate"] as? String ?? "unknown"

        var lines = [
            "Crash Points for \(bundleId) (\(crashPoints.count) signatures)",
            "Last synced: \(refreshDate)",
            String(repeating: "-", count: 60),
        ]

        for point in crashPoints {
            let name = point["analyticsPointName"] as? String ?? "Unknown"
            let pointId = point["analyticsPointIdentifier"] as? String ?? "?"
            let last24h = point["uniqueDeviceCountFilteredForLast24Hours"] as? Int ?? 0
            let total = point["uniqueDeviceCountFilteredWithTimePeriod"] as? Int ?? 0
            let hasFeedback = point["hasFeedback"] as? Bool ?? false
            let source = point["sourceFileName"] as? String ?? "?"
            let line = point["sourceFileLineNumber"] as? Int

            lines.append("  [\(pointId)]")
            lines.append("    Name: \(name)")
            lines.append("    Source: \(source)\(line.map { ":\($0)" } ?? "")")
            lines.append("    Devices (24h): \(last24h) | Devices (period): \(total)")
            if hasFeedback { lines.append("    Has user feedback: yes") }

            // Count available crash logs
            let logCount = countCrashLogs(bundleId: bundleId, pointId: pointId)
            if logCount > 0 {
                lines.append("    Crash logs available: \(logCount)")
            }
            lines.append("")
        }

        lines.append("Use organizer_get_crash_log to read full symbolicated backtrace.")
        lines.append("Use organizer_get_crash_stats for version/OS/device distribution.")

        return lines.joined(separator: "\n")
    }

    // MARK: - Get Crash Log

    private func handleGetCrashLog(_ args: [String: Value]) throws -> String {
        let bundleId = try requireString(args, "bundle_id")
        let pointId = stringValue(args, "point_id")
        let includeThreads = boolValue(args, "include_threads") ?? false

        // Find crash log files
        let crashLogs = findCrashLogs(bundleId: bundleId, pointId: pointId)

        if crashLogs.isEmpty {
            if let pointId {
                return "No crash logs found for point \(pointId) in \(bundleId)."
            } else {
                return "No crash logs found for \(bundleId). Open Xcode Organizer to sync crash data."
            }
        }

        // Sort by modification date, newest first
        let sorted = crashLogs.sorted { a, b in
            let aDate = (try? FileManager.default.attributesOfItem(atPath: a.path)[.modificationDate] as? Date) ?? .distantPast
            let bDate = (try? FileManager.default.attributesOfItem(atPath: b.path)[.modificationDate] as? Date) ?? .distantPast
            return aDate > bDate
        }

        // Read the most recent crash log
        let logURL = sorted[0]
        let content = try String(contentsOf: logURL, encoding: .utf8)

        if includeThreads {
            // Return full content
            var lines = [
                "Crash Log (\(sorted.count) total, showing most recent)",
                "File: \(logURL.lastPathComponent)",
                String(repeating: "=", count: 60),
                content,
            ]
            if sorted.count > 1 {
                lines.append("\n\(sorted.count - 1) more crash log(s) available for this point.")
            }
            return lines.joined(separator: "\n")
        }

        // Filtered view: header + Last Exception Backtrace + crashing thread only
        return filterCrashLog(content, logURL: logURL, totalCount: sorted.count)
    }

    // MARK: - Get Crash Stats

    private func handleGetCrashStats(_ args: [String: Value]) throws -> String {
        let bundleId = try requireString(args, "bundle_id")
        let pointId = try requireString(args, "point_id")

        let distInfoFiles = findDistributionInfo(bundleId: bundleId, pointId: pointId)
        guard let distFile = distInfoFiles.first else {
            return "No distribution info found for point \(pointId) in \(bundleId)."
        }

        let data = try Data(contentsOf: distFile)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let body = json["body"] as? [String: Any] ?? [:]

        var lines = [
            "Crash Statistics for point \(pointId)",
            String(repeating: "-", count: 60),
        ]

        // App version distribution
        if let dist = body["appVersionDistribution"] as? [String: Any],
           let metas = dist["appVersionAndBuildMetaDatas"] as? [[String: Any]] {
            lines.append("\nApp Version Distribution:")
            for meta in metas {
                let period = meta["timePeriod"] as? String ?? "?"
                let datas = meta["appVersionAndBuildDatas"] as? [[String: Any]] ?? []
                if datas.isEmpty { continue }
                lines.append("  \(period):")
                for d in datas {
                    let ver = d["appVersion"] as? String ?? "?"
                    let build = d["appBuild"] as? String ?? "?"
                    let count = d["value"] as? Int ?? 0
                    lines.append("    v\(ver) build \(build): \(count) device(s)")
                }
            }
        }

        // OS version distribution
        if let dist = body["osVersionDistribution"] as? [String: Any],
           let metas = dist["osVersionMetaDatas"] as? [[String: Any]] {
            lines.append("\nOS Version Distribution:")
            for meta in metas {
                let period = meta["timePeriod"] as? String ?? "?"
                let datas = meta["osVersionDatas"] as? [[String: Any]] ?? []
                if datas.isEmpty { continue }
                lines.append("  \(period):")
                for d in datas {
                    let os = d["osVersion"] as? String ?? "?"
                    let count = d["value"] as? Int ?? 0
                    lines.append("    \(os): \(count) device(s)")
                }
            }
        }

        // Device family distribution
        if let dist = body["deviceFamilyDistribution"] as? [String: Any],
           let metas = dist["deviceFamilyMetaDatas"] as? [[String: Any]] {
            lines.append("\nDevice Family Distribution:")
            for meta in metas {
                let period = meta["timePeriod"] as? String ?? "?"
                let datas = meta["deviceFamilyDatas"] as? [[String: Any]] ?? []
                if datas.isEmpty { continue }
                lines.append("  \(period):")
                for d in datas {
                    let family = d["deviceFamily"] as? String ?? "?"
                    let count = d["value"] as? Int ?? 0
                    lines.append("    \(family): \(count) device(s)")
                }
            }
        }

        // Beta vs App Store
        if let dist = body["isBetaDistribution"] as? [String: Any],
           let metas = dist["isBetaMetaDatas"] as? [[String: Any]] {
            lines.append("\nDistribution Type:")
            for meta in metas {
                let period = meta["timePeriod"] as? String ?? "?"
                let datas = meta["isBetaDatas"] as? [[String: Any]] ?? []
                if datas.isEmpty { continue }
                lines.append("  \(period):")
                for d in datas {
                    let isBeta = d["isBeta"] as? Bool ?? false
                    let count = d["value"] as? Int ?? 0
                    lines.append("    \(isBeta ? "TestFlight" : "App Store"): \(count) device(s)")
                }
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    private func listAvailableApps() throws -> String {
        let fm = FileManager.default
        guard fm.fileExists(atPath: productsDir.path) else {
            return "Xcode Products directory not found. Open Xcode Organizer at least once."
        }

        let contents = try fm.contentsOfDirectory(atPath: productsDir.path)
        let apps = contents.filter { !$0.hasPrefix(".") }

        if apps.isEmpty {
            return "No apps found in Xcode Organizer cache."
        }

        var lines = ["Available apps in Xcode Organizer cache:"]
        for app in apps.sorted() {
            let crashDir = productsDir.appendingPathComponent(app).appendingPathComponent("Crashes/Points")
            let hasCrashes = fm.fileExists(atPath: crashDir.path)
            let crashCount = hasCrashes ? (try? fm.contentsOfDirectory(atPath: crashDir.path).filter { $0.hasSuffix(".xccrashpoint") }.count) ?? 0 : 0
            lines.append("  \(app)\(crashCount > 0 ? " — \(crashCount) crash signature(s)" : "")")
        }
        lines.append("\nUse organizer_list_crashes with bundle_id for details.")
        return lines.joined(separator: "\n")
    }

    private func countCrashLogs(bundleId: String, pointId: String) -> Int {
        findCrashLogs(bundleId: bundleId, pointId: pointId).count
    }

    private func findCrashLogs(bundleId: String, pointId: String?) -> [URL] {
        let fm = FileManager.default
        let pointsDir = productsDir
            .appendingPathComponent(bundleId)
            .appendingPathComponent("Crashes/Points")

        guard fm.fileExists(atPath: pointsDir.path) else { return [] }

        var results: [URL] = []

        guard let pointDirs = try? fm.contentsOfDirectory(atPath: pointsDir.path) else { return [] }

        for pointDir in pointDirs {
            // If pointId specified, filter by it
            if let pointId, !pointDir.contains(pointId) { continue }

            let filtersDir = pointsDir
                .appendingPathComponent(pointDir)
                .appendingPathComponent("Filters")

            guard let filters = try? fm.contentsOfDirectory(atPath: filtersDir.path) else { continue }

            for filter in filters {
                let logsDir = filtersDir
                    .appendingPathComponent(filter)
                    .appendingPathComponent("Logs")

                guard let logs = try? fm.contentsOfDirectory(atPath: logsDir.path) else { continue }

                for log in logs where log.hasSuffix(".crash") {
                    results.append(logsDir.appendingPathComponent(log))
                }
            }
        }

        return results
    }

    private func findDistributionInfo(bundleId: String, pointId: String) -> [URL] {
        let fm = FileManager.default
        let pointsDir = productsDir
            .appendingPathComponent(bundleId)
            .appendingPathComponent("Crashes/Points")

        guard fm.fileExists(atPath: pointsDir.path) else { return [] }

        var results: [URL] = []

        guard let pointDirs = try? fm.contentsOfDirectory(atPath: pointsDir.path) else { return [] }

        for pointDir in pointDirs where pointDir.contains(pointId) {
            let filtersDir = pointsDir
                .appendingPathComponent(pointDir)
                .appendingPathComponent("Filters")

            guard let filters = try? fm.contentsOfDirectory(atPath: filtersDir.path) else { continue }

            for filter in filters {
                let distFile = filtersDir
                    .appendingPathComponent(filter)
                    .appendingPathComponent("DistributionInfo.json")

                if fm.fileExists(atPath: distFile.path) {
                    results.append(distFile)
                }
            }
        }

        return results
    }

    /// Filter a .crash file to show only the most relevant sections.
    private func filterCrashLog(_ content: String, logURL: URL, totalCount: Int) -> String {
        let lines = content.components(separatedBy: "\n")
        var result: [String] = [
            "Crash Log (\(totalCount) total, showing most recent)",
            "File: \(logURL.lastPathComponent)",
            String(repeating: "=", count: 60),
        ]

        var section = ""
        var crashingThreadName = ""

        // Find crashing thread from "Triggered by Thread:" line
        for line in lines {
            if line.hasPrefix("Triggered by Thread:") {
                let num = line.replacingOccurrences(of: "Triggered by Thread:", with: "").trimmingCharacters(in: .whitespaces)
                crashingThreadName = "Thread \(num)"
                break
            }
        }

        var includeSection = false
        for line in lines {
            // Detect section headers
            if line.hasPrefix("Incident Identifier:") || line.hasPrefix("Distributor ID:") ||
               line.hasPrefix("Hardware Model:") || line.hasPrefix("Process:") ||
               line.hasPrefix("Identifier:") || line.hasPrefix("Version:") ||
               line.hasPrefix("Beta:") || line.hasPrefix("Code Type:") ||
               line.hasPrefix("Date/Time:") || line.hasPrefix("Launch Time:") ||
               line.hasPrefix("OS Version:") ||
               line.hasPrefix("Exception Type:") || line.hasPrefix("Exception Codes:") ||
               line.hasPrefix("Termination Reason:") || line.hasPrefix("Terminating Process:") ||
               line.hasPrefix("Triggered by Thread:") {
                result.append(line)
                continue
            }

            if line.hasPrefix("Last Exception Backtrace:") {
                section = "last_exception"
                includeSection = true
                result.append("")
                result.append(line)
                continue
            }

            if line.hasPrefix("\(crashingThreadName) Crashed:") || line.hasPrefix("\(crashingThreadName) name:") {
                section = "crashing_thread"
                includeSection = true
                result.append("")
                result.append(line)
                continue
            }

            if line.hasPrefix("Thread ") && !line.isEmpty && section != "" {
                // New thread section — stop if we were in crashing thread
                if section == "crashing_thread" {
                    includeSection = false
                    section = ""
                }
                if section == "last_exception" {
                    includeSection = false
                    section = ""
                }
            }

            if line.hasPrefix("Binary Images:") {
                includeSection = false
                section = ""
            }

            if includeSection {
                result.append(line)
            }
        }

        if totalCount > 1 {
            result.append("")
            result.append("\(totalCount - 1) more crash log(s) available. Use include_threads=true for full output.")
        }

        return result.joined(separator: "\n")
    }
}
