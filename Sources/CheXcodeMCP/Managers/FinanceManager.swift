import Foundation
import MCP

// MARK: - FinanceManager

actor FinanceManager: ToolProvider {
    private let client: ASCClient

    init(client: ASCClient) {
        self.client = client
    }

    // MARK: - ToolProvider

    var tools: [Tool] {
        [
            Tool(
                name: "finance_get_sales_report",
                description: "Get sales and trends report (returns CSV/TSV data). Supports SALES, SUBSCRIPTION, SUBSCRIPTION_EVENT, SUBSCRIBER, and PRE_ORDER report types.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "vendor_number": .object([
                            "type": "string",
                            "description": "Your vendor number from App Store Connect (found in Financial Reports settings)"
                        ]),
                        "report_type": .object([
                            "type": "string",
                            "description": "Type of report: SALES, SUBSCRIPTION, SUBSCRIPTION_EVENT, SUBSCRIBER, or PRE_ORDER"
                        ]),
                        "frequency": .object([
                            "type": "string",
                            "description": "Report frequency: DAILY, WEEKLY, MONTHLY, or YEARLY"
                        ]),
                        "report_date": .object([
                            "type": "string",
                            "description": "Report date in YYYY-MM-DD format (optional, defaults to most recent available)"
                        ]),
                    ]),
                    "required": .array([.string("vendor_number"), .string("report_type"), .string("frequency")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "finance_get_finance_report",
                description: "Get financial report for a specific region and month. Returns CSV/TSV payment and financial data.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "vendor_number": .object([
                            "type": "string",
                            "description": "Your vendor number from App Store Connect"
                        ]),
                        "region_code": .object([
                            "type": "string",
                            "description": "Region code (e.g., \"US\", \"EU\", \"JP\", \"AU\", \"CA\")"
                        ]),
                        "report_date": .object([
                            "type": "string",
                            "description": "Report month in YYYY-MM format"
                        ]),
                    ]),
                    "required": .array([.string("vendor_number"), .string("region_code"), .string("report_date")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "finance_list_sales_report_types",
                description: "Explain available sales and finance report types, frequencies, and sub-types. No API call — returns reference information.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([:])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
        ]
    }

    func handle(_ name: String, arguments: [String: Value]) async throws -> String {
        switch name {
        case "finance_get_sales_report":
            return try await handleGetSalesReport(arguments)
        case "finance_get_finance_report":
            return try await handleGetFinanceReport(arguments)
        case "finance_list_sales_report_types":
            return handleListSalesReportTypes()
        default:
            throw ASCClientError.invalidResponse("Unknown finance tool: \(name)")
        }
    }

    // MARK: - Handler: Get Sales Report

    private func handleGetSalesReport(_ args: [String: Value]) async throws -> String {
        let vendorNumber = try requireString(args, "vendor_number")
        let reportType = try requireString(args, "report_type")
        let frequency = try requireString(args, "frequency")

        var queryItems = [
            URLQueryItem(name: "filter[vendorNumber]", value: vendorNumber),
            URLQueryItem(name: "filter[reportType]", value: reportType),
            URLQueryItem(name: "filter[frequency]", value: frequency),
            URLQueryItem(name: "filter[reportSubType]", value: "SUMMARY"),
        ]

        if let reportDate = stringValue(args, "report_date") {
            queryItems.append(URLQueryItem(name: "filter[reportDate]", value: reportDate))
        }

        let csv = try await client.getRaw(path: "/v1/salesReports", queryItems: queryItems)
        return csv
    }

    // MARK: - Handler: Get Finance Report

    private func handleGetFinanceReport(_ args: [String: Value]) async throws -> String {
        let vendorNumber = try requireString(args, "vendor_number")
        let regionCode = try requireString(args, "region_code")
        let reportDate = try requireString(args, "report_date")

        let queryItems = [
            URLQueryItem(name: "filter[vendorNumber]", value: vendorNumber),
            URLQueryItem(name: "filter[regionCode]", value: regionCode),
            URLQueryItem(name: "filter[reportDate]", value: reportDate),
            URLQueryItem(name: "filter[reportType]", value: "FINANCIAL"),
        ]

        let csv = try await client.getRaw(path: "/v1/financeReports", queryItems: queryItems)
        return csv
    }

    // MARK: - Handler: List Sales Report Types

    private func handleListSalesReportTypes() -> String {
        let separator = String(repeating: "-", count: 60)

        return """
        App Store Connect — Sales & Finance Reports Reference
        \(separator)

        SALES REPORTS (/v1/salesReports)
        \(separator)

        Report Types:
          SALES               — App and in-app purchase sales data
          SUBSCRIPTION         — Active subscription counts and status
          SUBSCRIPTION_EVENT   — Subscription lifecycle events (new, renew, cancel)
          SUBSCRIBER           — Subscriber-level detail (anonymized)
          PRE_ORDER            — Pre-order activity

        Frequencies:
          DAILY    — Available for SALES, SUBSCRIPTION_EVENT, SUBSCRIBER, PRE_ORDER
          WEEKLY   — Available for SALES, SUBSCRIPTION, PRE_ORDER
          MONTHLY  — Available for SALES, SUBSCRIPTION, SUBSCRIPTION_EVENT, PRE_ORDER
          YEARLY   — Available for SALES

        Report Sub-Types:
          SUMMARY   — Aggregated summary (default, used by this tool)
          DETAILED  — Line-item detail
          OPT_IN    — Opt-in data (SUBSCRIPTION only)

        Report Date Format:
          YYYY-MM-DD for DAILY/WEEKLY
          YYYY-MM    for MONTHLY
          YYYY       for YEARLY

        \(separator)

        FINANCE REPORTS (/v1/financeReports)
        \(separator)

        Report Type:
          FINANCIAL — Payment and financial settlement data

        Region Codes (common):
          US — Americas (United States)
          EU — Europe
          JP — Japan
          AU — Australia / New Zealand
          CA — Canada
          GB — United Kingdom
          CN — China
          WW — Rest of World

        Report Date Format:
          YYYY-MM (month of the financial period)

        \(separator)

        Notes:
        - Reports are generated by Apple and may take 1-2 days to become available.
        - Daily sales reports are typically available by 5:00 AM PST next day.
        - Financial reports are available after the close of each fiscal period.
        - All report endpoints return raw CSV/TSV text, not JSON.
        """
    }
}
