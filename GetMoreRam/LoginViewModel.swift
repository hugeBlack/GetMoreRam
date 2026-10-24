//
//  LoginViewModel.swift
//  GetMoreRam
//
//  Created by s s on 2025/3/15.
//
import SwiftUI
import StosSign_API
import StosSign_Auth
import StosSign_Common

@MainActor
class LoginViewModel: ObservableObject {
    @Published var appleID = ""
    @Published var password = ""
    @Published var needVerificationCode = false
    @Published var verificationCode = ""
    @Published var loginModalShow = false
    @Published var teamSelectionShow = false
    @Published var isLoginInProgress = false
    @Published private(set) var isVerificationCodeSubmitting = false
    @Published var logs = ""
    @Published var availableTeams: [Team] = []
    
    private var verificationCodeHandler: ((String?) -> Void)?
    private var isAuthenticationCancellationRequested = false
    
    func submitVerificationCode() {
        guard !isVerificationCodeSubmitting,
              let verificationCodeHandler else { return }

        self.verificationCodeHandler = nil
        isVerificationCodeSubmitting = true
        verificationCodeHandler(verificationCode)
    }

    func cancelAuthentication() {
        guard isLoginInProgress else { return }

        isAuthenticationCancellationRequested = true

        let verificationCodeHandler = verificationCodeHandler
        self.verificationCodeHandler = nil
        needVerificationCode = false
        verificationCode = ""
        isVerificationCodeSubmitting = false

        verificationCodeHandler?(nil)
    }
    
    func authenticate() async throws -> Bool {
        if isLoginInProgress {
            return false
        }
        
        logs = ""
        isLoginInProgress = true
        isAuthenticationCancellationRequested = false
        
        func logging(text: String) {
            NSLog("[GetMoreRam] %@", text)
            Task { @MainActor [weak self] in
                self?.logs.append("\(text)\n")
            }
        }
        
        AnisetteDataHelper.shared.loggingFunc = logging
        
        let settings = AuthenticationSettings.shared
        Authentication.userAgentOverride = settings.useServerClientInfo ? nil : settings.effectiveGrandSlamUserAgent
        Authentication.twoFactorUserAgentOverride = nil
        Authentication.useSideSignRequestFormat = false
        Authentication.xcodeVersion = "27.0 (27A5218g)"
        Authentication.progressHandler = logging
        Authentication.anisetteDataRefreshHandler = {
            try await AnisetteDataHelper.shared.getAnisetteData(refresh: true)
        }

        defer {
            verificationCodeHandler = nil
            appleID = ""
            password = ""
            needVerificationCode = false
            verificationCode = ""
            isLoginInProgress = false
            isVerificationCodeSubmitting = false
            isAuthenticationCancellationRequested = false
        }

        do {
            let anisetteData = try await fetchAnisetteData(settings: settings, logging: logging)
            if settings.useServerClientInfo {
                // Use the server's user agent for GrandSlam too
                Authentication.userAgentOverride = AnisetteDataHelper.shared.userAgent
            }
            if AnisetteDataHelper.shared.sideStoreIdentifier != nil {
                // Identity imported from SideStore 2.0: send exactly what SideSign sends
                logging(text: "SideStore identity: using SideSign request format")
                Authentication.useSideSignRequestFormat = true
                Authentication.twoFactorUserAgentOverride = "Xcode"
                Authentication.xcodeVersion = "26.0 (26A242)"
            }

            let (account, session) = try await AppleAPI.shared.authenticate(appleID: appleID, password: password, anisetteData: anisetteData) { [weak self] completionHandler in
                guard let self else {
                    completionHandler(nil)
                    return
                }

                self.prepareForVerification(using: completionHandler)
            }

            guard !isAuthenticationCancellationRequested else {
                throw CancellationError()
            }

            logging(text: "Successfully signed in")

            DataManager.shared.model.account = account
            DataManager.shared.model.session = session
            Keychain.shared.appleIDEmailAddress = appleID
            Keychain.shared.appleIDPassword = password

            let teams = try await fetchTeams(for: account, session: session)
            logging(text: "Successfully fetched teams")
            availableTeams = teams

            return true
        } catch {
            if isAuthenticationCancellationRequested {
                throw CancellationError()
            }
            print(error)
            if error.localizedDescription.contains("-80046") {
                logging(text: "Apple refused the token (-80046). Use a macOS-ADI server (SideStore (New), jkcoxson…) with the \"macOS current Mac\" preset, then tap \"Clean Up Keychain\" and sign in again.")
            }
            throw error
        }
    }

    /// Tries the selected anisette server, then the other ones if fallback is enabled.
    private func fetchAnisetteData(settings: AuthenticationSettings, logging: (String) -> Void) async throws -> AnisetteData {
        let servers = settings.serversToTry
        guard !servers.isEmpty else {
            throw "No anisette server configured. Add one in Settings."
        }
        
        var lastError: Error?
        for server in servers {
            guard let url = URL(string: server.address) else { continue }
            try Task.checkCancellation()
            logging("Trying anisette server \(server.name) (\(server.address))")
            if server.library != .mac, await AnisetteDataHelper.shared.serverRunsAndroidADI(url) == true {
                // Apple takes the password and the code, then refuses the token (-80046)
                logging("Skipping \(server.address): it runs Apple's Android ADI library, whose token Apple refuses (-80046). Use a macOS-ADI server.")
                lastError = "\(server.name) runs Apple's Android ADI library, which Apple refuses since October 21 (-80046). Pick a macOS-ADI server such as SideStore (New) in Settings › Anisette Servers."
                continue
            }
            AnisetteDataHelper.shared.configure(
                server: url,
                clientInfo: settings.clientInfo,
                userAgent: settings.userAgent,
                useServerClientInfo: settings.useServerClientInfo
            )
            do {
                return try await AnisetteDataHelper.shared.getAnisetteData()
            } catch {
                logging("Anisette server \(server.address) failed: \(error.localizedDescription)")
                lastError = error
            }
        }
        throw lastError ?? "No anisette server could be reached"
    }

    private func prepareForVerification(using handler: @escaping (String?) -> Void) {
        guard !isAuthenticationCancellationRequested else {
            handler(nil)
            return
        }

        verificationCodeHandler = handler
        verificationCode = ""
        needVerificationCode = true
        isVerificationCodeSubmitting = false
    }
    
    func fetchTeams(for account: Account, session: AppleAPISession) async throws -> [Team]
    {

        let fetchedTeams = try await AppleAPI.shared.fetchTeamsForAccount(account: account, session: session)
        guard !fetchedTeams.isEmpty else {
            throw "Unable to Fetch Team!"
        }
        
        return fetchedTeams
    }
}
