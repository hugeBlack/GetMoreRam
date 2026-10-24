//
//  ProvisioningProfile.swift
//  StosSign
//
//  Created by Stossy11 on 19/03/2025.
//

import Foundation

public struct ProvisioningProfile: Codable {
    public var identifier: String
    public var data: Data
    public var name: String
    public var uuid: UUID
    public var teamIdentifier: String
    public var teamName: String
    public var creationDate: Date
    public var expirationDate: Date
    public var entitlements: [String: AnyCodable]
    public var deviceIDs: [String]
    public var isFreeProvisioningProfile: Bool
    public var bundleIdentifier: String?
    public var certificates: [Data]

    enum CodingKeys: String, CodingKey {
        case identifier = "provisioningProfileId"
        case data = "encodedProfile"
        case name = "Name"
        case uuid = "UUID"
        case teamIdentifier = "TeamIdentifier"
        case teamName = "TeamName"
        case creationDate = "CreationDate"
        case expirationDate = "dateExpire"
        case entitlements = "Entitlements"
        case deviceIDs = "ProvisionedDevices"
        case isFreeProvisioningProfile = "LocalProvision"
        case bundleIdentifier
        case certificates = "DeveloperCertificates"
    }

    public init(_ dict: [String: Any]) {
        identifier = dict[CodingKeys.identifier.rawValue] as? String ?? ""
        data = dict[CodingKeys.data.rawValue] as? Data ?? Data()

        name = dict[CodingKeys.name.rawValue] as? String ?? ""
        let uuidString = dict[CodingKeys.uuid.rawValue] as? String ?? ""
        uuid = UUID(uuidString: uuidString) ?? UUID()

        teamIdentifier = (dict[CodingKeys.teamIdentifier.rawValue] as? [String])?.first ?? ""
        teamName = dict[CodingKeys.teamName.rawValue] as? String ?? ""
        creationDate = dict[CodingKeys.creationDate.rawValue] as? Date ?? Date()
        expirationDate = dict[CodingKeys.expirationDate.rawValue] as? Date ?? Date()

        entitlements = (dict[CodingKeys.entitlements.rawValue] as? [String: Any] ?? [:])
            .mapValues { AnyCodable($0) }

        deviceIDs = dict[CodingKeys.deviceIDs.rawValue] as? [String] ?? []
        isFreeProvisioningProfile = dict[CodingKeys.isFreeProvisioningProfile.rawValue] as? Bool ?? false

        if let appIdDict = dict["appId"] as? [String: Any],
        let identifierStr = appIdDict["identifier"] as? String {
            bundleIdentifier = identifierStr
        } else {
            bundleIdentifier = nil
        }

        certificates = dict[CodingKeys.certificates.rawValue] as? [Data] ?? []
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        identifier = try container.decode(String.self, forKey: .identifier)
        data = try container.decode(Data.self, forKey: .data)

        let profileDict = try Self.decodeProfileData(data)
        name = profileDict[CodingKeys.name.rawValue] as? String ?? ""
        let uuidString = profileDict[CodingKeys.uuid.rawValue] as? String ?? ""
        uuid = UUID(uuidString: uuidString) ?? UUID()
        teamIdentifier = (profileDict[CodingKeys.teamIdentifier.rawValue] as? [String])?.first ?? ""
        teamName = profileDict[CodingKeys.teamName.rawValue] as? String ?? ""
        creationDate = profileDict[CodingKeys.creationDate.rawValue] as? Date ?? Date()
        expirationDate = profileDict[CodingKeys.expirationDate.rawValue] as? Date ?? Date()
        entitlements = (profileDict[CodingKeys.entitlements.rawValue] as? [String: Any] ?? [:]).mapValues { AnyCodable($0) }
        deviceIDs = profileDict[CodingKeys.deviceIDs.rawValue] as? [String] ?? []
        isFreeProvisioningProfile = profileDict[CodingKeys.isFreeProvisioningProfile.rawValue] as? Bool ?? false

        if let appID = entitlements["application-identifier"]?.value as? String, let range = appID.range(of: ".") {
            bundleIdentifier = String(appID[range.upperBound...])
        } else {
            bundleIdentifier = nil
        }

        certificates = profileDict[CodingKeys.certificates.rawValue] as? [Data] ?? []
    }

    private static func decodeProfileData(_ data: Data) throws -> [String: Any] {
        guard let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            throw NSError(domain: "ProvisioningProfile", code: 1, userInfo: nil)
        }
        return dict
    }
}

public struct AnyCodable: Codable {
    public let value: Any

    public init(_ value: Any) { self.value = value }

    public  init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self.value = value
        } else if let value = try? container.decode(Int.self) {
            self.value = value
        } else if let value = try? container.decode(Double.self) {
            self.value = value
        } else if let value = try? container.decode(Bool.self) {
            self.value = value
        } else {
            throw DecodingError.typeMismatch(AnyCodable.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported type"))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let value as String:
            try container.encode(value)
        case let value as Int:
            try container.encode(value)
        case let value as Double:
            try container.encode(value)
        case let value as Bool:
            try container.encode(value)
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Unsupported type"))
        }
    }
}
