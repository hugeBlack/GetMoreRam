//
//  Device.swift
//  StosSign
//
//  Created by Stossy11 on 19/03/2025.
//

import Foundation

public enum DeviceType: Int, Sendable {
    case iPhone = 1
    case iPad = 2
    case AppleTV = 3
    case none = 0
    case all = 7
    
    public static func from(uiDeviceFamily deviceFamily: Int) -> DeviceType {
        switch deviceFamily {
        case 1: return .iPhone
        case 2: return .iPad
        case 3: return .AppleTV
        default: return .none
        }
    }
    
    public static func combine(_ lhs: DeviceType, _ rhs: DeviceType) -> DeviceType {
        return DeviceType(rawValue: lhs.rawValue | rhs.rawValue) ?? .none
    }
}

public struct Device: Codable, Sendable {
    public var name: String
    public var identifier: String
    public var type: DeviceType
    public var osVersion: OperatingSystemVersion = .init()
    
    enum CodingKeys: String, CodingKey {
        case name
        case identifier = "deviceNumber"
        case deviceClass
    }
    
    public init(name: String, identifier: String, type: DeviceType) {
        self.name = name
        self.identifier = identifier
        self.type = type
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        name = try container.decode(String.self, forKey: .name)
        identifier = try container.decode(String.self, forKey: .identifier)
        
        let deviceClass = try container.decodeIfPresent(String.self, forKey: .deviceClass) ?? "iphone"
        switch deviceClass.lowercased() {
        case "iphone":
            type = .iPhone
        case "ipad":
            type = .iPad
        case "tvos":
            type = .AppleTV
        default:
            type = .none
        }
    }
    
    public static func operatingSystemNameForDeviceType(_ deviceType: DeviceType) -> String? {
        switch deviceType {
        case .iPhone, .iPad:
            return "iOS"
        case .AppleTV:
            return "tvOS"
        default:
            return nil
        }
    }

    
    public static func operatingSystemVersionFromString(_ osVersionString: String) -> OperatingSystemVersion {
        let versionComponents = osVersionString.split(separator: ".").map { Int($0) ?? 0 }
        let majorVersion = versionComponents.count > 0 ? versionComponents[0] : 0
        let minorVersion = versionComponents.count > 1 ? versionComponents[1] : 0
        let patchVersion = versionComponents.count > 2 ? versionComponents[2] : 0

        return OperatingSystemVersion(majorVersion: majorVersion, minorVersion: minorVersion, patchVersion: patchVersion)
    }

    public static func stringFromOperatingSystemVersion(_ osVersion: OperatingSystemVersion) -> String {
        var versionString = "\(osVersion.majorVersion).\(osVersion.minorVersion)"
        if osVersion.patchVersion != 0 {
            versionString += ".\(osVersion.patchVersion)"
        }
        return versionString
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(name, forKey: .name)
        try container.encode(identifier, forKey: .identifier)
        
        let deviceClass: String
        switch type {
        case .iPhone:
            deviceClass = "iphone"
        case .iPad:
            deviceClass = "ipad"
        case .AppleTV:
            deviceClass = "tvos"
        default:
            deviceClass = "unknown"
        }
        
        try container.encode(deviceClass, forKey: .deviceClass)
    }
}

