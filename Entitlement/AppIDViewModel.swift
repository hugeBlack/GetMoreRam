//
//  AppIDViewModel.swift
//  Entitlement
//
//  Created by s s on 2025/3/15.
//
import SwiftUI
import StosSign

class AppIDModel : ObservableObject, Hashable {
    static func == (lhs: AppIDModel, rhs: AppIDModel) -> Bool {
        return lhs === rhs
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
    
    var appID: AppID
    @Published var bundleID: String
    @Published var result: String = ""
    
    init(appID: AppID) {
        self.appID = appID
        bundleID = appID.bundleIdentifier
    }
    
    func addIncreasedMemory() async throws {
        guard let team = DataManager.shared.model.team, let session = DataManager.shared.model.session else {
            throw "Please Login First"
        }

        let dateFormatter = ISO8601DateFormatter()
        let httpHeaders = [
            "Content-Type": "application/vnd.api+json",
            "User-Agent": "Xcode",
            "Accept": "application/vnd.api+json",
            "Accept-Language": "en-us",
            "X-Apple-App-Info": "com.apple.gs.xcode.auth",
            "X-Xcode-Version": "11.2 (11B41)",
            "X-Apple-I-Identity-Id": session.dsid,
            "X-Apple-GS-Token": session.authToken,
            "X-Apple-I-MD-M": session.anisetteData.machineID,
            "X-Apple-I-MD": session.anisetteData.oneTimePassword,
            "X-Apple-I-MD-LU": session.anisetteData.localUserID,
            "X-Apple-I-MD-RINFO": session.anisetteData.routingInfo.description,
            "X-Mme-Device-Id": session.anisetteData.deviceUniqueIdentifier,
            "X-MMe-Client-Info": session.anisetteData.deviceDescription,
            "X-Apple-I-Client-Time": dateFormatter.string(from:session.anisetteData.date),
            "X-Apple-Locale": session.anisetteData.locale.identifier,
            "X-Apple-I-TimeZone": session.anisetteData.timeZone.abbreviation()!
        ] as [String : String];
        
        var request = URLRequest(url: URL(string: "https://developerservices2.apple.com/services/v1/bundleIds/\(appID.identifier)")!)
        request.httpMethod = "PATCH"
        request.allHTTPHeaderFields = httpHeaders
        request.httpBody = "{\"data\":{\"relationships\":{\"bundleIdCapabilities\":{\"data\":[{\"relationships\":{\"capability\":{\"data\":{\"id\":\"INCREASED_MEMORY_LIMIT\",\"type\":\"capabilities\"}}},\"type\":\"bundleIdCapabilities\",\"attributes\":{\"settings\":[],\"enabled\":true}}]}},\"id\":\"\(appID.identifier)\",\"attributes\":{\"hasExclusiveManagedCapabilities\":false,\"teamId\":\"\(team.identifier)\",\"bundleType\":\"bundle\",\"identifier\":\"\(appID.bundleIdentifier)\",\"seedId\":\"\(team.identifier)\",\"name\":\"\(appID.name)\"},\"type\":\"bundleIds\"}}".data(using: .utf8)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        await MainActor.run {
            result = String(data: data, encoding: .utf8) ?? "Unable to decode response."
        }
        
    }
    
}

class AppIDViewModel : ObservableObject {
    @Published var appIDs : [AppIDModel] = []
    
    func fetchAppIDs() async throws {
        guard let team = DataManager.shared.model.team, let session = DataManager.shared.model.session else {
            throw "Please Login First"
        }
        
        let ids = try await withUnsafeThrowingContinuation { (c: UnsafeContinuation<[AppID], Error>) in
            AppleAPI().fetchAppIDsForTeam(team: team, session: session) { (appIDs, error) in
                if let error = appIDs as? Error {
                    c.resume(throwing: error)
                }
                guard let appIDs else {
                    c.resume(throwing: "AppIDs is nil. Please try again or reopen the app.")
                    return
                }
                c.resume(returning: appIDs)
            }
        }
        await MainActor.run {
            for id in ids {
                appIDs.append(AppIDModel(appID: id))
            }
        }
    }
}
