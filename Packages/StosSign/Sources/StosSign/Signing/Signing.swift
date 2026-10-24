//
//  Signing.swift
//  StosSign
//
//  Created by Stossy11 on 03/04/2025.
//

import Foundation
import StosSign_Common
#if canImport(Security)
import StosSign_CodeSign
#endif

typealias EVP_PKEY = OpaquePointer
typealias X509 = OpaquePointer
typealias BIO = OpaquePointer

let AppleRootCertificateData = """
-----BEGIN CERTIFICATE-----
MIIEuzCCA6OgAwIBAgIBAjANBgkqhkiG9w0BAQUFADBiMQswCQYDVQQGEwJVUzET
MBEGA1UEChMKQXBwbGUgSW5jLjEmMCQGA1UECxMdQXBwbGUgQ2VydGlmaWNhdGlv
biBBdXRob3JpdHkxFjAUBgNVBAMTDUFwcGxlIFJvb3QgQ0EwHhcNMDYwNDI1MjE0
MDM2WhcNMzUwMjA5MjE0MDM2WjBiMQswCQYDVQQGEwJVUzETMBEGA1UEChMKQXBw
bGUgSW5jLjEmMCQGA1UECxMdQXBwbGUgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkx
FjAUBgNVBAMTDUFwcGxlIFJvb3QgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAw
ggEKAoIBAQDkkakJH5HbHkdQ6wXtXnmELes2oldMVeyLGYne+Uts9QerIjAC6Bg+
+FAJ039BqJj50cpmnCRrEdCju+QbKsMflZ56DKRHi1vUFjczy8QPTc4UadHJGXL1
XQ7Vf1+b8iUDulWPTV0N8WQ1IxVLFVkds5T39pyez1C6wVhQZ48ItCD3y6wsIG9w
tj8BMIy3Q88PnT3zK0koGsj+zrW5DtleHNbLPbU6rfQPDgCSC7EhFi501TwN22IW
q6NxkkdTVcGvL0Gz+PvjcM3mo0xFfh9Ma1CWQYnEdGILEINBhzOKgbEwWOxaBDKM
aLOPHd5lc/9nXmW8Sdh2nzMUZaF3lMktAgMBAAGjggF6MIIBdjAOBgNVHQ8BAf8E
BAMCAQYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUK9BpR5R2Cf70a40uQKb3
R01/CF4wHwYDVR0jBBgwFoAUK9BpR5R2Cf70a40uQKb3R01/CF4wggERBgNVHSAE
ggEIMIIBBDCCAQAGCSqGSIb3Y2QFATCB8jAqBggrBgEFBQcCARYeaHR0cHM6Ly93
d3cuYXBwbGUuY29tL2FwcGxlY2EvMIHDBggrBgEFBQcCAjCBthqBs1JlbGlhbmNl
IG9uIHRoaXMgY2VydGlmaWNhdGUgYnkgYW55IHBhcnR5IGFzc3VtZXMgYWNjZXB0
YW5jZSBvZiB0aGUgdGhlbiBhcHBsaWNhYmxlIHN0YW5kYXJkIHRlcm1zIGFuZCBj
b25kaXRpb25zIG9mIHVzZSwgY2VydGlmaWNhdGUgcG9saWN5IGFuZCBjZXJ0aWZp
Y2F0aW9uIHByYWN0aWNlIHN0YXRlbWVudHMuMA0GCSqGSIb3DQEBBQUAA4IBAQBc
NplMLXi37Yyb3PN3m/J20ncwT8EfhYOFG5k9RzfyqZtAjizUsZAS2L70c5vu0mQP
y3lPNNiiPvl4/2vIB+x9OYOLUyDTOMSxv5pPCmv/K/xZpwUJfBdAVhEedNO3iyM7
R6PVbyTi69G3cN8PReEnyvFteO3ntRcXqNx+IjXKJdXZD9Zr1KIkIxH3oayPc4Fg
xhtbCS+SsvhESPBgOJ4V9T0mZyCKM2r3DYLP3uujL/lTaltkwGMzd/c6ByxW69oP
IQ7aunMZT7XZNn/Bh1XZp5m5MkL72NVxnn6hUrcbvZNCJBIqxw8dtk2cXmPIS4AX
"UKqK1drk/NAJBzewdXUh
-----END CERTIFICATE-----
"""
let AppleWWDRCertificateData = """
-----BEGIN CERTIFICATE-----
MIIEUTCCAzmgAwIBAgIQfK9pCiW3Of57m0R6wXjF7jANBgkqhkiG9w0BAQsFADBi
MQswCQYDVQQGEwJVUzETMBEGA1UEChMKQXBwbGUgSW5jLjEmMCQGA1UECxMdQXBw
bGUgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkxFjAUBgNVBAMTDUFwcGxlIFJvb3Qg
Q0EwHhcNMjAwMjE5MTgxMzQ3WhcNMzAwMjIwMDAwMDAwWjB1MUQwQgYDVQQDDDtB
cHBsZSBXb3JsZHdpZGUgRGV2ZWxvcGVyIFJlbGF0aW9ucyBDZXJ0aWZpY2F0aW9u
IEF1dGhvcml0eTELMAkGA1UECwwCRzMxEzARBgNVBAoMCkFwcGxlIEluYy4xCzAJ
BgNVBAYTAlVTMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA2PWJ/KhZ
C4fHTJEuLVaQ03gdpDDppUjvC0O/LYT7JF1FG+XrWTYSXFRknmxiLbTGl8rMPPbW
BpH85QKmHGq0edVny6zpPwcR4YS8Rx1mjjmi6LRJ7TrS4RBgeo6TjMrA2gzAg9Dj
+ZHWp4zIwXPirkbRYp2SqJBgN31ols2N4Pyb+ni743uvLRfdW/6AWSN1F7gSwe0b
5TTO/iK1nkmw5VW/j4SiPKi6xYaVFuQAyZ8D0MyzOhZ71gVcnetHrg21LYwOaU1A
0EtMOwSejSGxrC5DVDDOwYqGlJhL32oNP/77HK6XF8J4CjDgXx9UO0m3JQAaN4LS
VpelUkl8YDib7wIDAQABo4HvMIHsMBIGA1UdEwEB/wQIMAYBAf8CAQAwHwYDVR0j
BBgwFoAUK9BpR5R2Cf70a40uQKb3R01/CF4wRAYIKwYBBQUHAQEEODA2MDQGCCsG
AQUFBzABhihodHRwOi8vb2NzcC5hcHBsZS5jb20vb2NzcDAzLWFwcGxlcm9vdGNh
MC4GA1UdHwQnMCUwI6AhoB+GHWh0dHA6Ly9jcmwuYXBwbGUuY29tL3Jvb3QuY3Js
MB0GA1UdDgQWBBQJ/sAVkPmvZAqSErkmKGMMl+ynsjAOBgNVHQ8BAf8EBAMCAQYw
EAYKKoZIhvdjZAYCAQQCBQAwDQYJKoZIhvcNAQELBQADggEBAK1lE+j24IF3RAJH
Qr5fpTkg6mKp/cWQyXMT1Z6b0KoPjY3L7QHPbChAW8dVJEH4/M/BtSPp3Ozxb8qA
HXfCxGFJJWevD8o5Ja3T43rMMygNDi6hV0Bz+uZcrgZRKe3jhQxPYdwyFot30ETK
XXIDMUacrptAGvr04NM++i+MZp+XxFRZ79JI9AeZSWBZGcfdlNHAwWx/eCHvDOs7
bJmCS1JgOLU5gm3sUjFTvg+RTElJdI+mUcuER04ddSduvfnSXPN/wmwLCTbiZOTC
NwMUGdXqapSqqdv+9poIZ4vvK7iqF0mDr8/LvOnP6pVxsLRFoszlh6oKw0E6eVza
UDSdlTs=
-----END CERTIFICATE-----
"""

let LegacyAppleWWDRCertificateData = """
-----BEGIN CERTIFICATE-----
MIIEIjCCAwqgAwIBAgIIAd68xDltoBAwDQYJKoZIhvcNAQEFBQAwYjELMAkGA1UE
BhMCVVMxEzARBgNVBAoTCkFwcGxlIEluYy4xJjAkBgNVBAsTHUFwcGxlIENlcnRp
ZmljYXRpb24gQXV0aG9yaXR5MRYwFAYDVQQDEw1BcHBsZSBSb290IENBMB4XDTEz
MDIwNzIxNDg0N1oXDTIzMDIwNzIxNDg0N1owgZYxCzAJBgNVBAYTAlVTMRMwEQYD
VQQKDApBcHBsZSBJbmMuMSwwKgYDVQQLDCNBcHBsZSBXb3JsZHdpZGUgRGV2ZWxv
cGVyIFJlbGF0aW9uczFEMEIGA1UEAww7QXBwbGUgV29ybGR3aWRlIERldmVsb3Bl
ciBSZWxhdGlvbnMgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkwggEiMA0GCSqGSIb3
DQEBAQUAA4IBDwAwggEKAoIBAQDKOFSmy1aqyCQ5SOmM7uxfuH8mkbw0U3rOfGOA
YXdkXqUHI7Y5/lAtFVZYcC1+xG7BSoU+L/DehBqhV8mvexj/avoVEkkVCBmsqtsq
Mu2WY2hSFT2Miuy/axiV4AOsAX2XBWfODoWVN2rtCbauZ81RZJ/GXNG8V25nNYB2
NqSHgW44j9grFU57Jdhav06DwY3Sk9UacbVgnJ0zTlX5ElgMhrgWDcHld0WNUEi6
Ky3klIXh6MSdxmilsKP8Z35wugJZS3dCkTm59c3hTO/AO0iMpuUhXf1qarunFjVg
0uat80YpyejDi+l5wGphZxWy8P3laLxiX27Pmd3vG2P+kmWrAgMBAAGjgaYwgaMw
HQYDVR0OBBYEFIgnFwmpthhgi+zruvZHWcVSVKO3MA8GA1UdEwEB/wQFMAMBAf8w
HwYDVR0jBBgwFoAUK9BpR5R2Cf70a40uQKb3R01/CF4wLgYDVR0fBCcwJTAjoCGg
H4YdaHR0cDovL2NybC5hcHBsZS5jb20vcm9vdC5jcmwwDgYDVR0PAQH/BAQDAgGG
MBAGCiqGSIb3Y2QGAgEEAgUAMA0GCSqGSIb3DQEBBQUAA4IBAQBPz+9Zviz1smwv
j+4ThzLoBTWobot9yWkMudkXvHcs1Gfi/ZptOllc34MBvbKuKmFysa/Nw0Uwj6OD
Dc4dR7Txk4qjdJukw5hyhzs+r0ULklS5MruQGFNrCk4QttkdUGwhgAqJTleMa1s8
Pab93vcNIx0LSiaHP7qRkkykGRIZbVf1eliHe2iK5IaMSuviSRSqpd1VAKmuu0sw
ruGgsbwpgOYJd+W+NKIByn/c4grmO7i77LpilfMFY0GCzQ87HUyVpNur+cmV6U/k
TecmmYHpvPm0KdIBembhLoz2IYrF+Hjhga6/05Cdqa3zr/04GpZnMBxRpVzscYqC
tGwPDBUf
-----END CERTIFICATE-----
"""


public enum SigningError: LocalizedError {
    case missingAppBundle(underlyingError: Error)
    case invalidApp
    case missingProvisioningProfile(bundleIdentifier: String)
    case missingCertificate
    case signingFailed(component: String, details: String?)
    case fileOperationFailed(Error)
    case unknown(String)
    
    public var errorDescription: String? {
        switch self {
        case .missingAppBundle:
            return NSLocalizedString("Missing App Bundle", comment: "Error when app bundle cannot be found")
        case .invalidApp:
            return NSLocalizedString("Invalid Application", comment: "Error when app is invalid or corrupted")
        case .missingProvisioningProfile(let bundleIdentifier):
            return String(format: NSLocalizedString("Missing Provisioning Profile for '%@'", comment: "Error when provisioning profile is missing"), bundleIdentifier)
        case .missingCertificate:
            return NSLocalizedString("Missing Certificate", comment: "Error when certificate is missing")
        case .signingFailed(let component, _):
            return String(format: NSLocalizedString("Failed to Sign %@", comment: "Error when signing fails"), component)
        case .fileOperationFailed:
            return NSLocalizedString("File Operation Failed", comment: "Error when file operation fails")
        case .unknown:
            return NSLocalizedString("Unknown Error", comment: "Generic unknown error")
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .missingAppBundle(let error):
            return String(format: NSLocalizedString("The app bundle could not be extracted or found: %@", comment: "Failure reason for missing app bundle"), error.localizedDescription)
        case .invalidApp:
            return NSLocalizedString("The application file is invalid or corrupted and cannot be signed.", comment: "Failure reason for invalid app")
        case .missingProvisioningProfile(let bundleIdentifier):
            return String(format: NSLocalizedString("No provisioning profile was found that matches the bundle identifier '%@'.", comment: "Failure reason for missing provisioning profile"), bundleIdentifier)
        case .missingCertificate:
            return NSLocalizedString("The certificate or private key is missing or invalid.", comment: "Failure reason for missing certificate")
        case .signingFailed(let component, let details):
            if let details = details {
                return String(format: NSLocalizedString("The signing process failed for %@: %@", comment: "Failure reason for signing failure with details"), component, details)
            }
            return String(format: NSLocalizedString("The signing process failed for %@.", comment: "Failure reason for signing failure"), component)
        case .fileOperationFailed(let error):
            return String(format: NSLocalizedString("A file operation failed: %@", comment: "Failure reason for file operation failure"), error.localizedDescription)
        case .unknown(let message):
            return message
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .missingAppBundle:
            return NSLocalizedString("Ensure the IPA file is not corrupted and try again.", comment: "Recovery suggestion for missing app bundle")
        case .invalidApp:
            return NSLocalizedString("Verify the application file is a valid iOS app and try again.", comment: "Recovery suggestion for invalid app")
        case .missingProvisioningProfile:
            return NSLocalizedString("Add a provisioning profile that matches the app's bundle identifier.", comment: "Recovery suggestion for missing provisioning profile")
        case .missingCertificate:
            return NSLocalizedString("Ensure you have selected a valid certificate with a private key.", comment: "Recovery suggestion for missing certificate")
        case .signingFailed:
            return NSLocalizedString("Check your certificate and provisioning profile, then try again.", comment: "Recovery suggestion for signing failure")
        case .fileOperationFailed:
            return NSLocalizedString("Check file permissions and available disk space.", comment: "Recovery suggestion for file operation failure")
        case .unknown:
            return NSLocalizedString("Please try again or contact support if the problem persists.", comment: "Recovery suggestion for unknown error")
        }
    }
}

public final class Signer {
    public let team: Team
    public let certificate: Certificate
    
    public init(team: Team, certificate: Certificate) {
        self.team = team
        self.certificate = certificate
    }
    
    public func signApp(at appURL: URL? = nil, application: Application?, entitlements: [Entitlement : Any], provisioningProfiles profiles: [ProvisioningProfile]) async throws  {
        let progress = Progress(totalUnitCount: 1)
        
        let appURL = appURL ?? application!.fileURL
        
        guard let application = application ?? Application(fileURL: appURL) else {
            throw SigningError.invalidApp
        }
        
        var bundleID = application.bundleIdentifier
        if !bundleID.hasSuffix(team.identifier) {
            bundleID += "." + team.identifier
        }
        
        progress.totalUnitCount = Int64(FileManager.default.subpaths(atPath: appURL.path)?.count ?? 0)
        
        let profileForApp: (Application) -> ProvisioningProfile? = { app in
            profiles.first { profile in
                let profileBID = profile.bundleIdentifier
                let appBID = app.bundleIdentifier
                
                return appBID == profileBID || bundleID == profileBID
            }
        }

        do {
            guard let p12Data = self.certificate.p12Data else {
                throw SigningError.missingCertificate
            }
            
            let p12FilePath = FileManager.default.temporaryDirectory.appendingPathComponent("certificate.p12")
            try p12Data.write(to: p12FilePath)
            
            guard let profile = profileForApp(application) else {
                throw SigningError.missingProvisioningProfile(bundleIdentifier: bundleID)
            }
            let provisioningPath = try saveProvisioningProfile(profile)
            
            for appExtension in application.appExtensions {
                guard let extensionProfile = profileForApp(appExtension) ?? profileForApp(application) else {
                    throw SigningError.missingProvisioningProfile(bundleIdentifier: bundleID)
                }
                
                let extensionProvisioningPath = try saveProvisioningProfile(extensionProfile)
                
                let newBundleID = appExtension.bundleIdentifier.hasPrefix(bundleID) ? appExtension.bundleIdentifier : appExtension.bundleIdentifier.replacingOccurrences(of: application.bundleIdentifier, with: bundleID)
                
                updatePlistValue(fileURL: appExtension.fileURL.appendingPathComponent("Info.plist"), key: "CFBundleIdentifier", newValue: newBundleID)
                
                let convertedEntitlements = entitlements.mapValues { $0 }
                
                
                print("signing app extension \(newBundleID)")
                try await Signer.signAsync(
                    appPath: appExtension.fileURL.path,
                    provisionPath: extensionProvisioningPath,
                    p12Path: p12FilePath.path,
                    p12Password: "",
                    entitlements: convertedEntitlements.merging(extensionProfile.entitlements, uniquingKeysWith: {current, new in current })
                )
            }
            
            
            updatePlistValue(fileURL: appURL.appendingPathComponent("Info.plist"), key: "CFBundleIdentifier", newValue: bundleID)
            
            let convertedEntitlements = entitlements.mapValues { $0 }
            
            try await Signer.signAsync(
                appPath: appURL.path,
                provisionPath: provisioningPath,
                p12Path: p12FilePath.path,
                p12Password: "",
                entitlements: convertedEntitlements.merging(profile.entitlements, uniquingKeysWith: {current, new in current })
            )
        } catch {
            throw error
        }
        
    }
    
    func updatePlistValue(fileURL: URL, key: String, newValue: Any) {
        do {
            let data = try Data(contentsOf: fileURL)
            
            guard var plist = try PropertyListSerialization.propertyList(from: data, options: .mutableContainersAndLeaves, format: nil) as? [String: Any] else {
                return
            }

            plist[key] = newValue

            let updatedData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)

            try updatedData.write(to: fileURL, options: .atomic)
            print("Successfully updated \(key)!")
            
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
}


func saveProvisioningProfile(_ profile: ProvisioningProfile) throws -> String {
    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(profile.uuid).mobileprovision")
    try profile.data.write(to: tempURL)
    return tempURL.path
}
extension Data {
    var bytes: [UInt8] {
        return [UInt8](self)
    }
}

extension Optional where Wrapped == Data {
    var bytes: [UInt8] {
        return self?.bytes ?? []
    }
}

extension URL {
    @available(iOS, deprecated: 16.0, message: "Use URL.temporaryDirectory on iOS 16 and above")
    static var temporaryDirectory: URL {
        let documentDirectory = FileManager.default.temporaryDirectory
        return documentDirectory
    }
}

extension Signer {
    static func signAsync(
        appPath: String,
        provisionPath: String,
        p12Path: String,
        p12Password: String,
        entitlements: [Entitlement: Any],
    ) async throws {
        #if canImport(Security)
        let security: () async throws -> Void = {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                let status = codesignAllNested(
                    appPath,
                    p12Path,
                    p12Password,
                    provisionPath,
                    entitlements
                )
                
                if status == 0 {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: NSError(
                        domain: "CodeSign",
                        code: Int(status),
                        userInfo: [NSLocalizedDescriptionKey: "Signing failed"]
                    ))
                }
                
            }
        }
        #else
        let security: () async throws -> Void = {}
        #endif
        
        try await security()
    }
}

