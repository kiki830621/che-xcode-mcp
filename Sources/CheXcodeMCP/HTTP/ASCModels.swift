import Foundation

/// JSON:API response envelope for single resource
struct ASCResponse<T: Decodable>: Decodable {
    let data: T
    let links: ASCPageLinks?
    let included: [ASCIncludedResource]?
}

/// JSON:API response envelope for single resource that may be null (e.g., unlinked build, missing review detail)
struct ASCOptionalResponse<T: Decodable>: Decodable {
    let data: T?
    let links: ASCPageLinks?
    let included: [ASCIncludedResource]?
}

/// JSON:API response envelope for resource list
struct ASCListResponse<T: Decodable>: Decodable {
    let data: [T]
    let links: ASCPageLinks?
    let included: [ASCIncludedResource]?
    let meta: ASCMeta?
}

/// Pagination links
struct ASCPageLinks: Decodable {
    let `self`: String?
    let next: String?
    let first: String?
}

/// Generic included resource
struct ASCIncludedResource: Decodable {
    let type: String
    let id: String
    let attributes: [String: AnyCodable]?
}

/// Meta information
struct ASCMeta: Decodable {
    let paging: ASCPaging?
}

struct ASCPaging: Decodable {
    let total: Int?
    let limit: Int?
}

/// JSON:API resource object
struct ASCResource<Attrs: Decodable>: Decodable {
    let type: String
    let id: String
    let attributes: Attrs?
    let relationships: [String: ASCRelationship]?
}

/// JSON:API relationship
struct ASCRelationship: Decodable {
    let data: ASCRelationshipData?
    let links: ASCRelationshipLinks?
}

enum ASCRelationshipData: Decodable {
    case single(ASCResourceIdentifier)
    case many([ASCResourceIdentifier])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let single = try? container.decode(ASCResourceIdentifier.self) {
            self = .single(single)
        } else if let many = try? container.decode([ASCResourceIdentifier].self) {
            self = .many(many)
        } else {
            throw DecodingError.typeMismatch(
                ASCRelationshipData.self,
                .init(codingPath: decoder.codingPath, debugDescription: "Expected single or array of resource identifiers")
            )
        }
    }
}

struct ASCResourceIdentifier: Decodable {
    let type: String
    let id: String
}

struct ASCRelationshipLinks: Decodable {
    let related: String?
    let `self`: String?
}

/// JSON:API error response
struct ASCErrorResponse: Decodable {
    let errors: [ASCAPIError]
}

struct ASCAPIError: Decodable, LocalizedError {
    let id: String?
    let status: String?
    let code: String?
    let title: String?
    let detail: String?

    var errorDescription: String? {
        [title, detail].compactMap { $0 }.joined(separator: ": ")
    }
}

/// Type-erased Codable for dynamic JSON values
struct AnyCodable: Decodable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map(\.value)
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues(\.value)
        } else if container.decodeNil() {
            value = NSNull()
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON type")
        }
    }
}
