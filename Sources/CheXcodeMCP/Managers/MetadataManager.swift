import CryptoKit
import Foundation
import MCP

// MARK: - ASC Attribute Models

struct AppStoreVersionAttributes: Decodable {
    let versionString: String?
    let platform: String?
    let appStoreState: String?
    let copyright: String?
    let releaseType: String?
    let earliestReleaseDate: Date?
    let createdDate: Date?
}

struct AppStoreVersionLocalizationAttributes: Decodable {
    let locale: String?
    let description: String?
    let keywords: String?
    let whatsNew: String?
    let promotionalText: String?
    let marketingUrl: String?
    let supportUrl: String?
}

struct AppStoreVersionPhasedReleaseAttributes: Decodable {
    let phasedReleaseState: String?
    let startDate: Date?
    let totalPauseDuration: Int?
    let currentDayNumber: Int?
}

struct AppStoreReviewDetailAttributes: Decodable {
    let contactFirstName: String?
    let contactLastName: String?
    let contactPhone: String?
    let contactEmail: String?
    let demoAccountName: String?
    let demoAccountPassword: String?
    let demoAccountRequired: Bool?
    let notes: String?
}

struct AgeRatingDeclarationAttributes: Decodable {
    let alcoholTobaccoOrDrugUseOrReferences: String?
    let contests: String?
    let gambling: Bool?
    let gamblingSimulated: String?
    let horrorOrFearThemes: String?
    let matureOrSuggestiveThemes: String?
    let medicalOrTreatmentInformation: String?
    let profanityOrCrudeHumor: String?
    let sexualContentGraphicAndNudity: String?
    let sexualContentOrNudity: String?
    let violenceCartoonOrFantasy: String?
    let violenceRealistic: String?
    let violenceRealisticProlonged: String?
    let ageRatingOverride: String?
    let koreaAgeRatingOverride: String?
    let seventeenPlus: Bool?
    let gamblingAndContests: Bool?
}

struct AppScreenshotSetAttributes: Decodable {
    let screenshotDisplayType: String?
}

struct AppScreenshotAttributes: Decodable {
    let fileSize: Int?
    let fileName: String?
    let sourceFileChecksum: String?
}

/// Extended screenshot attributes including upload operations (returned by POST /v1/appScreenshots)
struct AppScreenshotUploadAttributes: Decodable {
    let fileSize: Int?
    let fileName: String?
    let sourceFileChecksum: String?
    let uploadOperations: [ASCUploadOperation]?
    let assetDeliveryState: ASCAssetDeliveryState?
}

struct ASCUploadOperation: Decodable {
    let method: String?
    let url: String?
    let length: Int?
    let offset: Int?
    let requestHeaders: [ASCUploadHeader]?
}

struct ASCUploadHeader: Decodable {
    let name: String?
    let value: String?
}

struct ASCAssetDeliveryState: Decodable {
    let state: String?
    let errors: [ASCAssetError]?
}

struct ASCAssetError: Decodable {
    let code: String?
    let description: String?
}

struct AppStoreVersionReleaseRequestAttributes: Decodable {
    // This resource has no significant attributes
}

// MARK: - Type aliases

private typealias AppStoreVersion = ASCResource<AppStoreVersionAttributes>
private typealias AppStoreVersionLocalization = ASCResource<AppStoreVersionLocalizationAttributes>
private typealias AppStoreVersionPhasedRelease = ASCResource<AppStoreVersionPhasedReleaseAttributes>
private typealias AppStoreReviewDetail = ASCResource<AppStoreReviewDetailAttributes>
private typealias AgeRatingDeclaration = ASCResource<AgeRatingDeclarationAttributes>
private typealias AppScreenshotSet = ASCResource<AppScreenshotSetAttributes>
private typealias AppScreenshot = ASCResource<AppScreenshotAttributes>
private typealias AppScreenshotUpload = ASCResource<AppScreenshotUploadAttributes>
private typealias AppStoreVersionReleaseRequest = ASCResource<AppStoreVersionReleaseRequestAttributes>
// Build type is defined in TestFlightManager.swift — reusable here
private typealias Build = ASCResource<BuildAttributes>

// MARK: - MetadataManager

actor MetadataManager: ToolProvider {
    private let client: ASCClient

    init(client: ASCClient) {
        self.client = client
    }

    // MARK: - ToolProvider

    var tools: [Tool] {
        [
            // --- Version CRUD ---
            Tool(
                name: "metadata_list_versions",
                description: "List App Store versions (e.g., v1.0, v1.1) for an app. Returns version UUIDs, version strings, platform, and review state. Use version UUIDs as version_id in metadata_get_version, metadata_update_version, review_submit_for_review. Note: these are App Store release versions, NOT TestFlight builds.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "app_id": .object([
                            "type": "string",
                            "description": "App Store Connect app ID (required)"
                        ]),
                        "platform": .object([
                            "type": "string",
                            "description": "Filter by platform (IOS, MAC_OS)"
                        ]),
                        "version_state": .object([
                            "type": "string",
                            "description": "Filter by version state (e.g. READY_FOR_SALE, PREPARE_FOR_SUBMISSION, WAITING_FOR_REVIEW)"
                        ])
                    ]),
                    "required": .array([.string("app_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "metadata_get_version",
                description: "Get detailed information about a specific App Store version.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "version_id": .object([
                            "type": "string",
                            "description": "The App Store version ID"
                        ])
                    ]),
                    "required": .array([.string("version_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "metadata_create_version",
                description: "Create a new App Store version for an app.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "app_id": .object([
                            "type": "string",
                            "description": "App Store Connect app ID"
                        ]),
                        "version_string": .object([
                            "type": "string",
                            "description": "Version string (e.g. 1.2.0)"
                        ]),
                        "platform": .object([
                            "type": "string",
                            "description": "Platform (default: IOS). Options: IOS, MAC_OS"
                        ])
                    ]),
                    "required": .array([.string("app_id"), .string("version_string")])
                ]),
                annotations: .init(destructiveHint: false)
            ),
            Tool(
                name: "metadata_update_version",
                description: "Update App Store version attributes such as copyright, release type, or earliest release date.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "version_id": .object([
                            "type": "string",
                            "description": "The App Store version ID to update"
                        ]),
                        "version_string": .object([
                            "type": "string",
                            "description": "New version string"
                        ]),
                        "copyright": .object([
                            "type": "string",
                            "description": "Copyright text (e.g. 2025 My Company)"
                        ]),
                        "release_type": .object([
                            "type": "string",
                            "description": "Release type: MANUAL, AFTER_APPROVAL, or SCHEDULED"
                        ]),
                        "earliest_release_date": .object([
                            "type": "string",
                            "description": "Earliest release date in ISO 8601 format (for SCHEDULED release type)"
                        ])
                    ]),
                    "required": .array([.string("version_id")])
                ]),
                annotations: .init(destructiveHint: false)
            ),

            // --- Localizations ---
            Tool(
                name: "metadata_list_localizations",
                description: "List all localizations for an App Store version. Shows locale, description, keywords, and what's new.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "version_id": .object([
                            "type": "string",
                            "description": "The App Store version ID"
                        ])
                    ]),
                    "required": .array([.string("version_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "metadata_update_localization",
                description: "Update an App Store version localization (description, keywords, what's new, etc.).",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "localization_id": .object([
                            "type": "string",
                            "description": "The localization ID to update"
                        ]),
                        "description": .object([
                            "type": "string",
                            "description": "App description text"
                        ]),
                        "keywords": .object([
                            "type": "string",
                            "description": "Search keywords (comma-separated)"
                        ]),
                        "whatsNew": .object([
                            "type": "string",
                            "description": "What's New in This Version text"
                        ]),
                        "promotionalText": .object([
                            "type": "string",
                            "description": "Promotional text (can be updated without a new version)"
                        ]),
                        "marketingUrl": .object([
                            "type": "string",
                            "description": "Marketing URL"
                        ]),
                        "supportUrl": .object([
                            "type": "string",
                            "description": "Support URL"
                        ])
                    ]),
                    "required": .array([.string("localization_id")])
                ]),
                annotations: .init(destructiveHint: false)
            ),
            Tool(
                name: "metadata_create_localization",
                description: "Add a new localization (language) to an App Store version. Use this to add support for a new locale. Get version_id from metadata_list_versions.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "version_id": .object([
                            "type": "string",
                            "description": "The App Store version ID"
                        ]),
                        "locale": .object([
                            "type": "string",
                            "description": "Locale code (e.g. en-US, zh-Hant, ja)"
                        ]),
                        "description": .object([
                            "type": "string",
                            "description": "App description text"
                        ]),
                        "keywords": .object([
                            "type": "string",
                            "description": "Search keywords (comma-separated)"
                        ]),
                        "whatsNew": .object([
                            "type": "string",
                            "description": "What's New in This Version text"
                        ]),
                        "promotionalText": .object([
                            "type": "string",
                            "description": "Promotional text"
                        ]),
                        "marketingUrl": .object([
                            "type": "string",
                            "description": "Marketing URL"
                        ]),
                        "supportUrl": .object([
                            "type": "string",
                            "description": "Support URL"
                        ])
                    ]),
                    "required": .array([.string("version_id"), .string("locale")])
                ]),
                annotations: .init(destructiveHint: false)
            ),

            // --- Build Linking ---
            Tool(
                name: "metadata_get_build_for_version",
                description: "Get the build currently linked to an App Store version. Shows build version number, upload date, and processing state. A version needs a linked build before it can be submitted for review.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "version_id": .object([
                            "type": "string",
                            "description": "The App Store version ID"
                        ])
                    ]),
                    "required": .array([.string("version_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "metadata_set_build_for_version",
                description: "Link (or unlink) a build to an App Store version. This is required before submitting for review. Get build_id from testflight_list_builds. Pass null/empty build_id to unlink the current build.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "version_id": .object([
                            "type": "string",
                            "description": "The App Store version ID"
                        ]),
                        "build_id": .object([
                            "type": "string",
                            "description": "The build UUID to link (from testflight_list_builds). Omit or pass empty string to unlink."
                        ])
                    ]),
                    "required": .array([.string("version_id")])
                ]),
                annotations: .init(destructiveHint: false)
            ),

            // --- Review Detail ---
            Tool(
                name: "metadata_get_review_detail",
                description: "Get the App Store review detail for a version (contact info, demo account credentials, review notes). This information is required for App Store review submission.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "version_id": .object([
                            "type": "string",
                            "description": "The App Store version ID"
                        ])
                    ]),
                    "required": .array([.string("version_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "metadata_update_review_detail",
                description: "Update App Store review detail — contact information, demo account credentials, and review notes. Get review_detail_id from metadata_get_review_detail.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "review_detail_id": .object([
                            "type": "string",
                            "description": "The review detail ID (from metadata_get_review_detail)"
                        ]),
                        "contact_first_name": .object([
                            "type": "string",
                            "description": "Contact first name"
                        ]),
                        "contact_last_name": .object([
                            "type": "string",
                            "description": "Contact last name"
                        ]),
                        "contact_phone": .object([
                            "type": "string",
                            "description": "Contact phone number"
                        ]),
                        "contact_email": .object([
                            "type": "string",
                            "description": "Contact email address"
                        ]),
                        "demo_account_name": .object([
                            "type": "string",
                            "description": "Demo account username"
                        ]),
                        "demo_account_password": .object([
                            "type": "string",
                            "description": "Demo account password"
                        ]),
                        "demo_account_required": .object([
                            "type": "boolean",
                            "description": "Whether a demo account is required for review"
                        ]),
                        "notes": .object([
                            "type": "string",
                            "description": "Notes for the reviewer"
                        ])
                    ]),
                    "required": .array([.string("review_detail_id")])
                ]),
                annotations: .init(destructiveHint: false)
            ),

            // --- Phased Release ---
            Tool(
                name: "metadata_get_phased_release",
                description: "Get phased release status for an App Store version. Shows rollout day, state, and pause duration.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "version_id": .object([
                            "type": "string",
                            "description": "The App Store version ID"
                        ])
                    ]),
                    "required": .array([.string("version_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "metadata_create_phased_release",
                description: "Enable phased release for an App Store version. The update will roll out gradually over 7 days (1%, 2%, 5%, 10%, 20%, 50%, 100%). Can be paused/resumed with metadata_update_phased_release.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "version_id": .object([
                            "type": "string",
                            "description": "The App Store version ID"
                        ])
                    ]),
                    "required": .array([.string("version_id")])
                ]),
                annotations: .init(destructiveHint: false)
            ),
            Tool(
                name: "metadata_update_phased_release",
                description: "Update phased release state: ACTIVE (resume rollout), PAUSED (pause rollout), or COMPLETE (release to all users immediately).",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "phased_release_id": .object([
                            "type": "string",
                            "description": "The phased release ID (from metadata_get_phased_release)"
                        ]),
                        "state": .object([
                            "type": "string",
                            "description": "New state: ACTIVE, PAUSED, or COMPLETE"
                        ])
                    ]),
                    "required": .array([.string("phased_release_id"), .string("state")])
                ]),
                annotations: .init(destructiveHint: false)
            ),
            Tool(
                name: "metadata_delete_phased_release",
                description: "Remove phased release configuration from an App Store version. The version will release to all users at once when approved.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "phased_release_id": .object([
                            "type": "string",
                            "description": "The phased release ID (from metadata_get_phased_release)"
                        ])
                    ]),
                    "required": .array([.string("phased_release_id")])
                ]),
                annotations: .init(destructiveHint: true)
            ),

            // --- Release ---
            Tool(
                name: "metadata_release_version",
                description: "Trigger manual release for an App Store version that is in PENDING_DEVELOPER_RELEASE state. This makes the version available on the App Store. Only works when the version's release_type is MANUAL and it has been approved by Apple.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "version_id": .object([
                            "type": "string",
                            "description": "The App Store version ID (must be in PENDING_DEVELOPER_RELEASE state)"
                        ])
                    ]),
                    "required": .array([.string("version_id")])
                ]),
                annotations: .init(destructiveHint: false)
            ),

            // --- Screenshots ---
            Tool(
                name: "metadata_list_screenshot_sets",
                description: "List screenshot sets (by device type) for a localization. Get localization_id from metadata_list_localizations.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "localization_id": .object([
                            "type": "string",
                            "description": "The App Store version localization ID"
                        ])
                    ]),
                    "required": .array([.string("localization_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "metadata_list_screenshots",
                description: "List screenshots within a screenshot set. Get screenshot_set_id from metadata_list_screenshot_sets.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "screenshot_set_id": .object([
                            "type": "string",
                            "description": "The screenshot set ID"
                        ])
                    ]),
                    "required": .array([.string("screenshot_set_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),

            Tool(
                name: "metadata_create_screenshot_set",
                description: """
                    Create a screenshot set for a specific device type within a localization. \
                    Common display types: APP_IPHONE_67 (6.7" iPhone 16 Pro Max), APP_IPHONE_65 (6.5" iPhone 11 Pro Max), \
                    APP_IPHONE_61 (6.1"), APP_IPAD_PRO_3GEN_129 (iPad Pro 12.9"), APP_IPAD_PRO_3GEN_11 (iPad Pro 11").
                    """,
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "localization_id": .object([
                            "type": "string",
                            "description": "The App Store version localization ID"
                        ]),
                        "display_type": .object([
                            "type": "string",
                            "description": "Screenshot display type (e.g. APP_IPHONE_67, APP_IPHONE_65, APP_IPAD_PRO_3GEN_129)"
                        ])
                    ]),
                    "required": .array([.string("localization_id"), .string("display_type")])
                ]),
                annotations: .init(destructiveHint: false)
            ),
            Tool(
                name: "metadata_upload_screenshot",
                description: "Upload a screenshot from a local file to a screenshot set. Handles the full 3-step upload: reserve → upload chunks → commit. Supports PNG and JPEG. Get screenshot_set_id from metadata_list_screenshot_sets or metadata_create_screenshot_set.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "screenshot_set_id": .object([
                            "type": "string",
                            "description": "The screenshot set ID"
                        ]),
                        "file_path": .object([
                            "type": "string",
                            "description": "Local file path to the screenshot (PNG or JPEG). Supports ~ for home directory."
                        ])
                    ]),
                    "required": .array([.string("screenshot_set_id"), .string("file_path")])
                ]),
                annotations: .init(destructiveHint: false)
            ),
            Tool(
                name: "metadata_delete_screenshot",
                description: "Delete a screenshot from a screenshot set. Get screenshot_id from metadata_list_screenshots.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "screenshot_id": .object([
                            "type": "string",
                            "description": "The screenshot ID to delete"
                        ])
                    ]),
                    "required": .array([.string("screenshot_id")])
                ]),
                annotations: .init(destructiveHint: true)
            ),
            Tool(
                name: "metadata_delete_screenshot_set",
                description: "Delete an entire screenshot set and all screenshots within it. Get screenshot_set_id from metadata_list_screenshot_sets.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "screenshot_set_id": .object([
                            "type": "string",
                            "description": "The screenshot set ID to delete"
                        ])
                    ]),
                    "required": .array([.string("screenshot_set_id")])
                ]),
                annotations: .init(destructiveHint: true)
            ),

            // --- Age Rating ---
            Tool(
                name: "metadata_get_age_rating",
                description: "Get the age rating declaration for an app info. Shows content ratings for violence, gambling, mature themes, etc. Get app_info_id from app_list_app_infos.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "app_info_id": .object([
                            "type": "string",
                            "description": "The app info ID (from app_list_app_infos)"
                        ])
                    ]),
                    "required": .array([.string("app_info_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "metadata_update_age_rating",
                description: """
                    Update the age rating declaration. Each content category accepts: NONE, INFREQUENT_OR_MILD, or FREQUENT_OR_INTENSE. \
                    Boolean fields (gambling, seventeenPlus) accept true/false. Get age_rating_id from metadata_get_age_rating.
                    """,
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "age_rating_id": .object([
                            "type": "string",
                            "description": "The age rating declaration ID (from metadata_get_age_rating)"
                        ]),
                        "alcoholTobaccoOrDrugUseOrReferences": .object([
                            "type": "string",
                            "description": "NONE, INFREQUENT_OR_MILD, or FREQUENT_OR_INTENSE"
                        ]),
                        "contests": .object([
                            "type": "string",
                            "description": "NONE, INFREQUENT_OR_MILD, or FREQUENT_OR_INTENSE"
                        ]),
                        "gambling": .object([
                            "type": "boolean",
                            "description": "Contains gambling content"
                        ]),
                        "gamblingSimulated": .object([
                            "type": "string",
                            "description": "NONE, INFREQUENT_OR_MILD, or FREQUENT_OR_INTENSE"
                        ]),
                        "horrorOrFearThemes": .object([
                            "type": "string",
                            "description": "NONE, INFREQUENT_OR_MILD, or FREQUENT_OR_INTENSE"
                        ]),
                        "matureOrSuggestiveThemes": .object([
                            "type": "string",
                            "description": "NONE, INFREQUENT_OR_MILD, or FREQUENT_OR_INTENSE"
                        ]),
                        "medicalOrTreatmentInformation": .object([
                            "type": "string",
                            "description": "NONE, INFREQUENT_OR_MILD, or FREQUENT_OR_INTENSE"
                        ]),
                        "profanityOrCrudeHumor": .object([
                            "type": "string",
                            "description": "NONE, INFREQUENT_OR_MILD, or FREQUENT_OR_INTENSE"
                        ]),
                        "sexualContentGraphicAndNudity": .object([
                            "type": "string",
                            "description": "NONE, INFREQUENT_OR_MILD, or FREQUENT_OR_INTENSE"
                        ]),
                        "sexualContentOrNudity": .object([
                            "type": "string",
                            "description": "NONE, INFREQUENT_OR_MILD, or FREQUENT_OR_INTENSE"
                        ]),
                        "violenceCartoonOrFantasy": .object([
                            "type": "string",
                            "description": "NONE, INFREQUENT_OR_MILD, or FREQUENT_OR_INTENSE"
                        ]),
                        "violenceRealistic": .object([
                            "type": "string",
                            "description": "NONE, INFREQUENT_OR_MILD, or FREQUENT_OR_INTENSE"
                        ]),
                        "violenceRealisticProlonged": .object([
                            "type": "string",
                            "description": "NONE, INFREQUENT_OR_MILD, or FREQUENT_OR_INTENSE"
                        ]),
                        "seventeenPlus": .object([
                            "type": "boolean",
                            "description": "Restrict to 17+"
                        ]),
                        "ageRatingOverride": .object([
                            "type": "string",
                            "description": "Override age rating (e.g. NONE, SEVENTEEN_PLUS)"
                        ])
                    ]),
                    "required": .array([.string("age_rating_id")])
                ]),
                annotations: .init(destructiveHint: false)
            ),
        ]
    }

    func handle(_ name: String, arguments: [String: Value]) async throws -> String {
        switch name {
        case "metadata_list_versions":
            return try await handleListVersions(arguments)
        case "metadata_get_version":
            return try await handleGetVersion(arguments)
        case "metadata_create_version":
            return try await handleCreateVersion(arguments)
        case "metadata_update_version":
            return try await handleUpdateVersion(arguments)
        case "metadata_list_localizations":
            return try await handleListLocalizations(arguments)
        case "metadata_update_localization":
            return try await handleUpdateLocalization(arguments)
        case "metadata_create_localization":
            return try await handleCreateLocalization(arguments)
        case "metadata_get_build_for_version":
            return try await handleGetBuildForVersion(arguments)
        case "metadata_set_build_for_version":
            return try await handleSetBuildForVersion(arguments)
        case "metadata_get_review_detail":
            return try await handleGetReviewDetail(arguments)
        case "metadata_update_review_detail":
            return try await handleUpdateReviewDetail(arguments)
        case "metadata_get_phased_release":
            return try await handleGetPhasedRelease(arguments)
        case "metadata_create_phased_release":
            return try await handleCreatePhasedRelease(arguments)
        case "metadata_update_phased_release":
            return try await handleUpdatePhasedRelease(arguments)
        case "metadata_delete_phased_release":
            return try await handleDeletePhasedRelease(arguments)
        case "metadata_release_version":
            return try await handleReleaseVersion(arguments)
        case "metadata_list_screenshot_sets":
            return try await handleListScreenshotSets(arguments)
        case "metadata_list_screenshots":
            return try await handleListScreenshots(arguments)
        case "metadata_create_screenshot_set":
            return try await handleCreateScreenshotSet(arguments)
        case "metadata_upload_screenshot":
            return try await handleUploadScreenshot(arguments)
        case "metadata_delete_screenshot":
            return try await handleDeleteScreenshot(arguments)
        case "metadata_delete_screenshot_set":
            return try await handleDeleteScreenshotSet(arguments)
        case "metadata_get_age_rating":
            return try await handleGetAgeRating(arguments)
        case "metadata_update_age_rating":
            return try await handleUpdateAgeRating(arguments)
        default:
            throw ASCClientError.invalidResponse("Unknown metadata tool: \(name)")
        }
    }

    // MARK: - Handler: List Versions

    private func handleListVersions(_ args: [String: Value]) async throws -> String {
        let appId = try requireString(args, "app_id")

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "fields[appStoreVersions]", value: "versionString,platform,appStoreState,copyright,releaseType,earliestReleaseDate,createdDate"),
        ]

        if let platform = stringValue(args, "platform") {
            queryItems.append(URLQueryItem(name: "filter[platform]", value: platform))
        }
        if let state = stringValue(args, "version_state") {
            queryItems.append(URLQueryItem(name: "filter[appStoreState]", value: state))
        }

        let response: ASCListResponse<AppStoreVersion> = try await client.getList(
            path: "/v1/apps/\(appId)/appStoreVersions",
            queryItems: queryItems
        )

        if response.data.isEmpty {
            return "No App Store versions found for app \(appId)."
        }

        var lines = ["App Store Versions (\(response.data.count)):"]
        lines.append(String(repeating: "-", count: 60))
        for version in response.data {
            lines.append(formatVersion(version))
        }

        if let paging = response.meta?.paging, let total = paging.total {
            lines.append("\nShowing \(response.data.count) of \(total) total versions.")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Handler: Get Version

    private func handleGetVersion(_ args: [String: Value]) async throws -> String {
        let versionId = try requireString(args, "version_id")

        let queryItems = [
            URLQueryItem(name: "fields[appStoreVersions]", value: "versionString,platform,appStoreState,copyright,releaseType,earliestReleaseDate,createdDate")
        ]

        let response: ASCResponse<AppStoreVersion> = try await client.get(
            path: "/v1/appStoreVersions/\(versionId)",
            queryItems: queryItems
        )

        return formatVersionDetailed(response.data)
    }

    // MARK: - Handler: Create Version

    private func handleCreateVersion(_ args: [String: Value]) async throws -> String {
        let appId = try requireString(args, "app_id")
        let versionString = try requireString(args, "version_string")
        let platform = stringValue(args, "platform") ?? "IOS"

        let body: [String: Any] = [
            "data": [
                "type": "appStoreVersions",
                "attributes": [
                    "versionString": versionString,
                    "platform": platform
                ],
                "relationships": [
                    "app": [
                        "data": [
                            "type": "apps",
                            "id": appId
                        ]
                    ]
                ]
            ]
        ]

        let response: ASCResponse<AppStoreVersion> = try await client.post(
            path: "/v1/appStoreVersions",
            body: body
        )

        let version = response.data
        let state = version.attributes?.appStoreState ?? "UNKNOWN"
        return "Created App Store version \(versionString) (\(platform)).\nVersion ID: \(version.id)\nState: \(stateEmoji(state)) \(state)"
    }

    // MARK: - Handler: Update Version

    private func handleUpdateVersion(_ args: [String: Value]) async throws -> String {
        let versionId = try requireString(args, "version_id")

        var attributes: [String: Any] = [:]
        if let versionString = stringValue(args, "version_string") {
            attributes["versionString"] = versionString
        }
        if let copyright = stringValue(args, "copyright") {
            attributes["copyright"] = copyright
        }
        if let releaseType = stringValue(args, "release_type") {
            attributes["releaseType"] = releaseType
        }
        if let earliestReleaseDate = stringValue(args, "earliest_release_date") {
            attributes["earliestReleaseDate"] = earliestReleaseDate
        }

        if attributes.isEmpty {
            return "No attributes provided to update. Specify at least one of: version_string, copyright, release_type, earliest_release_date."
        }

        let body: [String: Any] = [
            "data": [
                "type": "appStoreVersions",
                "id": versionId,
                "attributes": attributes
            ]
        ]

        let response: ASCResponse<AppStoreVersion> = try await client.patch(
            path: "/v1/appStoreVersions/\(versionId)",
            body: body
        )

        let version = response.data
        let updatedFields = attributes.keys.sorted().joined(separator: ", ")
        return "Updated App Store version \(versionId).\nUpdated fields: \(updatedFields)\nVersion: \(version.attributes?.versionString ?? "N/A")\nState: \(stateEmoji(version.attributes?.appStoreState ?? "UNKNOWN")) \(version.attributes?.appStoreState ?? "UNKNOWN")"
    }

    // MARK: - Handler: List Localizations

    private func handleListLocalizations(_ args: [String: Value]) async throws -> String {
        let versionId = try requireString(args, "version_id")

        let queryItems = [
            URLQueryItem(name: "fields[appStoreVersionLocalizations]", value: "locale,description,keywords,whatsNew,promotionalText,marketingUrl,supportUrl")
        ]

        let response: ASCListResponse<AppStoreVersionLocalization> = try await client.getList(
            path: "/v1/appStoreVersions/\(versionId)/appStoreVersionLocalizations",
            queryItems: queryItems
        )

        if response.data.isEmpty {
            return "No localizations found for version \(versionId)."
        }

        var lines = ["App Store Version Localizations (\(response.data.count)):"]
        lines.append(String(repeating: "-", count: 60))
        for localization in response.data {
            lines.append(formatLocalization(localization))
            lines.append(String(repeating: "-", count: 60))
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Handler: Update Localization

    private func handleUpdateLocalization(_ args: [String: Value]) async throws -> String {
        let localizationId = try requireString(args, "localization_id")

        var attributes: [String: Any] = [:]
        if let description = stringValue(args, "description") {
            attributes["description"] = description
        }
        if let keywords = stringValue(args, "keywords") {
            attributes["keywords"] = keywords
        }
        if let whatsNew = stringValue(args, "whatsNew") {
            attributes["whatsNew"] = whatsNew
        }
        if let promotionalText = stringValue(args, "promotionalText") {
            attributes["promotionalText"] = promotionalText
        }
        if let marketingUrl = stringValue(args, "marketingUrl") {
            attributes["marketingUrl"] = marketingUrl
        }
        if let supportUrl = stringValue(args, "supportUrl") {
            attributes["supportUrl"] = supportUrl
        }

        if attributes.isEmpty {
            return "No attributes provided to update. Specify at least one of: description, keywords, whatsNew, promotionalText, marketingUrl, supportUrl."
        }

        let body: [String: Any] = [
            "data": [
                "type": "appStoreVersionLocalizations",
                "id": localizationId,
                "attributes": attributes
            ]
        ]

        let response: ASCResponse<AppStoreVersionLocalization> = try await client.patch(
            path: "/v1/appStoreVersionLocalizations/\(localizationId)",
            body: body
        )

        let loc = response.data
        let locale = loc.attributes?.locale ?? "unknown"
        let updatedFields = attributes.keys.sorted().joined(separator: ", ")
        return "Updated localization \(localizationId) (locale: \(locale)).\nUpdated fields: \(updatedFields)"
    }

    // MARK: - Handler: Create Localization

    private func handleCreateLocalization(_ args: [String: Value]) async throws -> String {
        let versionId = try requireString(args, "version_id")
        let locale = try requireString(args, "locale")

        var attributes: [String: Any] = [
            "locale": locale
        ]
        if let description = stringValue(args, "description") {
            attributes["description"] = description
        }
        if let keywords = stringValue(args, "keywords") {
            attributes["keywords"] = keywords
        }
        if let whatsNew = stringValue(args, "whatsNew") {
            attributes["whatsNew"] = whatsNew
        }
        if let promotionalText = stringValue(args, "promotionalText") {
            attributes["promotionalText"] = promotionalText
        }
        if let marketingUrl = stringValue(args, "marketingUrl") {
            attributes["marketingUrl"] = marketingUrl
        }
        if let supportUrl = stringValue(args, "supportUrl") {
            attributes["supportUrl"] = supportUrl
        }

        let body: [String: Any] = [
            "data": [
                "type": "appStoreVersionLocalizations",
                "attributes": attributes,
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

        let response: ASCResponse<AppStoreVersionLocalization> = try await client.post(
            path: "/v1/appStoreVersionLocalizations",
            body: body
        )

        let loc = response.data
        return "Created localization for locale '\(locale)'.\nLocalization ID: \(loc.id)"
    }

    // MARK: - Handler: Get Build for Version

    private func handleGetBuildForVersion(_ args: [String: Value]) async throws -> String {
        let versionId = try requireString(args, "version_id")

        let queryItems = [
            URLQueryItem(name: "fields[builds]", value: "version,uploadedDate,processingState,minOsVersion,expirationDate")
        ]

        let build: Build? = try await client.getOptional(
            path: "/v1/appStoreVersions/\(versionId)/build",
            queryItems: queryItems
        )

        guard let build else {
            return "No build linked to App Store version \(versionId).\nUse metadata_set_build_for_version to link a build (get build_id from testflight_list_builds)."
        }

        let attrs = build.attributes
        var lines = [
            "Build Linked to Version \(versionId)",
            String(repeating: "-", count: 40),
            "  Build ID:         \(build.id)",
            "  Build Number:     \(attrs?.version ?? "N/A")",
            "  Processing State: \(attrs?.processingState ?? "N/A")",
            "  Uploaded:         \(formatDate(attrs?.uploadedDate))",
            "  Min OS Version:   \(attrs?.minOsVersion ?? "N/A")",
        ]
        if let expiration = attrs?.expirationDate {
            lines.append("  Expiration:       \(formatDate(expiration))")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Handler: Set Build for Version

    private func handleSetBuildForVersion(_ args: [String: Value]) async throws -> String {
        let versionId = try requireString(args, "version_id")
        let buildId = stringValue(args, "build_id")

        let body: [String: Any]
        if let buildId, !buildId.isEmpty {
            body = [
                "data": [
                    "type": "builds",
                    "id": buildId
                ] as [String: Any]
            ]
        } else {
            // Unlink: set data to NSNull for JSON null
            body = ["data": NSNull()]
        }

        try await client.patchNoContent(
            path: "/v1/appStoreVersions/\(versionId)/relationships/build",
            body: body
        )

        if let buildId, !buildId.isEmpty {
            return "Linked build \(buildId) to App Store version \(versionId)."
        } else {
            return "Unlinked build from App Store version \(versionId)."
        }
    }

    // MARK: - Handler: Get Review Detail

    private func handleGetReviewDetail(_ args: [String: Value]) async throws -> String {
        let versionId = try requireString(args, "version_id")

        let queryItems = [
            URLQueryItem(name: "fields[appStoreReviewDetails]", value: "contactFirstName,contactLastName,contactPhone,contactEmail,demoAccountName,demoAccountPassword,demoAccountRequired,notes")
        ]

        do {
            let detail: AppStoreReviewDetail? = try await client.getOptional(
                path: "/v1/appStoreVersions/\(versionId)/appStoreReviewDetail",
                queryItems: queryItems
            )

            guard let detail else {
                return "No review detail found for version \(versionId).\nReview detail is auto-created when you first update it via metadata_update_review_detail."
            }

            return formatReviewDetail(detail)
        } catch {
            // 404 means no review detail exists yet
            if "\(error)".contains("404") {
                return "No review detail found for version \(versionId).\nReview detail is auto-created when you first update it via metadata_update_review_detail."
            }
            throw error
        }
    }

    // MARK: - Handler: Update Review Detail

    private func handleUpdateReviewDetail(_ args: [String: Value]) async throws -> String {
        let reviewDetailId = try requireString(args, "review_detail_id")

        var attributes: [String: Any] = [:]
        if let v = stringValue(args, "contact_first_name") { attributes["contactFirstName"] = v }
        if let v = stringValue(args, "contact_last_name") { attributes["contactLastName"] = v }
        if let v = stringValue(args, "contact_phone") { attributes["contactPhone"] = v }
        if let v = stringValue(args, "contact_email") { attributes["contactEmail"] = v }
        if let v = stringValue(args, "demo_account_name") { attributes["demoAccountName"] = v }
        if let v = stringValue(args, "demo_account_password") { attributes["demoAccountPassword"] = v }
        if let v = boolValue(args, "demo_account_required") { attributes["demoAccountRequired"] = v }
        if let v = stringValue(args, "notes") { attributes["notes"] = v }

        if attributes.isEmpty {
            return "No attributes provided to update. Specify at least one of: contact_first_name, contact_last_name, contact_phone, contact_email, demo_account_name, demo_account_password, demo_account_required, notes."
        }

        let body: [String: Any] = [
            "data": [
                "type": "appStoreReviewDetails",
                "id": reviewDetailId,
                "attributes": attributes
            ]
        ]

        let response: ASCResponse<AppStoreReviewDetail> = try await client.patch(
            path: "/v1/appStoreReviewDetails/\(reviewDetailId)",
            body: body
        )

        let updatedFields = attributes.keys.sorted().joined(separator: ", ")
        return "Updated review detail \(reviewDetailId).\nUpdated fields: \(updatedFields)\n\n\(formatReviewDetail(response.data))"
    }

    // MARK: - Handler: Get Phased Release

    private func handleGetPhasedRelease(_ args: [String: Value]) async throws -> String {
        let versionId = try requireString(args, "version_id")

        do {
            let release: AppStoreVersionPhasedRelease? = try await client.getOptional(
                path: "/v1/appStoreVersions/\(versionId)/appStoreVersionPhasedRelease"
            )

            guard let release else {
                return "No phased release configured for version \(versionId).\nUse metadata_create_phased_release to enable 7-day phased rollout."
            }

            return formatPhasedReleaseDetailed(release)
        } catch {
            if "\(error)".contains("404") {
                return "No phased release configured for version \(versionId).\nUse metadata_create_phased_release to enable 7-day phased rollout."
            }
            throw error
        }
    }

    // MARK: - Handler: Create Phased Release

    private func handleCreatePhasedRelease(_ args: [String: Value]) async throws -> String {
        let versionId = try requireString(args, "version_id")

        let body: [String: Any] = [
            "data": [
                "type": "appStoreVersionPhasedReleases",
                "attributes": [
                    "phasedReleaseState": "ACTIVE"
                ],
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

        let response: ASCResponse<AppStoreVersionPhasedRelease> = try await client.post(
            path: "/v1/appStoreVersionPhasedReleases",
            body: body
        )

        let release = response.data
        return "Created phased release for version \(versionId).\nPhased Release ID: \(release.id)\nState: \(release.attributes?.phasedReleaseState ?? "ACTIVE")"
    }

    // MARK: - Handler: Update Phased Release

    private func handleUpdatePhasedRelease(_ args: [String: Value]) async throws -> String {
        let phasedReleaseId = try requireString(args, "phased_release_id")
        let state = try requireString(args, "state")

        let body: [String: Any] = [
            "data": [
                "type": "appStoreVersionPhasedReleases",
                "id": phasedReleaseId,
                "attributes": [
                    "phasedReleaseState": state
                ]
            ]
        ]

        let response: ASCResponse<AppStoreVersionPhasedRelease> = try await client.patch(
            path: "/v1/appStoreVersionPhasedReleases/\(phasedReleaseId)",
            body: body
        )

        let release = response.data
        return "Updated phased release \(phasedReleaseId).\nNew State: \(release.attributes?.phasedReleaseState ?? state)"
    }

    // MARK: - Handler: Delete Phased Release

    private func handleDeletePhasedRelease(_ args: [String: Value]) async throws -> String {
        let phasedReleaseId = try requireString(args, "phased_release_id")
        try await client.delete(path: "/v1/appStoreVersionPhasedReleases/\(phasedReleaseId)")
        return "Deleted phased release \(phasedReleaseId). The version will now release to all users at once when approved."
    }

    // MARK: - Handler: Release Version

    private func handleReleaseVersion(_ args: [String: Value]) async throws -> String {
        let versionId = try requireString(args, "version_id")

        let body: [String: Any] = [
            "data": [
                "type": "appStoreVersionReleaseRequests",
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

        let _: ASCResponse<AppStoreVersionReleaseRequest> = try await client.post(
            path: "/v1/appStoreVersionReleaseRequests",
            body: body
        )

        return "Release requested for App Store version \(versionId). The version will be available on the App Store shortly."
    }

    // MARK: - Handler: List Screenshot Sets

    private func handleListScreenshotSets(_ args: [String: Value]) async throws -> String {
        let localizationId = try requireString(args, "localization_id")

        let queryItems = [
            URLQueryItem(name: "fields[appScreenshotSets]", value: "screenshotDisplayType")
        ]

        let response: ASCListResponse<AppScreenshotSet> = try await client.getList(
            path: "/v1/appStoreVersionLocalizations/\(localizationId)/appScreenshotSets",
            queryItems: queryItems
        )

        if response.data.isEmpty {
            return "No screenshot sets found for localization \(localizationId)."
        }

        var lines = ["Screenshot Sets (\(response.data.count)):"]
        lines.append(String(repeating: "-", count: 60))
        for set in response.data {
            let displayType = set.attributes?.screenshotDisplayType ?? "UNKNOWN"
            lines.append("  [\(set.id)] \(formatDisplayType(displayType))")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Handler: List Screenshots

    private func handleListScreenshots(_ args: [String: Value]) async throws -> String {
        let screenshotSetId = try requireString(args, "screenshot_set_id")

        let queryItems = [
            URLQueryItem(name: "fields[appScreenshots]", value: "fileSize,fileName,sourceFileChecksum")
        ]

        let response: ASCListResponse<AppScreenshot> = try await client.getList(
            path: "/v1/appScreenshotSets/\(screenshotSetId)/appScreenshots",
            queryItems: queryItems
        )

        if response.data.isEmpty {
            return "No screenshots found in screenshot set \(screenshotSetId)."
        }

        var lines = ["Screenshots (\(response.data.count)):"]
        lines.append(String(repeating: "-", count: 60))
        for (index, screenshot) in response.data.enumerated() {
            let attrs = screenshot.attributes
            let fileName = attrs?.fileName ?? "unnamed"
            let fileSize = attrs?.fileSize.map { formatFileSize($0) } ?? "?"
            lines.append("  \(index + 1). [\(screenshot.id)] \(fileName) (\(fileSize))")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Handler: Create Screenshot Set

    private func handleCreateScreenshotSet(_ args: [String: Value]) async throws -> String {
        let localizationId = try requireString(args, "localization_id")
        let displayType = try requireString(args, "display_type")

        let body: [String: Any] = [
            "data": [
                "type": "appScreenshotSets",
                "attributes": [
                    "screenshotDisplayType": displayType
                ],
                "relationships": [
                    "appStoreVersionLocalization": [
                        "data": [
                            "type": "appStoreVersionLocalizations",
                            "id": localizationId
                        ]
                    ]
                ]
            ]
        ]

        let response: ASCResponse<AppScreenshotSet> = try await client.post(
            path: "/v1/appScreenshotSets",
            body: body
        )

        let set = response.data
        return "Created screenshot set for \(formatDisplayType(displayType)).\nScreenshot Set ID: \(set.id)"
    }

    // MARK: - Handler: Upload Screenshot

    private func handleUploadScreenshot(_ args: [String: Value]) async throws -> String {
        let screenshotSetId = try requireString(args, "screenshot_set_id")
        let filePath = try requireString(args, "file_path")

        // 1. Read local file
        let expandedPath = NSString(string: filePath).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expandedPath) else {
            return "File not found: \(filePath)"
        }
        guard let fileData = FileManager.default.contents(atPath: expandedPath) else {
            return "Could not read file: \(filePath)"
        }

        let fileName = URL(fileURLWithPath: expandedPath).lastPathComponent
        let fileSize = fileData.count

        // 2. Compute MD5 checksum
        let md5 = Insecure.MD5.hash(data: fileData)
        let checksum = md5.map { String(format: "%02hhx", $0) }.joined()

        // 3. Reserve screenshot (POST /v1/appScreenshots)
        let reserveBody: [String: Any] = [
            "data": [
                "type": "appScreenshots",
                "attributes": [
                    "fileName": fileName,
                    "fileSize": fileSize
                ],
                "relationships": [
                    "appScreenshotSet": [
                        "data": [
                            "type": "appScreenshotSets",
                            "id": screenshotSetId
                        ]
                    ]
                ]
            ]
        ]

        let reserveResponse: ASCResponse<AppScreenshotUpload> = try await client.post(
            path: "/v1/appScreenshots",
            body: reserveBody
        )

        let screenshot = reserveResponse.data
        let screenshotId = screenshot.id

        guard let operations = screenshot.attributes?.uploadOperations, !operations.isEmpty else {
            return "Error: No upload operations returned for screenshot \(screenshotId). File may be invalid or duplicate."
        }

        // 4. Upload chunks to Apple's CDN
        let session = URLSession.shared
        for (index, operation) in operations.enumerated() {
            guard let method = operation.method,
                  let urlString = operation.url,
                  let url = URL(string: urlString),
                  let offset = operation.offset,
                  let length = operation.length else {
                return "Error: Invalid upload operation at index \(index)."
            }

            let endIndex = min(offset + length, fileData.count)
            let chunk = fileData[offset..<endIndex]

            var request = URLRequest(url: url)
            request.httpMethod = method
            request.httpBody = Data(chunk)

            if let headers = operation.requestHeaders {
                for header in headers {
                    if let name = header.name, let value = header.value {
                        request.setValue(value, forHTTPHeaderField: name)
                    }
                }
            }

            let (_, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                return "Upload failed at chunk \(index + 1)/\(operations.count) (offset \(offset), \(length) bytes). HTTP \(statusCode)."
            }
        }

        // 5. Commit upload (PATCH /v1/appScreenshots/{id})
        let commitBody: [String: Any] = [
            "data": [
                "type": "appScreenshots",
                "id": screenshotId,
                "attributes": [
                    "uploaded": true,
                    "sourceFileChecksum": checksum
                ]
            ]
        ]

        let commitResponse: ASCResponse<AppScreenshotUpload> = try await client.patch(
            path: "/v1/appScreenshots/\(screenshotId)",
            body: commitBody
        )

        let state = commitResponse.data.attributes?.assetDeliveryState?.state ?? "UPLOADED"
        return """
            Screenshot uploaded successfully!
              Screenshot ID: \(screenshotId)
              File: \(fileName) (\(formatFileSize(fileSize)))
              Checksum: \(checksum)
              State: \(state)
              Chunks: \(operations.count)
            """
    }

    // MARK: - Handler: Delete Screenshot

    private func handleDeleteScreenshot(_ args: [String: Value]) async throws -> String {
        let screenshotId = try requireString(args, "screenshot_id")
        try await client.delete(path: "/v1/appScreenshots/\(screenshotId)")
        return "Deleted screenshot \(screenshotId)."
    }

    // MARK: - Handler: Delete Screenshot Set

    private func handleDeleteScreenshotSet(_ args: [String: Value]) async throws -> String {
        let screenshotSetId = try requireString(args, "screenshot_set_id")
        try await client.delete(path: "/v1/appScreenshotSets/\(screenshotSetId)")
        return "Deleted screenshot set \(screenshotSetId) and all screenshots within it."
    }

    // MARK: - Handler: Get Age Rating

    private func handleGetAgeRating(_ args: [String: Value]) async throws -> String {
        let appInfoId = try requireString(args, "app_info_id")

        let response: ASCResponse<AgeRatingDeclaration> = try await client.get(
            path: "/v1/appInfos/\(appInfoId)/ageRatingDeclaration"
        )

        return formatAgeRating(response.data)
    }

    // MARK: - Handler: Update Age Rating

    private func handleUpdateAgeRating(_ args: [String: Value]) async throws -> String {
        let ageRatingId = try requireString(args, "age_rating_id")

        let ratingFields = [
            "alcoholTobaccoOrDrugUseOrReferences", "contests", "gamblingSimulated",
            "horrorOrFearThemes", "matureOrSuggestiveThemes", "medicalOrTreatmentInformation",
            "profanityOrCrudeHumor", "sexualContentGraphicAndNudity", "sexualContentOrNudity",
            "violenceCartoonOrFantasy", "violenceRealistic", "violenceRealisticProlonged",
            "ageRatingOverride"
        ]
        let boolFields = ["gambling", "seventeenPlus"]

        var attributes: [String: Any] = [:]
        for field in ratingFields {
            if let v = stringValue(args, field) { attributes[field] = v }
        }
        for field in boolFields {
            if let v = boolValue(args, field) { attributes[field] = v }
        }

        if attributes.isEmpty {
            return "No attributes provided to update. Specify at least one rating field."
        }

        let body: [String: Any] = [
            "data": [
                "type": "ageRatingDeclarations",
                "id": ageRatingId,
                "attributes": attributes
            ]
        ]

        let response: ASCResponse<AgeRatingDeclaration> = try await client.patch(
            path: "/v1/ageRatingDeclarations/\(ageRatingId)",
            body: body
        )

        let updatedFields = attributes.keys.sorted().joined(separator: ", ")
        return "Updated age rating \(ageRatingId).\nUpdated fields: \(updatedFields)\n\n\(formatAgeRating(response.data))"
    }

    // MARK: - Formatters

    private func stateEmoji(_ state: String) -> String {
        switch state {
        case "READY_FOR_SALE": return "[LIVE]"
        case "PREPARE_FOR_SUBMISSION": return "[DRAFT]"
        case "WAITING_FOR_REVIEW": return "[REVIEW]"
        case "IN_REVIEW": return "[REVIEW]"
        case "DEVELOPER_REJECTED": return "[REJECTED]"
        case "REJECTED": return "[REJECTED]"
        case "PENDING_DEVELOPER_RELEASE": return "[PENDING]"
        case "PROCESSING_FOR_APP_STORE": return "[PROCESSING]"
        case "DEVELOPER_REMOVED_FROM_SALE": return "[REMOVED]"
        case "REMOVED_FROM_SALE": return "[REMOVED]"
        case "REPLACED_WITH_NEW_VERSION": return "[REPLACED]"
        default: return "[\(state)]"
        }
    }

    private func formatVersion(_ version: AppStoreVersion) -> String {
        let attrs = version.attributes
        let versionString = attrs?.versionString ?? "?"
        let platform = attrs?.platform ?? "?"
        let state = attrs?.appStoreState ?? "UNKNOWN"
        let created = formatDate(attrs?.createdDate)
        return "  [\(version.id)] v\(versionString) — \(stateEmoji(state)) \(state) | \(platform) | Created: \(created)"
    }

    private func formatVersionDetailed(_ version: AppStoreVersion) -> String {
        let attrs = version.attributes
        let state = attrs?.appStoreState ?? "UNKNOWN"
        var lines = [
            "App Store Version Details",
            String(repeating: "-", count: 40),
            "  ID:              \(version.id)",
            "  Version:         \(attrs?.versionString ?? "N/A")",
            "  Platform:        \(attrs?.platform ?? "N/A")",
            "  State:           \(stateEmoji(state)) \(state)",
            "  Copyright:       \(attrs?.copyright ?? "N/A")",
            "  Release Type:    \(attrs?.releaseType ?? "N/A")",
            "  Created:         \(formatDate(attrs?.createdDate))",
        ]
        if let earliestRelease = attrs?.earliestReleaseDate {
            lines.append("  Earliest Release: \(formatDate(earliestRelease))")
        }
        return lines.joined(separator: "\n")
    }

    private func formatLocalization(_ loc: AppStoreVersionLocalization) -> String {
        let attrs = loc.attributes
        let locale = attrs?.locale ?? "unknown"
        var lines = ["  [\(loc.id)] Locale: \(locale)"]

        if let description = attrs?.description, !description.isEmpty {
            let preview = description.count > 120 ? String(description.prefix(120)) + "..." : description
            lines.append("    Description: \(preview)")
        }
        if let keywords = attrs?.keywords, !keywords.isEmpty {
            let preview = keywords.count > 100 ? String(keywords.prefix(100)) + "..." : keywords
            lines.append("    Keywords:    \(preview)")
        }
        if let whatsNew = attrs?.whatsNew, !whatsNew.isEmpty {
            let preview = whatsNew.count > 120 ? String(whatsNew.prefix(120)) + "..." : whatsNew
            lines.append("    What's New:  \(preview)")
        }
        if let promo = attrs?.promotionalText, !promo.isEmpty {
            let preview = promo.count > 100 ? String(promo.prefix(100)) + "..." : promo
            lines.append("    Promo Text:  \(preview)")
        }
        if let marketing = attrs?.marketingUrl, !marketing.isEmpty {
            lines.append("    Marketing:   \(marketing)")
        }
        if let support = attrs?.supportUrl, !support.isEmpty {
            lines.append("    Support:     \(support)")
        }

        return lines.joined(separator: "\n")
    }

    private func formatPhasedReleaseDetailed(_ release: AppStoreVersionPhasedRelease) -> String {
        let attrs = release.attributes
        let state = attrs?.phasedReleaseState ?? "UNKNOWN"
        var lines = [
            "Phased Release Status",
            String(repeating: "-", count: 40),
            "  ID:              \(release.id)",
            "  State:           \(state)",
            "  Current Day:     \(attrs?.currentDayNumber.map(String.init) ?? "N/A")",
            "  Start Date:      \(formatDate(attrs?.startDate))",
        ]
        if let pauseDuration = attrs?.totalPauseDuration {
            lines.append("  Pause Duration:  \(pauseDuration) day(s)")
        }

        // Show rollout percentage guide
        lines.append("")
        lines.append("  Phased Rollout Schedule:")
        lines.append("    Day 1:  1%   | Day 2:  2%   | Day 3:  5%")
        lines.append("    Day 4: 10%   | Day 5: 20%   | Day 6: 50%")
        lines.append("    Day 7: 100%")

        return lines.joined(separator: "\n")
    }

    private func formatReviewDetail(_ detail: AppStoreReviewDetail) -> String {
        let attrs = detail.attributes
        var lines = [
            "App Store Review Detail",
            String(repeating: "-", count: 40),
            "  Review Detail ID:    \(detail.id)",
            "  Contact First Name:  \(attrs?.contactFirstName ?? "N/A")",
            "  Contact Last Name:   \(attrs?.contactLastName ?? "N/A")",
            "  Contact Phone:       \(attrs?.contactPhone ?? "N/A")",
            "  Contact Email:       \(attrs?.contactEmail ?? "N/A")",
            "  Demo Account Name:   \(attrs?.demoAccountName ?? "N/A")",
            "  Demo Account Pwd:    \(attrs?.demoAccountPassword ?? "N/A")",
            "  Demo Acct Required:  \(attrs?.demoAccountRequired.map(String.init) ?? "N/A")",
        ]
        if let notes = attrs?.notes, !notes.isEmpty {
            let preview = notes.count > 200 ? String(notes.prefix(200)) + "..." : notes
            lines.append("  Notes:               \(preview)")
        } else {
            lines.append("  Notes:               N/A")
        }
        return lines.joined(separator: "\n")
    }

    private func formatAgeRating(_ rating: AgeRatingDeclaration) -> String {
        let attrs = rating.attributes
        var lines = [
            "Age Rating Declaration",
            String(repeating: "-", count: 50),
            "  Age Rating ID:  \(rating.id)",
        ]

        let fields: [(String, String?)] = [
            ("Alcohol/Tobacco/Drug", attrs?.alcoholTobaccoOrDrugUseOrReferences),
            ("Contests", attrs?.contests),
            ("Gambling", attrs?.gambling.map(String.init)),
            ("Gambling Simulated", attrs?.gamblingSimulated),
            ("Horror/Fear", attrs?.horrorOrFearThemes),
            ("Mature/Suggestive", attrs?.matureOrSuggestiveThemes),
            ("Medical/Treatment", attrs?.medicalOrTreatmentInformation),
            ("Profanity/Crude Humor", attrs?.profanityOrCrudeHumor),
            ("Sexual Content (Graphic)", attrs?.sexualContentGraphicAndNudity),
            ("Sexual Content/Nudity", attrs?.sexualContentOrNudity),
            ("Violence (Cartoon)", attrs?.violenceCartoonOrFantasy),
            ("Violence (Realistic)", attrs?.violenceRealistic),
            ("Violence (Prolonged)", attrs?.violenceRealisticProlonged),
            ("Age Rating Override", attrs?.ageRatingOverride),
            ("Korea Rating Override", attrs?.koreaAgeRatingOverride),
            ("17+ Only", attrs?.seventeenPlus.map(String.init)),
            ("Gambling & Contests", attrs?.gamblingAndContests.map(String.init)),
        ]

        for (label, value) in fields {
            let padded = label.padding(toLength: 24, withPad: " ", startingAt: 0)
            lines.append("  \(padded) \(value ?? "N/A")")
        }

        return lines.joined(separator: "\n")
    }

    private func formatDisplayType(_ type: String) -> String {
        switch type {
        case "APP_IPHONE_67": return "iPhone 6.7\" (iPhone 16 Pro Max)"
        case "APP_IPHONE_65": return "iPhone 6.5\" (iPhone 11 Pro Max)"
        case "APP_IPHONE_61": return "iPhone 6.1\" (iPhone 16 Pro)"
        case "APP_IPHONE_55": return "iPhone 5.5\" (iPhone 8 Plus)"
        case "APP_IPAD_PRO_3GEN_129": return "iPad Pro 12.9\" (3rd gen+)"
        case "APP_IPAD_PRO_3GEN_11": return "iPad Pro 11\""
        case "APP_IPAD_PRO_129": return "iPad Pro 12.9\" (2nd gen)"
        case "APP_IPAD_105": return "iPad 10.5\""
        case "APP_IPAD_97": return "iPad 9.7\""
        case "APP_APPLE_WATCH_SERIES_4": return "Apple Watch Series 4+"
        case "APP_APPLE_WATCH_SERIES_7": return "Apple Watch Series 7+"
        case "APP_APPLE_WATCH_ULTRA": return "Apple Watch Ultra"
        default: return type
        }
    }

    private func formatFileSize(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return "\(bytes / 1024) KB" }
        return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
    }
}
