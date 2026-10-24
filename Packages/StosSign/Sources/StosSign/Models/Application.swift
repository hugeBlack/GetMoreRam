//
//  Application.swift
//  StosSign
//
//  Created by Stossy11 on 19/03/2025.
//

import Foundation
import StosSign_Common
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif


public typealias Entitlement = String

public final class Application: NSObject, Sendable {
    // MARK: - Public Properties
    
    public let name: String
    public let bundleIdentifier: String
    public let version: String
    public let buildVersion: String
    public let minimumiOSVersion: OperatingSystemVersion
    public let supportedDeviceTypes: DeviceType
    public let fileURL: URL
    public let bundle: Bundle
    
    public var entitlements: [Entitlement: Any] {
        do {
           let path = bundle.executableURL?.path ?? fileURL.path
            
            do {
                let rawEntitlements = try EntitlementsParser(path).readEntitlements().values
                // _entitlements = rawEntitlements
                return rawEntitlements
            } catch {
                throw EntitlementError.failedToExtract(error)
            }
        } catch {
            print("Error parsing entitlements: \(error)")
            return [:]
        }
    }
    
    
    public var provisioningProfile: ProvisioningProfile? {
        let provisioningProfileURL = fileURL.appendingPathComponent("embedded.mobileprovision")
        let decoder = PropertyListDecoder()

        do {
            let data = try Data(contentsOf: provisioningProfileURL)
            let profile = try decoder.decode(ProvisioningProfile.self, from: data)
            return profile
        } catch {
            print("Failed to decode provisioning profile: \(error)")
            return nil
        }
    }
    
    public var appExtensions: Set<Application> {
        guard let plugInsURL = bundle.builtInPlugInsURL else {
            return []
        }
        
        return Set(
            FileManager.default
                .enumerateContents(at: plugInsURL, options: [.skipsSubdirectoryDescendants])
                .compactMap { url -> Application? in
                    guard url.pathExtension.lowercased() == "appex",
                          let appExtension = Application(fileURL: url) else {
                        return nil
                    }
                    return appExtension
                }
        )
    }

    
    #if canImport(UIKit)
    public var icon: UIImage? {
        guard let iconName = self.iconName else {
            return nil
        }
        
        
        return UIImage(named: iconName, in: self.bundle, compatibleWith: nil)
    }
    #elseif canImport(AppKit)
    public var icon: NSImage? {
        guard let iconName = self.iconName else {
            return nil
        }
        
        return self.bundle.image(forResource: iconName)
    }
    #endif
    
    private let iconName: String?
    
    public init?(fileURL: URL) {
        guard let bundle = Bundle(url: fileURL) else {
            return nil
        }
        
        let infoPlistURL = bundle.bundleURL.appendingPathComponent("Info.plist")
        guard let infoDictionary = NSDictionary(contentsOf: infoPlistURL) as? [String: Any] else {
            return nil
        }
        
        guard let name = infoDictionary["CFBundleDisplayName"] as? String ?? infoDictionary[kCFBundleNameKey as String] as? String,
              let bundleIdentifier = infoDictionary[kCFBundleIdentifierKey as String] as? String else {
            return nil
        }
        
        let version = infoDictionary["CFBundleShortVersionString"] as? String ?? "1.0"
        let buildVersion = infoDictionary[kCFBundleVersionKey as String] as? String ?? "1"
        
        let minimumVersion = Self.parseMinimumOSVersion(from: infoDictionary["MinimumOSVersion"] as? String ?? "1.0")
        
        let supportedDeviceTypes = Self.parseSupportedDeviceTypes(from: infoDictionary)
        
        let iconName = Self.findIconName(in: infoDictionary)
        
        self.bundle = bundle
        self.fileURL = fileURL
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.version = version
        self.buildVersion = buildVersion
        self.minimumiOSVersion = minimumVersion
        self.supportedDeviceTypes = supportedDeviceTypes
        self.iconName = iconName
        
        super.init()

         _ = self.entitlements
    }
    
    private static func parseMinimumOSVersion(from versionString: String) -> OperatingSystemVersion {
        let components = versionString.components(separatedBy: ".")
        
        let major = components.indices.contains(0) ? Int(components[0]) ?? 0 : 0
        let minor = components.indices.contains(1) ? Int(components[1]) ?? 0 : 0
        let patch = components.indices.contains(2) ? Int(components[2]) ?? 0 : 0
        
        return OperatingSystemVersion(
            majorVersion: major,
            minorVersion: minor,
            patchVersion: patch
        )
    }
    
    private static func parseSupportedDeviceTypes(from infoDictionary: [String: Any]) -> DeviceType {
        if let deviceFamilies = infoDictionary["UIDeviceFamily"] {
            if let rawDeviceFamily = deviceFamilies as? Int {
                return DeviceType.from(uiDeviceFamily: rawDeviceFamily)
            } else if let deviceFamiliesArray = deviceFamilies as? [Int], !deviceFamiliesArray.isEmpty {
                return deviceFamiliesArray.reduce(DeviceType.none) { result, family in
                    DeviceType.combine(result, DeviceType.from(uiDeviceFamily: family))
                }
            }
        }
        
        return .iPhone
    }

    private static func findIconName(in infoDictionary: [String: Any]) -> String? {
        if let icons = infoDictionary["CFBundleIcons"] as? [String: Any],
           let primaryIcon = icons["CFBundlePrimaryIcon"] {
            if let iconString = primaryIcon as? String {
                return iconString
            } else if let primaryIconDict = primaryIcon as? [String: Any],
                      let iconFiles = primaryIconDict["CFBundleIconFiles"] as? [String],
                      let lastIcon = iconFiles.last {
                return lastIcon
            }
        }
        
        if let iconFiles = infoDictionary["CFBundleIconFiles"] as? [String],
           let lastIcon = iconFiles.last {
            return lastIcon
        }
        
        return infoDictionary["CFBundleIconFile"] as? String
    }
    
    public enum EntitlementError: Error, LocalizedError {
        case failedToExtract(Error)
        
        public var errorDescription: String? {
            switch self {
            case .failedToExtract(let error):
                return "Failed to extract entitlements: \(error.localizedDescription)"
            }
        }
    }
}

extension FileManager {
    func enumerateContents(at url: URL, options: DirectoryEnumerationOptions = []) -> [URL] {
        guard let enumerator = self.enumerator(
            at: url,
            includingPropertiesForKeys: nil,
            options: options,
            errorHandler: nil
        ) else {
            return []
        }
        
        return enumerator.compactMap { $0 as? URL }
    }
}
