//
//  AppIDViewModel.swift
//  GetMoreRam
//
//  Created by s s on 2025/3/15.
//
import SwiftUI
import SideSign

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

        try await DeveloperPortal.shared.enableIncreasedMemoryLimit(for: appID, team: team, session: session)
        
        result = "\(appID)"
    }
    
    func check() async throws -> Bool {
        guard let team = DataManager.shared.model.team, let session = DataManager.shared.model.session else {
            throw "Please Login First"
        }
        
        let profile = try await DeveloperPortal.shared.downloadProvisioningProfile(for: appID, team: team, session: session)
        if let iml = profile.entitlements["com.apple.developer.kernel.increased-memory-limit"] as? Bool, iml {
            return true
        } else {
            return false
        }
    }
    
}

class AppIDViewModel : ObservableObject {
    @Published var appIDs : [AppIDModel] = []
    
    func fetchAppIDs() async throws {
        guard let team = DataManager.shared.model.team, let session = DataManager.shared.model.session else {
            throw "Please Login First"
        }
        
        let ids = try await DeveloperPortal.shared.fetchAppIDs(for: team, session: session)
        if ids.isEmpty {
            throw "No App ID was found. Are you logged into the wrong account?"
        }
        
        await MainActor.run {
            appIDs.removeAll()
            for id in ids {
                appIDs.append(AppIDModel(appID: id))
            }
        }
    }
}

private extension DeveloperPortal {
    // SideSign's updateAppID uses the plist feature API. This capability uses the JSON bundle ID API.
    func enableIncreasedMemoryLimit(for appID: AppID, team: Team, session: Session) async throws {
        let url = servicesBaseURL.appendingPathComponent("bundleIds").appendingPathComponent(appID.identifier)
        let capability: [String: Any] = [
            "type": "bundleIdCapabilities",
            "attributes": ["enabled": true, "settings": []],
            "relationships": [
                "capability": ["data": ["type": "capabilities", "id": "INCREASED_MEMORY_LIMIT"]]
            ]
        ]
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
                "relationships": ["bundleIdCapabilities": ["data": [capability]]]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let anisetteData = try await DataManager.fetchAnisetteData()
        AnisetteDataManager.toHTTPHeaders(data: anisetteData).forEach {
            request.setValue($0.value, forHTTPHeaderField: $0.key)
        }
        request.setValue("application/vnd.api+json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("en-us", forHTTPHeaderField: "Accept-Language")
        request.setValue(customHeaders.developerServices.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(customHeaders.grandSlam.authApp, forHTTPHeaderField: "X-Apple-App-Info")
        request.setValue(session.xcodeVersion, forHTTPHeaderField: "X-Xcode-Version")
        request.setValue(session.dsid, forHTTPHeaderField: "X-Apple-I-Identity-Id")
        request.setValue(session.authToken, forHTTPHeaderField: "X-Apple-GS-Token")
        request.setValue(session.anisetteData.locale, forHTTPHeaderField: "X-Apple-I-Locale")

        let (data, response) = try await URLSession.shared.data(for: request)
        let body = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(statusCode), body?["data"] is [String: Any] else {
            let errors = body?["errors"] as? [[String: Any]]
            let message = errors?.first?["detail"] as? String ?? body?["error"] as? String
            throw message ?? "Unable to update the App ID (HTTP \(statusCode))."
        }
    }
}
