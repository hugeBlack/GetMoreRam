//
//  LoginViewModel.swift
//  Entitlement
//
//  Created by s s on 2025/3/15.
//
import SwiftUI
import AltSign
import KeychainAccess

class LoginViewModel: ObservableObject {
    @Published var appleID = ""
    @Published var password = ""
    @Published var needVerificationCode = false
    @Published var verificationCode = ""
    @Published var loginModalShow = false
    @Published var isLoginInProgress = false
    private var verificationCodeHandler: ((String?) -> Void)?
    
    func submitVerficationCode() {
        if let verificationCodeHandler {
            verificationCodeHandler(verificationCode)
        }
    }
    
    func authenticate() async throws -> Bool {
        if isLoginInProgress {
            return false
        }
        
        await MainActor.run {
            isLoginInProgress = true
        }

        defer {
            Task{ await MainActor.run {
                self.appleID = ""
                self.password = ""
                needVerificationCode = false
                verificationCode = ""
                isLoginInProgress = false
            }}
        }
        
        let anisetteData = try await AnisetteDataHelper.shared.getAnisetteData()
        
        let (account, session) = try await withUnsafeThrowingContinuation { (c : UnsafeContinuation<(ALTAccount, ALTAppleAPISession), Error>) in
            ALTAppleAPI.shared.authenticate(appleID: appleID, password: password, anisetteData: anisetteData) { [self] (completionHandler) in
                verificationCodeHandler = completionHandler
                Task{ await MainActor.run {
                    needVerificationCode = true
                }}
            } completionHandler: { account, session, error in
                if let error {
                    c.resume(throwing: error)
                    return
                }
                
                c.resume(returning: (account!, session!))
            }
        }
        
        DataManager.shared.model.account = account
        DataManager.shared.model.session = session
        Keychain.shared.appleIDEmailAddress = self.appleID
        Keychain.shared.appleIDPassword = self.password
        
        let team = try await fetchTeam(for: account, session: session)
        DataManager.shared.model.team = team
        
        Task{ await MainActor.run {
            DataManager.shared.model.isLogin = true
        }}
        
        return true
    }
    
    func fetchTeam(for account: ALTAccount, session: ALTAppleAPISession) async throws -> ALTTeam
    {

        let fetchedTeams = try await withUnsafeThrowingContinuation { (c: UnsafeContinuation<[ALTTeam]?, Error>) in
            ALTAppleAPI.shared.fetchTeams(for: account, session: session) { (teams, error) in
                if let error {
                    c.resume(throwing: error)
                    return
                }
                c.resume(returning: teams)
            }
        }
        guard let fetchedTeams, !fetchedTeams.isEmpty, let team = fetchedTeams.first else {
            throw "Unable to Fetch Team!"
        }
        
        return team
    }
}
