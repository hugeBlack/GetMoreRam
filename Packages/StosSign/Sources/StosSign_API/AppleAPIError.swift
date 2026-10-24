//
//  AppleAPIError.swift
//  StosSign
//
//  Created by Stossy11 on 1/2/2026.
//

import Foundation

public enum AppleAPIError: Error, Equatable {
    case unknown
    case invalidParameters
    case badServerResponse
    case incorrectCredentials
    case appSpecificPasswordRequired
    case noTeams
    case invalidDeviceID
    case deviceAlreadyRegistered
    case invalidCertificateRequest
    case certificateDoesNotExist
    case invalidAppIDName
    case invalidBundleIdentifier
    case bundleIdentifierUnavailable
    case appIDDoesNotExist
    case maximumAppIDLimitReached
    case invalidAppGroup
    case appGroupDoesNotExist
    case invalidProvisioningProfileIdentifier
    case provisioningProfileDoesNotExist
    case requiresTwoFactorAuthentication
    case incorrectVerificationCode
    case authenticationHandshakeFailed
    case invalidAnisetteData
    case accountLocked
    case customError(code: Int, message: String)
    
    public static func == (lhs: AppleAPIError, rhs: AppleAPIError) -> Bool {
        switch (lhs, rhs) {
        case (.unknown, .unknown),
             (.invalidParameters, .invalidParameters),
             (.badServerResponse, .badServerResponse),
             (.incorrectCredentials, .incorrectCredentials),
             (.appSpecificPasswordRequired, .appSpecificPasswordRequired),
             (.noTeams, .noTeams),
             (.invalidDeviceID, .invalidDeviceID),
             (.deviceAlreadyRegistered, .deviceAlreadyRegistered),
             (.invalidCertificateRequest, .invalidCertificateRequest),
             (.certificateDoesNotExist, .certificateDoesNotExist),
             (.invalidAppIDName, .invalidAppIDName),
             (.invalidBundleIdentifier, .invalidBundleIdentifier),
             (.bundleIdentifierUnavailable, .bundleIdentifierUnavailable),
             (.appIDDoesNotExist, .appIDDoesNotExist),
             (.maximumAppIDLimitReached, .maximumAppIDLimitReached),
             (.invalidAppGroup, .invalidAppGroup),
             (.appGroupDoesNotExist, .appGroupDoesNotExist),
             (.invalidProvisioningProfileIdentifier, .invalidProvisioningProfileIdentifier),
             (.provisioningProfileDoesNotExist, .provisioningProfileDoesNotExist),
             (.requiresTwoFactorAuthentication, .requiresTwoFactorAuthentication),
             (.incorrectVerificationCode, .incorrectVerificationCode),
             (.authenticationHandshakeFailed, .authenticationHandshakeFailed),
             (.invalidAnisetteData, .invalidAnisetteData):
            return true
        case (.customError(let lhsCode, let lhsMessage), .customError(let rhsCode, let rhsMessage)):
            return lhsCode == rhsCode && lhsMessage == rhsMessage
        default:
            return false
        }
    }
}


extension AppleAPIError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unknown:
            return "An unknown error occurred"
        case .invalidParameters:
            return "Invalid parameters provided"
        case .badServerResponse:
            return "Bad server response received"
        case .incorrectCredentials:
            return "Incorrect credentials provided"
        case .accountLocked:
            return "Locked Account"
        case .appSpecificPasswordRequired:
            return "App-specific password required"
        case .noTeams:
            return "No development teams available"
        case .invalidDeviceID:
            return "Invalid device identifier"
        case .deviceAlreadyRegistered:
            return "Device is already registered"
        case .invalidCertificateRequest:
            return "Invalid certificate request"
        case .certificateDoesNotExist:
            return "Certificate does not exist"
        case .invalidAppIDName:
            return "Invalid App ID name"
        case .invalidBundleIdentifier:
            return "Invalid bundle identifier"
        case .bundleIdentifierUnavailable:
            return "Bundle identifier is unavailable"
        case .appIDDoesNotExist:
            return "App ID does not exist"
        case .maximumAppIDLimitReached:
            return "Maximum App ID limit reached"
        case .invalidAppGroup:
            return "Invalid App Group"
        case .appGroupDoesNotExist:
            return "App Group does not exist"
        case .invalidProvisioningProfileIdentifier:
            return "Invalid provisioning profile identifier"
        case .provisioningProfileDoesNotExist:
            return "Provisioning profile does not exist"
        case .requiresTwoFactorAuthentication:
            return "Two-factor authentication required"
        case .incorrectVerificationCode:
            return "Incorrect verification code"
        case .authenticationHandshakeFailed:
            return "Authentication handshake failed"
        case .invalidAnisetteData:
            return "Invalid anisette data"
        case .customError(let code, let message):
            return "Error \(code): \(message)"
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .unknown:
            return "The operation failed for an unknown reason"
        case .invalidParameters:
            return "One or more required parameters are missing or invalid"
        case .badServerResponse:
            return "Apple's servers returned an unexpected response format"
        case .incorrectCredentials:
            return "The Apple ID or password is incorrect"
        case .accountLocked:
            return "Your Apple ID has been locked for security reasons."
        case .appSpecificPasswordRequired:
            return "Your Apple ID requires an app-specific password for this operation"
        case .noTeams:
            return "No development teams are associated with this Apple ID"
        case .invalidDeviceID:
            return "The device UDID format is invalid or not recognized"
        case .deviceAlreadyRegistered:
            return "This device is already registered in the developer portal"
        case .invalidCertificateRequest:
            return "The certificate signing request (CSR) is malformed or invalid"
        case .certificateDoesNotExist:
            return "The requested certificate could not be found in the developer portal"
        case .invalidAppIDName:
            return "The App ID name contains invalid characters or format"
        case .invalidBundleIdentifier:
            return "The bundle identifier format is invalid or contains restricted characters"
        case .bundleIdentifierUnavailable:
            return "This bundle identifier is already in use or reserved"
        case .appIDDoesNotExist:
            return "The specified App ID could not be found"
        case .maximumAppIDLimitReached:
            return "You have reached the maximum number of App IDs for your team"
        case .invalidAppGroup:
            return "The App Group identifier is invalid or malformed"
        case .appGroupDoesNotExist:
            return "The specified App Group could not be found"
        case .invalidProvisioningProfileIdentifier:
            return "The provisioning profile identifier is invalid"
        case .provisioningProfileDoesNotExist:
            return "The requested provisioning profile could not be found"
        case .requiresTwoFactorAuthentication:
            return "This Apple ID requires two-factor authentication to proceed"
        case .incorrectVerificationCode:
            return "The two-factor authentication code is incorrect or expired"
        case .authenticationHandshakeFailed:
            return "Could not establish an authenticated session with Apple's servers"
        case .invalidAnisetteData:
            return "The device authentication data is invalid or expired"
        case .customError(let code, let message):
            return "Custom error occurred: \(message) (Code: \(code))"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .incorrectCredentials:
            return "Verify your Apple ID and password are correct"
        case .appSpecificPasswordRequired:
            return "Generate an app-specific password at appleid.apple.com"
        case .accountLocked:
            return "Visit iForgot (at https://iforgot.apple.com) to reset your password"
        case .noTeams:
            return "Enroll in the Apple Developer Program or join an existing team"
        case .invalidDeviceID:
            return "Check that the device UDID is correctly formatted"
        case .deviceAlreadyRegistered:
            return "This device is already registered and can be used for development"
        case .bundleIdentifierUnavailable:
            return "Try a different bundle identifier or check your team's existing App IDs"
        case .maximumAppIDLimitReached:
            return "Remove unused App IDs or upgrade your developer account"
        case .requiresTwoFactorAuthentication:
            return "Enable two-factor authentication on your Apple ID"
        case .authenticationHandshakeFailed:
            return "Check your internet connection and try again"
        case .invalidAnisetteData:
            return "Restart the application and try again"
        default:
            return nil
        }
    }
}

extension AppleAPIError {
    static func fromCode(_ code: Int, message: String? = nil) -> AppleAPIError {
        switch code {
        case 0: return .unknown
        case 1: return .invalidParameters
        case 2: return .badServerResponse
        case 3: return .incorrectCredentials
        case 4: return .appSpecificPasswordRequired
        case 5: return .noTeams
        case 6: return .invalidDeviceID
        case 7: return .deviceAlreadyRegistered
        case 8: return .invalidCertificateRequest
        case 9: return .certificateDoesNotExist
        case 10: return .invalidAppIDName
        case 11: return .invalidBundleIdentifier
        case 12: return .bundleIdentifierUnavailable
        case 13: return .appIDDoesNotExist
        case 14: return .maximumAppIDLimitReached
        case 15: return .invalidAppGroup
        case 16: return .appGroupDoesNotExist
        case 17: return .invalidProvisioningProfileIdentifier
        case 18: return .provisioningProfileDoesNotExist
        case 19: return .requiresTwoFactorAuthentication
        case 20: return .incorrectVerificationCode
        case 21: return .authenticationHandshakeFailed
        case 22: return .invalidAnisetteData
        case 23: return .accountLocked
        default: return .customError(code: code, message: message ?? "Unknown error code \(code)")
        }
    }
    
    var errorCode: Int {
        switch self {
        case .unknown: return 0
        case .invalidParameters: return 1
        case .badServerResponse: return 2
        case .incorrectCredentials: return 3
        case .appSpecificPasswordRequired: return 4
        case .noTeams: return 5
        case .invalidDeviceID: return 6
        case .deviceAlreadyRegistered: return 7
        case .invalidCertificateRequest: return 8
        case .certificateDoesNotExist: return 9
        case .invalidAppIDName: return 10
        case .invalidBundleIdentifier: return 11
        case .bundleIdentifierUnavailable: return 12
        case .appIDDoesNotExist: return 13
        case .maximumAppIDLimitReached: return 14
        case .invalidAppGroup: return 15
        case .appGroupDoesNotExist: return 16
        case .invalidProvisioningProfileIdentifier: return 17
        case .provisioningProfileDoesNotExist: return 18
        case .requiresTwoFactorAuthentication: return 19
        case .incorrectVerificationCode: return 20
        case .authenticationHandshakeFailed: return 21
        case .invalidAnisetteData: return 22
        case .accountLocked: return 23
        case .customError(let code, _): return code
        }
    }
}

