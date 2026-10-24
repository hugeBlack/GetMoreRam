//
//  Capability.swift
//  StosSign
//
//  Created by Stossy11 on 14/2/2026.
//

public struct Capability: Codable {
    public var id: String
    public var attributes: CapabilityAttributes
}

public struct CapabilityAttributes: Codable {
    public var entitlements: [CapabilityEntitlement]?
    public var supportsWildcard: Bool
    public var validTeamTypes: [String]
}

public struct CapabilityEntitlement: Codable {
    public var key: String
    public var profileKey: String
}
