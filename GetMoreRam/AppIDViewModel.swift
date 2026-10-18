//
//  AppIDViewModel.swift
//  GetMoreRam
//
//  Created by s s on 2025/3/15.
//
import SwiftUI
import StosSign_API
import StosSign_Auth
import StosSign_Common

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
    @Published var isUpdating = false
    
    init(appID: AppID) {
        self.appID = appID
        bundleID = appID.bundleIdentifier
    }
    
    @MainActor
    func addIncreasedMemory() async throws {
        guard !isUpdating else { return }
        isUpdating = true
        defer { isUpdating = false }
        guard let team = DataManager.shared.model.team, let session = DataManager.shared.model.session else {
            throw "Please Login First"
        }

        result = "Refreshing anisette before updating \(bundleID)..."
        do {
            session.anisetteData = try await AnisetteDataHelper.shared.getAnisetteData(refresh: true)
            result = "Requesting Increased Memory Limit for \(bundleID)..."
            _ = try await AppleAPI.shared.updateAppID(appID, capabilities: ["INCREASED_MEMORY_LIMIT"], team: team, session: session)
            result = "Apple accepted the Increased Memory Limit request for:\n\(bundleID)\n\nRefresh/re-sign LiveContainer in SideStore to obtain a new provisioning profile. The entitlement in the installed app and the resulting memory limit have not been verified."
        } catch {
            result = "Capability update could not be confirmed:\n\(error.detailedDescription)"
            throw error
        }
    }
    
}

class AppIDViewModel : ObservableObject {
    @Published var appIDs : [AppIDModel] = []
    
    @MainActor
    func fetchAppIDs() async throws {
        guard let team = DataManager.shared.model.team, let session = DataManager.shared.model.session else {
            throw "Please Login First"
        }
        
        session.anisetteData = try await AnisetteDataHelper.shared.getAnisetteData(refresh: true)
        let ids = try await AppleAPI.shared.fetchAppIDsForTeam(team: team, session: session)
        await MainActor.run {
            appIDs.removeAll()
            for id in ids {
                appIDs.append(AppIDModel(appID: id))
            }
        }
    }
}
