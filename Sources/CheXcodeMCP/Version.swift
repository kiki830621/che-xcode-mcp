import Foundation

/// Centralized version management
enum AppVersion {
    static let current = "0.1.0"
    static let name = "CheXcodeMCP"
    static let displayName = "App Store Connect MCP Server"

    static var versionString: String {
        "\(name) \(current)"
    }

    static var helpMessage: String {
        """
        \(displayName)

        Usage: \(name) [options]

        Options:
          --version, -v    Show version information
          --help, -h       Show this help message

        Version: \(current)
        Repository: https://github.com/kiki830621/che-xcode-mcp

        Environment variables:
          ASC_KEY_ID             App Store Connect API Key ID
          ASC_ISSUER_ID          App Store Connect Issuer ID
          ASC_PRIVATE_KEY_PATH   Path to .p8 private key file
        """
    }
}
