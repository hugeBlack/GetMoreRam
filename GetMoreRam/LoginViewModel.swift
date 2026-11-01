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
    // Set once Apple asks for a 2FA code; after that a retry would send a second prompt
    private var didRequestVerificationCode = false
    
    private static let maxSignInAttempts = 3
    
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
            Task { @MainActor [weak self] in
                self?.logs.append("\(text)\n")
            }
        }
        
        AnisetteDataHelper.shared.loggingFunc = logging

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
            let (account, session) = try await authenticateWithRetry(log: logging)

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
            throw error
        }
    }

    /// Signs in, retrying with anisette data from a different server when Apple
    /// rejects the anisette data or the connection drops. Wrong password, locked
    /// account etc. are never retried so the account doesn't get locked.
    private func authenticateWithRetry(log: (String) -> Void) async throws -> (Account, AppleAPISession) {
        var badServers = Set<String>()
        didRequestVerificationCode = false
        
        for attempt in 1...Self.maxSignInAttempts {
            let anisetteData = try await AnisetteDataHelper.shared.getAnisetteData(excluding: badServers)
            let server = AnisetteDataHelper.shared.lastUsedURL?.absoluteString
            
            do {
                return try await AppleAPI.shared.authenticate(appleID: appleID, password: password, anisetteData: anisetteData) { [weak self] completionHandler in
                    guard let self else {
                        completionHandler(nil)
                        return
                    }

                    self.prepareForVerification(using: completionHandler)
                }
            } catch {
                if Self.isRejectedAnisette(error) {
                    // Apple refused this anisette identity; provision a fresh one next time
                    AnisetteDataHelper.shared.resetProvisioning()
                }
                
                guard attempt < Self.maxSignInAttempts,
                      !isAuthenticationCancellationRequested,
                      !didRequestVerificationCode,
                      Self.isAnisetteRelated(error),
                      // Apple rejecting the identity twice in a row won't be fixed by hammering it
                      !(Self.isRejectedAnisette(error) && attempt >= 2) else {
                    if Self.isRejectedAnisette(error) {
                        throw "\(error.localizedDescription)\n\nApple refused the sign in from this anisette identity. It has been reset, so tap Continue to try again with a new one (Apple may ask for a verification code again). If it keeps failing, wait a while before retrying, because repeated attempts can make it worse."
                    }
                    throw error
                }
                
                log("Sign in failed (\(error.localizedDescription)), retrying with another anisette server (\(attempt + 1)/\(Self.maxSignInAttempts))")
                if let server {
                    badServers.insert(server)
                    AnisetteServerPool.shared.recordFailure(server)
                }
                try await Task.sleep(nanoseconds: UInt64(attempt) * 1_000_000_000)
            }
        }
        
        throw "Sign in failed"
    }
    
    private static func isAnisetteRelated(_ error: Error) -> Bool {
        if error is URLError { return true }
        if isRejectedAnisette(error) { return true }
        guard let apiError = error as? AppleAPIError else { return false }
        switch apiError {
        case .invalidAnisetteData, .authenticationHandshakeFailed, .badServerResponse:
            return true
        default:
            return false
        }
    }
    
    /// -80045 (initial login) / -80046 (after the verification code): Apple
    /// refuses the device identity the anisette data claims.
    private static func isRejectedAnisette(_ error: Error) -> Bool {
        guard case .customError(let code, _) = error as? AppleAPIError else { return false }
        return code == -80045 || code == -80046
    }

    private func prepareForVerification(using handler: @escaping (String?) -> Void) {
        guard !isAuthenticationCancellationRequested else {
            handler(nil)
            return
        }

        didRequestVerificationCode = true
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
