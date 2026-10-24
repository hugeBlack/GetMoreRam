//
//  Capabilities.swift
//  StosSign
//
//  Created by Stossy11 on 18/03/2025.
//

// Entitlements
let entitlementApplicationIdentifier = "application-identifier"
let entitlementKeychainAccessGroups = "keychain-access-groups"
let entitlementAppGroups = "com.apple.security.application-groups"
let entitlementGetTaskAllow = "get-task-allow"
let entitlementIncreasedMemoryLimit = "com.apple.developer.kernel.increased-memory-limit"
let entitlementTeamIdentifier = "com.apple.developer.team-identifier"
let entitlementInterAppAudio = "inter-app-audio"
let entitlementIncreasedDebuggingMemoryLimit = "com.apple.developer.kernel.increased-debugging-memory-limit"
let entitlementExtendedVirtualAddressing = "com.apple.developer.kernel.extended-virtual-addressing"

// Capabilities
let capabilityIncreasedMemoryLimit = "INCREASED_MEMORY_LIMIT" 
let capabilityIncreasedDebuggingMemoryLimit = "INCREASED_MEMORY_LIMIT_DEBUGGING"
let capabilityExtendedVirtualAddressing = "EXTENDED_VIRTUAL_ADDRESSING"

// Features
let featureGameCenter = "gameCenter"
let featureAppGroups = "APG3427HIY"
let featureInterAppAudio = "IAD53UNK2F"

func entitlementForFeature(_ feature: String) -> String? {
    switch feature {
    case featureAppGroups:
        return entitlementAppGroups
    case featureInterAppAudio:
        return entitlementInterAppAudio
    case capabilityIncreasedMemoryLimit:
        return entitlementIncreasedMemoryLimit
    default:
        return nil
    }
}

func freeDeveloperCanUseEntitlement(_ entitlement: String) -> Bool {
    switch entitlement {
    case entitlementAppGroups,
         entitlementInterAppAudio,
         entitlementGetTaskAllow,
         entitlementIncreasedMemoryLimit,
         entitlementTeamIdentifier,
         entitlementKeychainAccessGroups,
         entitlementApplicationIdentifier:
        return true
    default:
        return false
    }
}

func featureForEntitlement(_ entitlement: String) -> String? {
    switch entitlement {
    case entitlementAppGroups:
        return featureAppGroups
    case entitlementInterAppAudio:
        return featureInterAppAudio
    case entitlementIncreasedMemoryLimit:
        return capabilityIncreasedMemoryLimit
    default:
        return nil
    }
}
