//
//  AppleAPI.swift
//  StosSign
//
//  Created by Stossy11 on 18/03/2025.
//

import Foundation
import StosSign_Common
#if !canImport(Darwin)
import FoundationNetworking
#endif

let clientID = "XABBG36SBA"
let QH_Protocol = "QH65B2"
let V1_Protocol = "v1"
let authProtocol = "A1234"

public final class AppleAPI: Sendable {
    public let session = URLSession(configuration: URLSessionConfiguration.ephemeral)
    public let qhURL = URL(string: "https://developerservices2.apple.com/services/\(QH_Protocol)/")!
    public let v1URL = URL(string: "https://developerservices2.apple.com/services/\(V1_Protocol)/")!
    
    public static let shared = AppleAPI()
    
    private init() {}
    
    public func fetchTeamsForAccount(account: Account, session: AppleAPISession) async throws -> [Team] {
        let url = qhURL.appendingPathComponent("listTeams.action")
        
        let response = try await sendRequestWithURL(requestURL: url, additionalParameters: nil, session: session, team: nil)
        
        guard let array = response["teams"] as? [[String: Any]] else {
            if let result = response["resultCode"] {
                let resultCode = (result as? NSNumber)?.intValue ?? 0
                
                if resultCode == 0 {
                    throw AppleAPIError.unknown
                } else {
                    let errorDescription = response["userString"] as? String ?? response["resultString"] as? String
                    let localizedDescription = String(format: "%@ (%@)", errorDescription ?? "", "\(resultCode)")
                    throw AppleAPIError.customError(code: resultCode, message: localizedDescription)
                }
            } else {
                if let data = response["error"] as? String {
                    throw AppleAPIError.customError(code: 0, message: data)
                }
                throw AppleAPIError.badServerResponse
            }
        }
        
        var teams: [Team] = []
        for dictionary in array {
            if let team = Team(account: account, responseDictionary: dictionary) {
                teams.append(team)
            }
        }
        
        if teams.count == 0 {
            throw AppleAPIError.noTeams
        }
        
        return teams
    }
    
    public func fetchDevicesForTeam(team: Team, session: AppleAPISession, types: DeviceType) async throws -> [Device] {
        let url = qhURL.appendingPathComponent("ios").appendingPathComponent("listDevices.action")
        
        let response = try await sendRequestWithURL(requestURL: url, additionalParameters: nil, session: session, team: team)
        
        do {
            let data = try JSONSerialization.data(withJSONObject: response["devices"] ?? [])
            let devices = try JSONDecoder().decode([Device].self, from: data)
            var devicesChecked = devices
            devicesChecked.removeAll(where: { types != $0.type })
            return devicesChecked
        } catch {
            if let result = response["resultCode"] {
                let resultCode = (result as? NSNumber)?.intValue ?? 0
                
                if resultCode == 0 {
                    throw AppleAPIError.unknown
                } else {
                    let errorDescription = response["userString"] as? String ?? response["resultString"] as? String
                    let localizedDescription = String(format: "%@ (%@)", errorDescription ?? "", "\(resultCode)")
                    throw AppleAPIError.customError(code: resultCode, message: localizedDescription)
                }
            } else {
                if let data = response["error"] as? String {
                    throw AppleAPIError.customError(code: 0, message: data)
                }
                throw AppleAPIError.badServerResponse
            }
        }
    }
    
    public func registerDeviceWithName(name: String, identifier: String, type: DeviceType, team: Team, session: AppleAPISession) async throws -> Device {
        let url = qhURL.appendingPathComponent("ios").appendingPathComponent("addDevice.action")
        
        var parameters = [
            "deviceNumber": identifier,
            "name": name
        ]
        
        switch type {
        case .iPad:
            parameters["DTDK_Platform"] = "ios"
        case .AppleTV:
            parameters["DTDK_Platform"] = "tvos"
            parameters["subPlatform"] = "tvOS"
        default: break
        }
        
        let response = try await sendRequestWithURL(requestURL: url, additionalParameters: parameters, session: session, team: team)
        
        guard let deviceDictionary = response["device"] as? [String: Any] else {
            if let result = response["resultCode"] as? Int {
                if result == 0 {
                    throw AppleAPIError.unknown
                } else if result == 35 {
                    throw AppleAPIError.deviceAlreadyRegistered
                } else {
                    let errorDescription = response["userString"] as? String ?? response["resultString"] as? String
                    let localizedDescription = String(format: "%@ (%@)", errorDescription ?? "", "\(result)")
                    throw AppleAPIError.customError(code: result, message: localizedDescription)
                }
            } else {
                if let data = response["error"] as? String {
                    throw AppleAPIError.customError(code: 0, message: data)
                }
                throw AppleAPIError.badServerResponse
            }
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: deviceDictionary, options: [])
            let device = try JSONDecoder().decode(Device.self, from: jsonData)
            return device
        } catch {
            if let result = response["resultCode"] {
                let resultCode = (result as? NSNumber)?.intValue ?? 0
                
                if resultCode == 0 {
                    throw error
                } else {
                    let errorDescription = response["userString"] as? String ?? response["resultString"] as? String
                    let localizedDescription = String(format: "%@ (%@)", errorDescription ?? "", "\(resultCode)")
                    throw AppleAPIError.customError(code: resultCode, message: localizedDescription)
                }
            } else {
                if let data = response["error"] as? String {
                    throw AppleAPIError.customError(code: 0, message: data)
                }
                throw AppleAPIError.badServerResponse
            }
        }
    }
    
    
    public func fetchCapabilitiesForTeam(team: Team, session: AppleAPISession) async throws -> [Capability] {
        let url = v1URL.appendingPathComponent("capabilities")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let response = try await sendServicesRequest(originalRequest: request, additionalParameters: ["filter[platform]": "IOS"], session: session, team: team)
        
        guard let data = try? JSONSerialization.data(withJSONObject: response["data"] ?? []) else {
            if let data = response["error"] as? String {
                throw AppleAPIError.customError(code: 0, message: data)
            }
            throw AppleAPIError.badServerResponse
        }
        
        let capabilities = try JSONDecoder().decode([Capability].self, from: data)
        
        return capabilities
    }
    

    func convertDatesToStrings(in dict: [String: Any]) -> [String: Any] {
        var newDict = [String: Any]()
        for (key, value) in dict {
            if let date = value as? Date {
                newDict[key] = date.iso8601()
            } else if let subDict = value as? [String: Any] {
                newDict[key] = convertDatesToStrings(in: subDict)
            } else if let array = value as? [Any] {
                newDict[key] = array.map { element -> Any in
                    if let elementDict = element as? [String: Any] {
                        return convertDatesToStrings(in: elementDict)
                    } else if let date = element as? Date {
                        return date.iso8601()
                    }
                    return element
                }
            } else {
                newDict[key] = value
            }
        }
        return newDict
    }
    
    public func fetchAppIDsForTeam(team: Team, session: AppleAPISession) async throws -> [AppID] {
        let url = qhURL.appendingPathComponent("ios/listAppIds.action")
        
        let response = try await sendRequestWithURL(requestURL: url, additionalParameters: nil, session: session, team: team)
        
        guard let array = response["appIds"] as? [[String: Any]] else {
            if let data = response["error"] as? String {
                throw AppleAPIError.customError(code: 0, message: data)
            }
            throw AppleAPIError.badServerResponse
        }
        
        let appIDs = array.compactMap { AppID(responseDictionary: $0) }
        
        return appIDs
    }
    
    public func addAppID(name: String, bundleIdentifier: String, team: Team, session: AppleAPISession) async throws -> AppID {
        let url = qhURL.appendingPathComponent("ios/addAppId.action")
        
        var sanitizedName = name.folding(options: .diacriticInsensitive, locale: nil)
        sanitizedName = sanitizedName.components(separatedBy: CharacterSet.alphanumerics.union(.whitespaces).inverted).joined()
        
        if sanitizedName.isEmpty {
            sanitizedName = "App"
        }
        
        let parameters = [
            "identifier": bundleIdentifier,
            "name": sanitizedName
        ]
        
        let response = try await sendRequestWithURL(requestURL: url, additionalParameters: parameters, session: session, team: team)
        
        guard let dictionary = response["appId"] as? [String: Any] else {
            // Handle result code errors
            if let resultCode = response["resultCode"] as? Int {
                switch resultCode {
                case 35:
                    throw AppleAPIError.customError(
                        code: resultCode,
                        message: "Invalid App ID Name (\(sanitizedName))"
                    )
                case 9120:
                    throw AppleAPIError.maximumAppIDLimitReached
                case 9401:
                    throw AppleAPIError.bundleIdentifierUnavailable
                case 9412:
                    throw AppleAPIError.invalidBundleIdentifier
                case 9400:
                    throw AppleAPIError.bundleIdentifierUnavailable
                default:
                    throw AppleAPIError.unknown
                }
            }
            
            if let data = response["error"] as? String {
                throw AppleAPIError.customError(code: 0, message: data)
            }
            throw AppleAPIError.badServerResponse
        }
        
        guard let appID = AppID(responseDictionary: dictionary) else {
            throw AppleAPIError.badServerResponse
        }
        
        return appID
    }
    
    public func updateAppID(_ appID: AppID, capabilities: [String], team: Team, session: AppleAPISession) async throws -> AppID {
        let url = v1URL.appendingPathComponent("bundleIds").appendingPathComponent(appID.identifier)
        
        let capabilitiesPayload: [[String: Any]] = capabilities.map { capabilityId in
            [
                "type": "bundleIdCapabilities",
                "attributes": ["enabled": true, "settings": []],
                "relationships": [
                    "capability": [
                        "data": ["type": "capabilities", "id": capabilityId]
                    ]
                ]
            ]
        }

        let payload: [String: Any] = [
            "data": [
                "type": "bundleIds",
                "id": appID.identifier,
                "attributes": [
                    "identifier": appID.bundleIdentifier,
                    "teamId": team.identifier,
                    "seedId": team.identifier,
                    "bundleType": "bundle",
                    "name": appID.name,
                    "hasExclusiveManagedCapabilities": false
                ],
                "relationships": [
                    "bundleIdCapabilities": ["data": capabilitiesPayload]
                ]
            ]
        ]
        
        let response = try await sendEditRequest(requestURL: url, body: payload, session: session, json: true, appendClientId: false)
        
        print("Server Response: \(response)")
        
        guard let _ = response["data"] as? [String: Any] else {
            if let data = response["error"] as? String {
                throw AppleAPIError.customError(code: 0, message: data)
            }
            throw AppleAPIError.badServerResponse
        }
        
        return appID
    }

    
    public func qHupdateAppID(_ appID: AppID, team: Team, session: AppleAPISession) async throws -> AppID {
        let url = qhURL.appendingPathComponent("ios/updateAppId.action")
        
        var parameters: [String: Any] = ["appIdId": appID.identifier]
        
        // Add features
        appID.features.forEach { key, value in
            parameters[key] = value
        }
        
        // Handle entitlements based on team type
        var entitlements = appID.entitlements
        
        if team.type == .free {
            entitlements = entitlements.filter { key in
                freeDeveloperCanUseEntitlement(key)
            }
        }
        
        parameters["entitlements"] = entitlements
        
        let response = try await sendRequestWithURL(requestURL: url, additionalParameters: parameters.mapValues { String(describing: $0) }, session: session, team: team)
        
        guard let dictionary = response["appId"] as? [String: Any] else {
            // Handle result code errors
            if let resultCode = response["resultCode"] as? Int {
                switch resultCode {
                case 35:
                    throw AppleAPIError.invalidAppIDName
                case 9100:
                    throw AppleAPIError.appIDDoesNotExist
                case 9412:
                    throw AppleAPIError.invalidBundleIdentifier
                default:
                    throw AppleAPIError.unknown
                }
            }
            
            if let data = response["error"] as? String {
                throw AppleAPIError.customError(code: 0, message: data)
            }
            throw AppleAPIError.badServerResponse
        }
        
        guard let updatedAppID = AppID(responseDictionary: dictionary) else {
            throw AppleAPIError.badServerResponse
        }
        
        return updatedAppID
    }
    
    public func deleteAppID(_ appID: AppID, team: Team, session: AppleAPISession) async throws -> Bool {
        let url = qhURL.appendingPathComponent("ios/deleteAppId.action")
        
        let parameters = ["appIdId": appID.identifier]
        
        let response = try await sendRequestWithURL(requestURL: url, additionalParameters: parameters, session: session, team: team)
        
        // Check result code
        if let resultCode = response["resultCode"] as? Int {
            switch resultCode {
            case 9100:
                throw AppleAPIError.appIDDoesNotExist
            case 0:
                return true
            default:
                throw AppleAPIError.unknown
            }
        }
        
        throw AppleAPIError.badServerResponse
    }
    
    // MARK: - App Groups
    
    public func fetchAppGroupsForTeam(team: Team, session: AppleAPISession) async throws -> [AppGroup] {
        let url = qhURL.appendingPathComponent("ios/listApplicationGroups.action")
        
        let response = try await sendRequestWithURL(requestURL: url, additionalParameters: nil, session: session, team: team)
        
        guard let data = try? JSONSerialization.data(withJSONObject: response["applicationGroupList"] ?? []) else {
            if let data = response["error"] as? String {
                throw AppleAPIError.customError(code: 0, message: data)
            }
            throw AppleAPIError.badServerResponse
        }
        
        let groups = try JSONDecoder().decode([AppGroup].self, from: data)

        return groups
    }
    
    public func addAppGroup(name: String, groupIdentifier: String, team: Team, session: AppleAPISession) async throws -> AppGroup {
        let url = qhURL.appendingPathComponent("ios/addApplicationGroup.action")
        
        let parameters = [
            "identifier": groupIdentifier,
            "name": name
        ]
        
        let response = try await sendRequestWithURL(requestURL: url, additionalParameters: parameters, session: session, team: team)
        
        guard let dictionary = response["applicationGroup"] as? [String: Any] else {
            if let resultCode = response["resultCode"] as? Int, resultCode == 35 {
                throw AppleAPIError.invalidAppGroup
            }
            
            if let data = response["error"] as? String {
                throw AppleAPIError.customError(code: 0, message: data)
            }
            throw AppleAPIError.badServerResponse
        }
        
        guard let data = try? JSONSerialization.data(withJSONObject: dictionary) else {
            throw AppleAPIError.badServerResponse
        }
        
        let groups = try JSONDecoder().decode(AppGroup.self, from: data)
        return groups
    }
    
    public func assignAppID(_ appID: AppID, toGroups groups: [AppGroup], team: Team, session: AppleAPISession) async throws -> Bool {
        let url = qhURL.appendingPathComponent("ios/assignApplicationGroupToAppId.action")
        
        let groupIDs = groups.map { $0.identifier }
        
        let parameters: [String: String] = [
            "appIdId": appID.identifier,
            "applicationGroups": groupIDs.joined(separator: ",")
        ]
        
        let response = try await sendRequestWithURL(requestURL: url, additionalParameters: parameters, session: session, team: team)
        
        if let resultCode = response["resultCode"] as? Int {
            switch resultCode {
            case 9115:
                throw AppleAPIError.appIDDoesNotExist
            case 35:
                throw AppleAPIError.appGroupDoesNotExist
            case 0:
                return true
            default:
                print(response)
                throw AppleAPIError.unknown
            }
        }
        
        throw AppleAPIError.badServerResponse
    }
    
    public func fetchProvisioningProfileForAppID(appID: AppID, deviceType: DeviceType, team: Team, session: AppleAPISession) async throws -> ProvisioningProfile {
        let url = qhURL.appendingPathComponent("ios/downloadTeamProvisioningProfile.action")
        
        var parameters: [String: String] = ["appIdId": appID.identifier]
        
        switch deviceType {
        case .iPhone, .iPad:
            parameters["DTDK_Platform"] = "ios"
        case .AppleTV:
            parameters["DTDK_Platform"] = "tvos"
            parameters["subPlatform"] = "tvOS"
        default:
            break
        }
        
        let response = try await sendRequestWithURL(requestURL: url, additionalParameters: parameters, session: session, team: team)
        
        if let resultCode = response["resultCode"] as? Int, resultCode == 8201 {
            throw AppleAPIError.appIDDoesNotExist
        }
        
        guard let dictionary = response["provisioningProfile"] as? [String: Any] else {
            if let data = response["error"] as? String {
                throw AppleAPIError.customError(code: 0, message: data)
            }
            throw AppleAPIError.badServerResponse
        }
        
        print("Provisioning Profile Response: \(dictionary)")
        let provisioningProfile = ProvisioningProfile(dictionary)
        
        return provisioningProfile
    }
    
    public func deleteProvisioningProfile(_ provisioningProfile: ProvisioningProfile, team: Team, session: AppleAPISession) async throws -> Bool {
        let url = qhURL.appendingPathComponent("ios/deleteProvisioningProfile.action")
        
        let parameters = [
            "provisioningProfileId": provisioningProfile.identifier,
            "teamId": team.identifier
        ]
        
        let response = try await sendRequestWithURL(requestURL: url, additionalParameters: parameters, session: session, team: team)
        
        if let resultCode = response["resultCode"] as? Int {
            switch resultCode {
            case 35:
                throw AppleAPIError.invalidProvisioningProfileIdentifier
            case 8101:
                throw AppleAPIError.provisioningProfileDoesNotExist
            case 0:
                return true
            default:
                throw AppleAPIError.unknown
            }
        }
        
        throw AppleAPIError.badServerResponse
    }
    
    public func sendServicesRequest(originalRequest: URLRequest, additionalParameters: [String: String]? = nil, session: AppleAPISession, team: Team) async throws -> [String: Any] {
        var request = originalRequest
        
        var queryItems = [URLQueryItem(name: "teamId", value: team.identifier)]
        
        additionalParameters?.forEach { key, value in
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        
        var components = URLComponents()
        components.queryItems = queryItems
        let queryString = components.query ?? ""
        
        let bodyData = try JSONSerialization.data(
            withJSONObject: ["urlEncodedQueryParams": queryString],
            options: []
        )
        request.httpBody = bodyData
        
        let originalHTTPMethod = request.httpMethod
        request.httpMethod = "POST"
        
        let httpHeaders: [String: String] = [
            "Content-Type": "application/vnd.api+json",
            "User-Agent": "Xcode",
            "Accept": "application/vnd.api+json",
            "Accept-Language": "en-us",
            "X-Apple-App-Info": "com.apple.gs.xcode.auth",
            "X-Xcode-Version": "27.0 (27A5218g)",
            "X-HTTP-Method-Override": originalHTTPMethod ?? "",
            "X-Apple-I-Identity-Id": session.dsid,
            "X-Apple-GS-Token": session.authToken,
            "X-Apple-I-MD-M": session.anisetteData.machineID,
            "X-Apple-I-MD": session.anisetteData.oneTimePassword,
            "X-Apple-I-MD-LU": session.anisetteData.localUserID,
            "X-Apple-I-MD-RINFO": String(session.anisetteData.routingInfo),
            "X-Mme-Device-Id": session.anisetteData.deviceUniqueIdentifier,
            "X-MMe-Client-Info": session.anisetteData.deviceDescription,
            "X-Apple-I-Client-Time": session.anisetteData.date.iso8601(),
            "X-Apple-Locale": session.anisetteData.locale.identifier,
            "X-Apple-I-TimeZone": session.anisetteData.timeZone.abbreviation() ?? ""
        ]
        
        httpHeaders.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        guard !data.isEmpty else {
            return [:]
        }
        
        guard let responseDictionary = try JSONSerialization.jsonObject(
            with: data,
            options: []
        ) as? [String: Any] else {
            throw AppleAPIError.badServerResponse
        }
        
        return responseDictionary
    }
    
    public func sendEditRequest(requestURL: URL, body: [String: Any], session: AppleAPISession, json: Bool = false, appendClientId: Bool = true) async throws -> [String : Any] {
        let bodyData = json ? try JSONSerialization.data(withJSONObject: body) : try PropertyListSerialization.data(fromPropertyList: body, format: .xml, options: 0)
        
        var urlString = requestURL.absoluteString
        if appendClientId {
            urlString.append("?clientId=\(clientID)")
        }
        guard let url = URL(string: urlString) else {
            throw AppleAPIError.invalidParameters
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.httpBody = bodyData
        
        let httpHeaders: [String: String] = [
            "Content-Type": json ? "application/vnd.api+json" : "text/x-xml-plist",
            "User-Agent": "Xcode",
            "Accept": json ? "application/json, text/plain, */*" : "text/x-xml-plist",
            "Accept-Language": "en-us",
            "X-Apple-App-Info": "com.apple.gs.xcode.auth",
            "X-Xcode-Version": "27.0 (27A5218g)",
            "X-Apple-I-Identity-Id": session.dsid,
            "X-Apple-GS-Token": session.authToken,
            "X-Apple-I-MD-M": session.anisetteData.machineID,
            "X-Apple-I-MD": session.anisetteData.oneTimePassword,
            "X-Apple-I-MD-LU": session.anisetteData.localUserID,
            "X-Apple-I-MD-RINFO": "\(session.anisetteData.routingInfo)",
            "X-Mme-Device-Id": session.anisetteData.deviceUniqueIdentifier,
            "X-MMe-Client-Info": session.anisetteData.deviceDescription,
            "X-Apple-I-Client-Time": session.anisetteData.date.iso8601(),
            "X-Apple-Locale": session.anisetteData.locale.identifier,
            "X-Apple-I-Locale": session.anisetteData.locale.identifier,
            "X-Apple-I-TimeZone": session.anisetteData.timeZone.abbreviation() ?? "GMT"
        ]
        
        for (key, value) in httpHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let (data, _) = try await self.session.data(for: request)
        
        if json {
            guard let responseDictionary = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                throw AppleAPIError.badServerResponse
            }
            
            return responseDictionary
        } else {
            guard let responseDictionary = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
                throw AppleAPIError.badServerResponse
            }
            
            return responseDictionary
        }
    }
    
    
    public func sendRequestWithURL(requestURL: URL, additionalParameters: [String: String]?, session: AppleAPISession, team: Team?) async throws -> [String : Any] {
        var parameters: [String: String] = [
            "clientId": clientID,
            "protocolVersion": QH_Protocol,
            "requestId": UUID().uuidString.uppercased()
        ]
        
        if let team = team {
            parameters["teamId"] = team.identifier
        }
        
        additionalParameters?.forEach { key, value in
            parameters[key] = value
        }
        
        let bodyData = try PropertyListSerialization.data(fromPropertyList: parameters, format: .xml, options: 0)
        
        var urlString = requestURL.absoluteString
        urlString.append("?clientId=\(clientID)")
        guard let url = URL(string: urlString) else {
            throw AppleAPIError.invalidParameters
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        
        let httpHeaders: [String: String] = [
            "Content-Type": "text/x-xml-plist",
            "User-Agent": "Xcode",
            "Accept": "text/x-xml-plist",
            "Accept-Language": "en-us",
            "X-Apple-App-Info": "com.apple.gs.xcode.auth",
            "X-Xcode-Version": "27.0 (27A5218g)",
            "X-Apple-I-Identity-Id": session.dsid,
            "X-Apple-GS-Token": session.authToken,
            "X-Apple-I-MD-M": session.anisetteData.machineID,
            "X-Apple-I-MD": session.anisetteData.oneTimePassword,
            "X-Apple-I-MD-LU": session.anisetteData.localUserID,
            "X-Apple-I-MD-RINFO": "\(session.anisetteData.routingInfo)",
            "X-Mme-Device-Id": session.anisetteData.deviceUniqueIdentifier,
            "X-MMe-Client-Info": session.anisetteData.deviceDescription,
            "X-Apple-I-Client-Time": session.anisetteData.date.iso8601(),
            "X-Apple-Locale": session.anisetteData.locale.identifier,
            "X-Apple-I-Locale": session.anisetteData.locale.identifier,
            "X-Apple-I-TimeZone": session.anisetteData.timeZone.abbreviation() ?? "GMT"
        ]
        
        for (key, value) in httpHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let (data, _) = try await self.session.data(for: request)
        
        guard let responseDictionary = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            throw AppleAPIError.badServerResponse
        }
        
        return responseDictionary
    }
    
    public func fetchAccount(session: AppleAPISession) async throws -> Account {
        let url = qhURL.appendingPathComponent("viewDeveloper.action")
        
        let response = try await sendRequestWithURL(requestURL: url, additionalParameters: nil, session: session, team: nil)
        
        guard let dictionary = response["developer"] as? [String: Any] else {
            if let data = response["error"] as? String {
                throw AppleAPIError.customError(code: 0, message: data)
            }
            throw AppleAPIError.badServerResponse
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: dictionary)
        
        guard let account = try? JSONDecoder().decode(Account.self, from: jsonData) else {
            throw AppleAPIError.badServerResponse
        }
        
        return account
    }
}

public enum SignError: Int, Error {
    case unknown
    case invalidApp
    case missingAppBundle
    case missingInfoPlist
    case missingProvisioningProfile
}

extension Date {
    func iso8601() -> String {
        if #available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *) {
            return self.formatted(.iso8601)
        } else {
            let formatter = ISO8601DateFormatter()
            return formatter.string(from: self)
        }
    }
}
