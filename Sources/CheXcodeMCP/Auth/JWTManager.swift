import Foundation
import CryptoKit

/// Manages JWT token generation for App Store Connect API authentication.
/// Uses ES256 (P-256 ECDSA) signing with Apple's CryptoKit.
actor JWTManager {
    private let keyID: String
    private let issuerID: String
    private let privateKeyPath: String

    private var cachedToken: String?
    private var tokenExpiration: Date?

    /// Token validity: 20 minutes. Refresh 2 minutes early.
    private let tokenLifetime: TimeInterval = 20 * 60
    private let refreshBuffer: TimeInterval = 2 * 60

    init(keyID: String, issuerID: String, privateKeyPath: String) {
        self.keyID = keyID
        self.issuerID = issuerID
        self.privateKeyPath = privateKeyPath
    }

    /// Convenience init from environment variables.
    init(fromEnvironment: Void = ()) throws {
        guard let keyID = ProcessInfo.processInfo.environment["ASC_KEY_ID"] else {
            throw JWTError.missingEnvVar("ASC_KEY_ID")
        }
        guard let issuerID = ProcessInfo.processInfo.environment["ASC_ISSUER_ID"] else {
            throw JWTError.missingEnvVar("ASC_ISSUER_ID")
        }
        let keyPath = ProcessInfo.processInfo.environment["ASC_PRIVATE_KEY_PATH"]
            ?? "~/.appstoreconnect/private_keys/AuthKey_\(keyID).p8"
        self.init(
            keyID: keyID,
            issuerID: issuerID,
            privateKeyPath: NSString(string: keyPath).expandingTildeInPath
        )
    }

    /// Get a valid JWT token, refreshing if needed.
    func getToken() async throws -> String {
        if let token = cachedToken, !tokenNeedsRefresh() {
            return token
        }
        let token = try generateToken()
        cachedToken = token
        tokenExpiration = Date().addingTimeInterval(tokenLifetime)
        return token
    }

    /// Force token refresh on next getToken() call.
    func invalidateToken() {
        cachedToken = nil
        tokenExpiration = nil
    }

    func tokenNeedsRefresh() -> Bool {
        guard let expiration = tokenExpiration else { return true }
        return Date() >= expiration.addingTimeInterval(-refreshBuffer)
    }

    // MARK: - Token Generation

    private func generateToken() throws -> String {
        let header = try Self.buildHeader(keyID: keyID)
        let payload = try Self.buildPayload(issuerID: issuerID, expirationInterval: tokenLifetime)
        let signingInput = "\(header).\(payload)"

        let privateKey = try loadPrivateKey()
        let signature = try privateKey.signature(
            for: Data(signingInput.utf8)
        )
        let signatureBase64 = signature.rawRepresentation.base64URLEncoded()

        return "\(signingInput).\(signatureBase64)"
    }

    private func loadPrivateKey() throws -> P256.Signing.PrivateKey {
        let keyData = try String(contentsOfFile: privateKeyPath, encoding: .utf8)
        // Strip PEM headers
        let stripped = keyData
            .replacingOccurrences(of: "-----BEGIN PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "-----END PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
        guard let derData = Data(base64Encoded: stripped) else {
            throw JWTError.invalidKeyFormat
        }
        return try P256.Signing.PrivateKey(derRepresentation: derData)
    }

    // MARK: - Static Helpers (testable)

    static func buildHeader(keyID: String) throws -> String {
        let header: [String: String] = ["alg": "ES256", "kid": keyID, "typ": "JWT"]
        let data = try JSONSerialization.data(withJSONObject: header, options: .sortedKeys)
        return data.base64URLEncoded()
    }

    static func buildPayload(issuerID: String, expirationInterval: TimeInterval) throws -> String {
        let now = Date()
        let payload: [String: Any] = [
            "iss": issuerID,
            "iat": Int(now.timeIntervalSince1970),
            "exp": Int(now.addingTimeInterval(expirationInterval).timeIntervalSince1970),
            "aud": "appstoreconnect-v1"
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: .sortedKeys)
        return data.base64URLEncoded()
    }
}

// MARK: - Base64URL Encoding

extension Data {
    func base64URLEncoded() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    init?(base64URLDecoded string: String) {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 {
            base64.append("=")
        }
        self.init(base64Encoded: base64)
    }
}

// MARK: - Errors

enum JWTError: LocalizedError {
    case missingEnvVar(String)
    case invalidKeyFormat

    var errorDescription: String? {
        switch self {
        case .missingEnvVar(let name):
            return "Missing environment variable: \(name). Set it in your MCP config."
        case .invalidKeyFormat:
            return "Invalid .p8 private key format. Expected PEM-encoded PKCS#8."
        }
    }
}
