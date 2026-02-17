import Foundation
import MCP

// MARK: - ASC Attribute Models

struct CertificateAttributes: Decodable {
    let name: String?
    let certificateType: String?
    let displayName: String?
    let platform: String?
    let expirationDate: Date?
    let serialNumber: String?
}

struct DeviceAttributes: Decodable {
    let name: String?
    let platform: String?
    let udid: String?
    let deviceClass: String?
    let status: String?
    let model: String?
    let addedDate: Date?
}

struct BundleIdAttributes: Decodable {
    let name: String?
    let identifier: String?
    let platform: String?
    let seedId: String?
}

struct ProfileAttributes: Decodable {
    let name: String?
    let profileType: String?
    let profileState: String?
    let platform: String?
    let createdDate: Date?
    let expirationDate: Date?
    let uuid: String?
}

// MARK: - Type aliases

private typealias Certificate = ASCResource<CertificateAttributes>
private typealias Device = ASCResource<DeviceAttributes>
private typealias BundleId = ASCResource<BundleIdAttributes>
private typealias Profile = ASCResource<ProfileAttributes>

// MARK: - ProvisioningManager

actor ProvisioningManager: ToolProvider {
    private let client: ASCClient

    init(client: ASCClient) {
        self.client = client
    }

    // MARK: - ToolProvider

    var tools: [Tool] {
        [
            Tool(
                name: "provisioning_list_certificates",
                description: "List signing certificates. Optionally filter by certificate_type (IOS_DEVELOPMENT, IOS_DISTRIBUTION, MAC_APP_DISTRIBUTION, etc.).",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "certificate_type": .object([
                            "type": "string",
                            "description": "Filter by certificate type (IOS_DEVELOPMENT, IOS_DISTRIBUTION, MAC_APP_DISTRIBUTION, MAC_INSTALLER_DISTRIBUTION, MAC_APP_DEVELOPMENT, DEVELOPER_ID_KEXT, DEVELOPER_ID_APPLICATION, DEVELOPMENT, DISTRIBUTION)"
                        ]),
                        "limit": .object([
                            "type": "integer",
                            "description": "Maximum number of certificates to return (default 20, max 200)"
                        ])
                    ])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "provisioning_get_certificate",
                description: "Get detailed information about a specific signing certificate.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "certificate_id": .object([
                            "type": "string",
                            "description": "The ASC certificate ID"
                        ])
                    ]),
                    "required": .array([.string("certificate_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "provisioning_list_devices",
                description: "List registered devices. Optionally filter by platform and status.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "platform": .object([
                            "type": "string",
                            "description": "Filter by platform (IOS, MAC_OS)"
                        ]),
                        "status": .object([
                            "type": "string",
                            "description": "Filter by status (ENABLED, DISABLED)"
                        ]),
                        "limit": .object([
                            "type": "integer",
                            "description": "Maximum number of devices to return (default 50, max 200)"
                        ])
                    ])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "provisioning_register_device",
                description: "Register a new device for development or ad-hoc distribution.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "name": .object([
                            "type": "string",
                            "description": "A human-readable name for the device"
                        ]),
                        "udid": .object([
                            "type": "string",
                            "description": "The device UDID"
                        ]),
                        "platform": .object([
                            "type": "string",
                            "description": "Device platform (default: IOS). Options: IOS, MAC_OS"
                        ])
                    ]),
                    "required": .array([.string("name"), .string("udid")])
                ]),
                annotations: .init(destructiveHint: false)
            ),
            Tool(
                name: "provisioning_update_device",
                description: "Update a registered device's name or status (enable/disable).",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "device_id": .object([
                            "type": "string",
                            "description": "The ASC device ID"
                        ]),
                        "name": .object([
                            "type": "string",
                            "description": "New name for the device"
                        ]),
                        "status": .object([
                            "type": "string",
                            "description": "New status (ENABLED, DISABLED)"
                        ])
                    ]),
                    "required": .array([.string("device_id")])
                ]),
                annotations: .init(destructiveHint: false)
            ),
            Tool(
                name: "provisioning_list_bundle_ids",
                description: "List registered bundle IDs. Optionally filter by identifier string or platform.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "identifier": .object([
                            "type": "string",
                            "description": "Filter by bundle ID string (e.g. com.example.app)"
                        ]),
                        "platform": .object([
                            "type": "string",
                            "description": "Filter by platform (IOS, MAC_OS, UNIVERSAL)"
                        ]),
                        "limit": .object([
                            "type": "integer",
                            "description": "Maximum number of bundle IDs to return (default 20, max 200)"
                        ])
                    ])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "provisioning_list_profiles",
                description: "List provisioning profiles. Optionally filter by profile_type.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "profile_type": .object([
                            "type": "string",
                            "description": "Filter by profile type (IOS_APP_DEVELOPMENT, IOS_APP_STORE, IOS_APP_ADHOC, IOS_APP_INHOUSE, MAC_APP_DEVELOPMENT, MAC_APP_STORE, MAC_APP_DIRECT, TVOS_APP_DEVELOPMENT, TVOS_APP_STORE, TVOS_APP_ADHOC, MAC_CATALYST_APP_DEVELOPMENT, MAC_CATALYST_APP_STORE, MAC_CATALYST_APP_DIRECT)"
                        ]),
                        "limit": .object([
                            "type": "integer",
                            "description": "Maximum number of profiles to return (default 20, max 200)"
                        ])
                    ])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "provisioning_get_profile",
                description: "Get detailed information about a specific provisioning profile.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "profile_id": .object([
                            "type": "string",
                            "description": "The ASC profile ID"
                        ])
                    ]),
                    "required": .array([.string("profile_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
        ]
    }

    func handle(_ name: String, arguments: [String: Value]) async throws -> String {
        switch name {
        case "provisioning_list_certificates":
            return try await handleListCertificates(arguments)
        case "provisioning_get_certificate":
            return try await handleGetCertificate(arguments)
        case "provisioning_list_devices":
            return try await handleListDevices(arguments)
        case "provisioning_register_device":
            return try await handleRegisterDevice(arguments)
        case "provisioning_update_device":
            return try await handleUpdateDevice(arguments)
        case "provisioning_list_bundle_ids":
            return try await handleListBundleIds(arguments)
        case "provisioning_list_profiles":
            return try await handleListProfiles(arguments)
        case "provisioning_get_profile":
            return try await handleGetProfile(arguments)
        default:
            throw ASCClientError.invalidResponse("Unknown Provisioning tool: \(name)")
        }
    }

    // MARK: - Handler: List Certificates

    private func handleListCertificates(_ args: [String: Value]) async throws -> String {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "fields[certificates]", value: "name,certificateType,displayName,platform,expirationDate,serialNumber"),
            URLQueryItem(name: "sort", value: "displayName"),
        ]

        if let certType = stringValue(args, "certificate_type") {
            queryItems.append(URLQueryItem(name: "filter[certificateType]", value: certType))
        }
        let limit = intValue(args, "limit") ?? 20
        queryItems.append(URLQueryItem(name: "limit", value: String(min(limit, 200))))

        let response: ASCListResponse<Certificate> = try await client.getList(
            path: "/v1/certificates",
            queryItems: queryItems
        )

        if response.data.isEmpty {
            return "No certificates found."
        }

        var lines = ["Signing Certificates (\(response.data.count)):"]
        lines.append(String(repeating: "-", count: 60))
        for cert in response.data {
            lines.append(formatCertificate(cert))
        }

        if let paging = response.meta?.paging, let total = paging.total {
            lines.append("\nShowing \(response.data.count) of \(total) total certificates.")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Handler: Get Certificate

    private func handleGetCertificate(_ args: [String: Value]) async throws -> String {
        let certId = try requireString(args, "certificate_id")

        let queryItems = [
            URLQueryItem(name: "fields[certificates]", value: "name,certificateType,displayName,platform,expirationDate,serialNumber")
        ]

        let response: ASCResponse<Certificate> = try await client.get(
            path: "/v1/certificates/\(certId)",
            queryItems: queryItems
        )

        return formatCertificateDetailed(response.data)
    }

    // MARK: - Handler: List Devices

    private func handleListDevices(_ args: [String: Value]) async throws -> String {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "fields[devices]", value: "name,platform,udid,deviceClass,status,model,addedDate"),
            URLQueryItem(name: "sort", value: "name"),
        ]

        if let platform = stringValue(args, "platform") {
            queryItems.append(URLQueryItem(name: "filter[platform]", value: platform))
        }
        if let status = stringValue(args, "status") {
            queryItems.append(URLQueryItem(name: "filter[status]", value: status))
        }
        let limit = intValue(args, "limit") ?? 50
        queryItems.append(URLQueryItem(name: "limit", value: String(min(limit, 200))))

        let response: ASCListResponse<Device> = try await client.getList(
            path: "/v1/devices",
            queryItems: queryItems
        )

        if response.data.isEmpty {
            return "No devices found."
        }

        var lines = ["Registered Devices (\(response.data.count)):"]
        lines.append(String(repeating: "-", count: 60))
        for device in response.data {
            lines.append(formatDevice(device))
        }

        if let paging = response.meta?.paging, let total = paging.total {
            lines.append("\nShowing \(response.data.count) of \(total) total devices.")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Handler: Register Device

    private func handleRegisterDevice(_ args: [String: Value]) async throws -> String {
        let name = try requireString(args, "name")
        let udid = try requireString(args, "udid")
        let platform = stringValue(args, "platform") ?? "IOS"

        let body: [String: Any] = [
            "data": [
                "type": "devices",
                "attributes": [
                    "name": name,
                    "udid": udid,
                    "platform": platform
                ]
            ]
        ]

        let response: ASCResponse<Device> = try await client.post(
            path: "/v1/devices",
            body: body
        )

        let device = response.data
        let deviceName = device.attributes?.name ?? name
        let deviceUdid = device.attributes?.udid ?? udid

        return "Successfully registered device.\n  Name: \(deviceName)\n  UDID: \(deviceUdid)\n  Platform: \(platform)\n  Device ID: \(device.id)"
    }

    // MARK: - Handler: Update Device

    private func handleUpdateDevice(_ args: [String: Value]) async throws -> String {
        let deviceId = try requireString(args, "device_id")

        var attributes: [String: Any] = [:]
        if let name = stringValue(args, "name") {
            attributes["name"] = name
        }
        if let status = stringValue(args, "status") {
            attributes["status"] = status
        }

        if attributes.isEmpty {
            return "No updates specified. Provide at least one of: name, status."
        }

        let body: [String: Any] = [
            "data": [
                "type": "devices",
                "id": deviceId,
                "attributes": attributes
            ]
        ]

        let response: ASCResponse<Device> = try await client.patch(
            path: "/v1/devices/\(deviceId)",
            body: body
        )

        let device = response.data
        let deviceName = device.attributes?.name ?? "?"
        let deviceStatus = device.attributes?.status ?? "?"

        return "Successfully updated device \(deviceId).\n  Name: \(deviceName)\n  Status: \(deviceStatus)"
    }

    // MARK: - Handler: List Bundle IDs

    private func handleListBundleIds(_ args: [String: Value]) async throws -> String {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "fields[bundleIds]", value: "name,identifier,platform,seedId"),
            URLQueryItem(name: "sort", value: "identifier"),
        ]

        if let identifier = stringValue(args, "identifier") {
            queryItems.append(URLQueryItem(name: "filter[identifier]", value: identifier))
        }
        if let platform = stringValue(args, "platform") {
            queryItems.append(URLQueryItem(name: "filter[platform]", value: platform))
        }
        let limit = intValue(args, "limit") ?? 20
        queryItems.append(URLQueryItem(name: "limit", value: String(min(limit, 200))))

        let response: ASCListResponse<BundleId> = try await client.getList(
            path: "/v1/bundleIds",
            queryItems: queryItems
        )

        if response.data.isEmpty {
            return "No bundle IDs found."
        }

        var lines = ["Bundle IDs (\(response.data.count)):"]
        lines.append(String(repeating: "-", count: 60))
        for bundleId in response.data {
            lines.append(formatBundleId(bundleId))
        }

        if let paging = response.meta?.paging, let total = paging.total {
            lines.append("\nShowing \(response.data.count) of \(total) total bundle IDs.")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Handler: List Profiles

    private func handleListProfiles(_ args: [String: Value]) async throws -> String {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "fields[profiles]", value: "name,profileType,profileState,platform,createdDate,expirationDate,uuid"),
            URLQueryItem(name: "sort", value: "name"),
        ]

        if let profileType = stringValue(args, "profile_type") {
            queryItems.append(URLQueryItem(name: "filter[profileType]", value: profileType))
        }
        let limit = intValue(args, "limit") ?? 20
        queryItems.append(URLQueryItem(name: "limit", value: String(min(limit, 200))))

        let response: ASCListResponse<Profile> = try await client.getList(
            path: "/v1/profiles",
            queryItems: queryItems
        )

        if response.data.isEmpty {
            return "No provisioning profiles found."
        }

        var lines = ["Provisioning Profiles (\(response.data.count)):"]
        lines.append(String(repeating: "-", count: 60))
        for profile in response.data {
            lines.append(formatProfile(profile))
        }

        if let paging = response.meta?.paging, let total = paging.total {
            lines.append("\nShowing \(response.data.count) of \(total) total profiles.")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Handler: Get Profile

    private func handleGetProfile(_ args: [String: Value]) async throws -> String {
        let profileId = try requireString(args, "profile_id")

        let queryItems = [
            URLQueryItem(name: "fields[profiles]", value: "name,profileType,profileState,platform,createdDate,expirationDate,uuid")
        ]

        let response: ASCResponse<Profile> = try await client.get(
            path: "/v1/profiles/\(profileId)",
            queryItems: queryItems
        )

        return formatProfileDetailed(response.data)
    }

    // MARK: - Formatters

    private func formatCertificate(_ cert: Certificate) -> String {
        let attrs = cert.attributes
        let name = attrs?.displayName ?? attrs?.name ?? "Unnamed"
        let certType = attrs?.certificateType ?? "UNKNOWN"
        let expiration = formatDate(attrs?.expirationDate)
        let serial = attrs?.serialNumber ?? "?"
        return "  [\(cert.id)] \(name) — \(certType) | Expires: \(expiration) | Serial: \(serial)"
    }

    private func formatCertificateDetailed(_ cert: Certificate) -> String {
        let attrs = cert.attributes
        var lines = [
            "Certificate Details",
            String(repeating: "-", count: 60),
            "  ID:              \(cert.id)",
            "  Name:            \(attrs?.name ?? "N/A")",
            "  Display Name:    \(attrs?.displayName ?? "N/A")",
            "  Type:            \(attrs?.certificateType ?? "N/A")",
            "  Platform:        \(attrs?.platform ?? "N/A")",
            "  Serial Number:   \(attrs?.serialNumber ?? "N/A")",
            "  Expiration:      \(formatDate(attrs?.expirationDate))",
        ]
        if let expDate = attrs?.expirationDate {
            let daysRemaining = Calendar.current.dateComponents([.day], from: Date(), to: expDate).day ?? 0
            if daysRemaining < 0 {
                lines.append("  Status:          EXPIRED (\(-daysRemaining) days ago)")
            } else if daysRemaining < 30 {
                lines.append("  Status:          EXPIRING SOON (\(daysRemaining) days remaining)")
            } else {
                lines.append("  Status:          Valid (\(daysRemaining) days remaining)")
            }
        }
        return lines.joined(separator: "\n")
    }

    private func formatDevice(_ device: Device) -> String {
        let attrs = device.attributes
        let name = attrs?.name ?? "Unnamed"
        let platform = attrs?.platform ?? "?"
        let status = attrs?.status ?? "UNKNOWN"
        let deviceClass = attrs?.deviceClass ?? "?"
        let udid = attrs?.udid ?? "?"
        return "  [\(device.id)] \(name) — \(platform) \(deviceClass) | \(status) | UDID: \(udid)"
    }

    private func formatBundleId(_ bundleId: BundleId) -> String {
        let attrs = bundleId.attributes
        let name = attrs?.name ?? "Unnamed"
        let identifier = attrs?.identifier ?? "?"
        let platform = attrs?.platform ?? "?"
        return "  [\(bundleId.id)] \(name) — \(identifier) | \(platform)"
    }

    private func formatProfile(_ profile: Profile) -> String {
        let attrs = profile.attributes
        let name = attrs?.name ?? "Unnamed"
        let profileType = attrs?.profileType ?? "UNKNOWN"
        let state = attrs?.profileState ?? "UNKNOWN"
        let expiration = formatDate(attrs?.expirationDate)
        return "  [\(profile.id)] \(name) — \(profileType) | \(state) | Expires: \(expiration)"
    }

    private func formatProfileDetailed(_ profile: Profile) -> String {
        let attrs = profile.attributes
        var lines = [
            "Provisioning Profile Details",
            String(repeating: "-", count: 60),
            "  ID:              \(profile.id)",
            "  Name:            \(attrs?.name ?? "N/A")",
            "  Type:            \(attrs?.profileType ?? "N/A")",
            "  State:           \(attrs?.profileState ?? "N/A")",
            "  Platform:        \(attrs?.platform ?? "N/A")",
            "  UUID:            \(attrs?.uuid ?? "N/A")",
            "  Created:         \(formatDate(attrs?.createdDate))",
            "  Expiration:      \(formatDate(attrs?.expirationDate))",
        ]
        if let expDate = attrs?.expirationDate {
            let daysRemaining = Calendar.current.dateComponents([.day], from: Date(), to: expDate).day ?? 0
            if daysRemaining < 0 {
                lines.append("  Status:          EXPIRED (\(-daysRemaining) days ago)")
            } else if daysRemaining < 30 {
                lines.append("  Status:          EXPIRING SOON (\(daysRemaining) days remaining)")
            } else {
                lines.append("  Status:          Valid (\(daysRemaining) days remaining)")
            }
        }
        return lines.joined(separator: "\n")
    }
}
