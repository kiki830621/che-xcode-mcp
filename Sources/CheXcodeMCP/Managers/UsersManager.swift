import Foundation
import MCP

// MARK: - ASC Attribute Models

struct UserAttributes: Decodable {
    let username: String?
    let firstName: String?
    let lastName: String?
    let email: String?
    let roles: [String]?
    let allAppsVisible: Bool?
    let provisioningAllowed: Bool?
}

struct UserInvitationAttributes: Decodable {
    let email: String?
    let firstName: String?
    let lastName: String?
    let roles: [String]?
    let allAppsVisible: Bool?
    let expirationDate: Date?
}

// MARK: - Type aliases

private typealias User = ASCResource<UserAttributes>
private typealias UserInvitation = ASCResource<UserInvitationAttributes>

// MARK: - UsersManager

actor UsersManager: ToolProvider {
    private let client: ASCClient

    init(client: ASCClient) {
        self.client = client
    }

    // MARK: - ToolProvider

    var tools: [Tool] {
        [
            Tool(
                name: "users_list_users",
                description: "List team users. Optionally filter by role.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "roles": .object([
                            "type": "string",
                            "description": "Comma-separated roles to filter by (e.g. ADMIN,DEVELOPER,MARKETING)"
                        ]),
                        "limit": .object([
                            "type": "integer",
                            "description": "Maximum number of users to return (default 50, max 200)"
                        ])
                    ])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "users_get_user",
                description: "Get detailed information about a specific team user.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "user_id": .object([
                            "type": "string",
                            "description": "The ASC user ID"
                        ])
                    ]),
                    "required": .array([.string("user_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "users_update_user_roles",
                description: "Update a user's roles. Replaces all existing roles with the provided set.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "user_id": .object([
                            "type": "string",
                            "description": "The ASC user ID"
                        ]),
                        "roles": .object([
                            "type": "string",
                            "description": "Comma-separated roles to assign (e.g. ADMIN,DEVELOPER,MARKETING)"
                        ])
                    ]),
                    "required": .array([.string("user_id"), .string("roles")])
                ]),
                annotations: .init(destructiveHint: false)
            ),
            Tool(
                name: "users_remove_user",
                description: "Remove a user from the team. This action cannot be undone.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "user_id": .object([
                            "type": "string",
                            "description": "The ASC user ID to remove"
                        ])
                    ]),
                    "required": .array([.string("user_id")])
                ]),
                annotations: .init(destructiveHint: true)
            ),
            Tool(
                name: "users_list_invitations",
                description: "List pending user invitations to the team.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "limit": .object([
                            "type": "integer",
                            "description": "Maximum number of invitations to return (default 50, max 200)"
                        ])
                    ])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "users_invite_user",
                description: "Invite a new user to the team by email with specified roles.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "email": .object([
                            "type": "string",
                            "description": "Email address of the user to invite"
                        ]),
                        "roles": .object([
                            "type": "string",
                            "description": "Comma-separated roles to assign (e.g. ADMIN,DEVELOPER,MARKETING)"
                        ]),
                        "first_name": .object([
                            "type": "string",
                            "description": "First name of the invited user"
                        ]),
                        "last_name": .object([
                            "type": "string",
                            "description": "Last name of the invited user"
                        ]),
                        "all_apps_visible": .object([
                            "type": "boolean",
                            "description": "Whether the user can see all apps (default false)"
                        ])
                    ]),
                    "required": .array([.string("email"), .string("roles")])
                ]),
                annotations: .init(destructiveHint: false)
            ),
            Tool(
                name: "users_cancel_invitation",
                description: "Cancel a pending user invitation. This action cannot be undone.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "invitation_id": .object([
                            "type": "string",
                            "description": "The ASC user invitation ID to cancel"
                        ])
                    ]),
                    "required": .array([.string("invitation_id")])
                ]),
                annotations: .init(destructiveHint: true)
            ),
        ]
    }

    func handle(_ name: String, arguments: [String: Value]) async throws -> String {
        switch name {
        case "users_list_users":
            return try await handleListUsers(arguments)
        case "users_get_user":
            return try await handleGetUser(arguments)
        case "users_update_user_roles":
            return try await handleUpdateUserRoles(arguments)
        case "users_remove_user":
            return try await handleRemoveUser(arguments)
        case "users_list_invitations":
            return try await handleListInvitations(arguments)
        case "users_invite_user":
            return try await handleInviteUser(arguments)
        case "users_cancel_invitation":
            return try await handleCancelInvitation(arguments)
        default:
            throw ASCClientError.invalidResponse("Unknown Users tool: \(name)")
        }
    }

    // MARK: - Handler: List Users

    private func handleListUsers(_ args: [String: Value]) async throws -> String {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "fields[users]", value: "username,firstName,lastName,roles,allAppsVisible,provisioningAllowed"),
            URLQueryItem(name: "sort", value: "lastName"),
        ]

        if let rolesString = stringValue(args, "roles") {
            let roles = rolesString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            queryItems.append(URLQueryItem(name: "filter[roles]", value: roles.joined(separator: ",")))
        }
        let limit = intValue(args, "limit") ?? 50
        queryItems.append(URLQueryItem(name: "limit", value: String(min(limit, 200))))

        let response: ASCListResponse<User> = try await client.getList(
            path: "/v1/users",
            queryItems: queryItems
        )

        if response.data.isEmpty {
            return "No users found."
        }

        var lines = ["Team Users (\(response.data.count)):"]
        lines.append(String(repeating: "-", count: 60))
        for user in response.data {
            lines.append(formatUser(user))
        }

        if let paging = response.meta?.paging, let total = paging.total {
            lines.append("\nShowing \(response.data.count) of \(total) total users.")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Handler: Get User

    private func handleGetUser(_ args: [String: Value]) async throws -> String {
        let userId = try requireString(args, "user_id")

        let queryItems = [
            URLQueryItem(name: "fields[users]", value: "username,firstName,lastName,roles,allAppsVisible,provisioningAllowed")
        ]

        let response: ASCResponse<User> = try await client.get(
            path: "/v1/users/\(userId)",
            queryItems: queryItems
        )

        return formatUserDetailed(response.data)
    }

    // MARK: - Handler: Update User Roles

    private func handleUpdateUserRoles(_ args: [String: Value]) async throws -> String {
        let userId = try requireString(args, "user_id")
        let rolesString = try requireString(args, "roles")
        let roles = rolesString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        let body: [String: Any] = [
            "data": [
                "type": "users",
                "id": userId,
                "attributes": [
                    "roles": roles
                ]
            ]
        ]

        let response: ASCResponse<User> = try await client.patch(
            path: "/v1/users/\(userId)",
            body: body
        )

        let updatedRoles = response.data.attributes?.roles ?? roles
        let displayName = formatUserName(response.data)

        return "Successfully updated roles for \(displayName).\nNew roles: \(updatedRoles.joined(separator: ", "))"
    }

    // MARK: - Handler: Remove User

    private func handleRemoveUser(_ args: [String: Value]) async throws -> String {
        let userId = try requireString(args, "user_id")

        try await client.delete(path: "/v1/users/\(userId)")

        return "Successfully removed user \(userId) from the team."
    }

    // MARK: - Handler: List Invitations

    private func handleListInvitations(_ args: [String: Value]) async throws -> String {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "fields[userInvitations]", value: "email,firstName,lastName,roles,allAppsVisible,expirationDate"),
            URLQueryItem(name: "sort", value: "email"),
        ]

        let limit = intValue(args, "limit") ?? 50
        queryItems.append(URLQueryItem(name: "limit", value: String(min(limit, 200))))

        let response: ASCListResponse<UserInvitation> = try await client.getList(
            path: "/v1/userInvitations",
            queryItems: queryItems
        )

        if response.data.isEmpty {
            return "No pending invitations found."
        }

        var lines = ["Pending Invitations (\(response.data.count)):"]
        lines.append(String(repeating: "-", count: 60))
        for invitation in response.data {
            lines.append(formatInvitation(invitation))
        }

        if let paging = response.meta?.paging, let total = paging.total {
            lines.append("\nShowing \(response.data.count) of \(total) total invitations.")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Handler: Invite User

    private func handleInviteUser(_ args: [String: Value]) async throws -> String {
        let email = try requireString(args, "email")
        let rolesString = try requireString(args, "roles")
        let roles = rolesString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let firstName = stringValue(args, "first_name")
        let lastName = stringValue(args, "last_name")
        let allAppsVisible = boolValue(args, "all_apps_visible") ?? false

        var attributes: [String: Any] = [
            "email": email,
            "roles": roles,
            "allAppsVisible": allAppsVisible,
        ]
        if let firstName { attributes["firstName"] = firstName }
        if let lastName { attributes["lastName"] = lastName }

        let body: [String: Any] = [
            "data": [
                "type": "userInvitations",
                "attributes": attributes
            ]
        ]

        let response: ASCResponse<UserInvitation> = try await client.post(
            path: "/v1/userInvitations",
            body: body
        )

        let invitation = response.data
        let name = [invitation.attributes?.firstName, invitation.attributes?.lastName]
            .compactMap { $0 }
            .joined(separator: " ")
        let displayName = name.isEmpty ? email : "\(name) (\(email))"
        let assignedRoles = invitation.attributes?.roles ?? roles

        return "Successfully invited \(displayName) to the team.\nInvitation ID: \(invitation.id)\nRoles: \(assignedRoles.joined(separator: ", "))"
    }

    // MARK: - Handler: Cancel Invitation

    private func handleCancelInvitation(_ args: [String: Value]) async throws -> String {
        let invitationId = try requireString(args, "invitation_id")

        try await client.delete(path: "/v1/userInvitations/\(invitationId)")

        return "Successfully cancelled invitation \(invitationId)."
    }

    // MARK: - Formatters

    private func formatUserName(_ user: User) -> String {
        let attrs = user.attributes
        let name = [attrs?.firstName, attrs?.lastName]
            .compactMap { $0 }
            .joined(separator: " ")
        let email = attrs?.email ?? "?"
        return name.isEmpty ? email : "\(name) (\(email))"
    }

    private func formatUser(_ user: User) -> String {
        let attrs = user.attributes
        let displayName = formatUserName(user)
        let roles = attrs?.roles?.joined(separator: ", ") ?? "No roles"
        return "  [\(user.id)] \(displayName) — Roles: \(roles)"
    }

    private func formatUserDetailed(_ user: User) -> String {
        let attrs = user.attributes
        let roles = attrs?.roles?.joined(separator: ", ") ?? "None"
        let lines = [
            "User Details",
            String(repeating: "-", count: 40),
            "  ID:                  \(user.id)",
            "  Username:            \(attrs?.username ?? "N/A")",
            "  First Name:          \(attrs?.firstName ?? "N/A")",
            "  Last Name:           \(attrs?.lastName ?? "N/A")",
            "  Email:               \(attrs?.email ?? "N/A")",
            "  Roles:               \(roles)",
            "  All Apps Visible:    \(attrs?.allAppsVisible == true ? "Yes" : "No")",
            "  Provisioning Allowed: \(attrs?.provisioningAllowed == true ? "Yes" : "No")",
        ]
        return lines.joined(separator: "\n")
    }

    private func formatInvitation(_ invitation: UserInvitation) -> String {
        let attrs = invitation.attributes
        let name = [attrs?.firstName, attrs?.lastName]
            .compactMap { $0 }
            .joined(separator: " ")
        let email = attrs?.email ?? "?"
        let displayName = name.isEmpty ? email : "\(name) <\(email)>"
        let roles = attrs?.roles?.joined(separator: ", ") ?? "No roles"
        let expiry = formatDate(attrs?.expirationDate)
        return "  [\(invitation.id)] \(displayName) — Roles: \(roles) | Expires: \(expiry)"
    }
}
