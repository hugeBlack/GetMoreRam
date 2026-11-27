//
//  LoginViewModel.swift
//  GetMoreRam
//
//  Created by s s on 2025/3/15.
//
import SwiftUI
import SideSign
import AnisetteKit

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
    
    private var verificationCodeContinuation: CheckedContinuation<TwoFactorResponse, Never>?
    private var isAuthenticationCancellationRequested = false
    
    func submitVerificationCode() {
        guard !isVerificationCodeSubmitting,
              let verificationCodeContinuation else { return }

        self.verificationCodeContinuation = nil
        isVerificationCodeSubmitting = true
        verificationCodeContinuation.resume(returning: .verificationCode(verificationCode))
    }

    func cancelAuthentication() {
        guard isLoginInProgress else { return }

        isAuthenticationCancellationRequested = true

        let verificationCodeContinuation = verificationCodeContinuation
        self.verificationCodeContinuation = nil
        needVerificationCode = false
        verificationCode = ""
        isVerificationCodeSubmitting = false

        verificationCodeContinuation?.resume(returning: .cancel)
    }
    
    func authenticate() async throws -> Bool {
        if isLoginInProgress {
            return false
        }
        
        logs = ""
        isLoginInProgress = true
        isAuthenticationCancellationRequested = false
        
        defer {
            verificationCodeContinuation = nil
            appleID = ""
            password = ""
            needVerificationCode = false
            verificationCode = ""
            isLoginInProgress = false
            isVerificationCodeSubmitting = false
            isAuthenticationCancellationRequested = false
        }

        do {
            DeveloperPortal.shared.customHeaders.grandSlam.userAgent = DataManager.shared.model.anisetteUA
            DeveloperPortal.shared.customHeaders.appleAuth.userAgent = DataManager.shared.model.anisetteUA
            
            let anisetteData = try await DataManager.fetchAnisetteData { msg in
                await MainActor.run {
                    self.logs += msg
                }
            }
            let authentication = try await DeveloperPortal.shared.authenticate(
                appleID: appleID,
                password: password,
                anisetteData: anisetteData,
                xcodeVersion: "26.0",
                verificationHandler: { [weak self] request in
                    guard let self else { return .cancel }
                    return await self.respondToVerification(request)
                }
            )

            guard !isAuthenticationCancellationRequested else {
                throw CancellationError()
            }

            logs += "Successfully signed in\n"

            let teams = try await DeveloperPortal.shared.fetchTeams(
                for: authentication.account,
                session: authentication.session
            )
            guard !isAuthenticationCancellationRequested else {
                throw CancellationError()
            }

            DataManager.shared.model.account = authentication.account
            DataManager.shared.model.session = authentication.session
            Keychain.shared.appleIDEmailAddress = appleID
            Keychain.shared.appleIDPassword = password
            logs += "Successfully fetched teams\n"
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

    private func respondToVerification(_ request: TwoFactorRequest) async -> TwoFactorResponse {
        guard !isAuthenticationCancellationRequested else { return .cancel }

        if case .selectDeliveryMethod(let preferredMode, let phoneNumbers) = request {
            switch preferredMode {
            case .trustedDevice:
                return .requestTrustedDevice
            case .sms:
                return .requestSMS(phoneID: phoneNumbers.first?.id ?? "1")
            case .voice:
                return .requestVoice(phoneID: phoneNumbers.first?.id ?? "1")
            }
        }

        if let error = request.error {
            logs += "\(error)\n"
        }
        return await withCheckedContinuation { continuation in
            verificationCodeContinuation = continuation
            verificationCode = ""
            needVerificationCode = true
            isVerificationCodeSubmitting = false
        }
    }


    
}
