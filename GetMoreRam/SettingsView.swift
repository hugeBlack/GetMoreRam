//
//  SettingsView.swift
//  GetMoreRam
//
//  Created by s s on 2025/3/14.
//

import SwiftUI
import UniformTypeIdentifiers
import StosSign_API
import StosSign_Auth
import StosSign_Common

struct SettingsView: View {

    @State var email = ""
    @State var teamId = ""
    @StateObject var viewModel : LoginViewModel
    @EnvironmentObject private var sharedModel : SharedModel
    @ObservedObject private var authSettings = AuthenticationSettings.shared
    
    @State private var errorShow = false
    @State private var errorInfo = ""
    @State private var importResultShow = false
    @State private var importResultInfo = ""
    @State private var isImportingSideStoreAccount = false
    @State private var sideStoreFilePasswordShow = false
    @State private var sideStoreFilePassword = ""
    @State private var pendingSideStoreAccountData: Data?


    var body: some View {
        NavigationStack {
            settingsForm
                .navigationTitle("Settings")
        }
    }
    
    var settingsForm: some View {
        Form {

            Section {
                if sharedModel.isLogin {
                    HStack {
                        Text("Email")
                        Spacer()
                        Text(email)
                    }
                    HStack {
                        Text("Team ID")
                        Spacer()
                        Text(teamId)
                    }
                } else {
                    Button("Sign in") {
                        viewModel.loginModalShow = true
                    }
                    
                    Button("Import SideStore Account") {
                        isImportingSideStoreAccount = true
                    }
                    .disabled(viewModel.isLoginInProgress)
                }
            } header: {
                Text("Account")
            }
            
            Section {
                NavigationLink {
                    AnisetteServersView()
                } label: {
                    HStack {
                        Text("Anisette Server")
                        Spacer()
                        Text(authSettings.selectedServer?.name ?? "None")
                            .foregroundStyle(.secondary)
                    }
                }
                NavigationLink {
                    AuthenticationHeadersView()
                } label: {
                    HStack {
                        Text("Client Info / User-Agent")
                        Spacer()
                        Text(authSettings.useServerClientInfo ? "Server" :
                                (HeaderPreset.all.first { $0.id == authSettings.currentPresetID }?.name ?? "Custom"))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            } header: {
                Text("Authentication")
            }
            
            Section {
                Button("Clean Up Keychain") {
                    cleanUp()
                }
            } footer: {
                Text("If something went wrong during signing in, please try to clean up the keychain, repoen the app and try again. \n \nIf you use SideStore and are already signed in, please also try exporting SideStore Account from SideStore settings and import it here to sign in. Newer SideStore versions export an encrypted .sideconf file, so keep the file password you chose, it is asked for while importing.")
            }
        }
        .alert("Error", isPresented: $errorShow){
            Button("OK".loc, action: {
            })
        } message: {
            Text(errorInfo)
        }
        .alert("SideStore Account", isPresented: $importResultShow){
            Button("OK".loc, action: {
            })
        } message: {
            Text(importResultInfo)
        }
        .alert("File Password", isPresented: $sideStoreFilePasswordShow){
            SecureField("Password", text: $sideStoreFilePassword)
            Button("Import".loc, action: {
                importEncryptedSideStoreAccount()
            })
            Button("Cancel".loc, role: .cancel, action: {
                cancelSideStoreFilePassword()
            })
        } message: {
            Text("This SideStore account file is encrypted. Enter the file password you chose while exporting it from SideStore.")
        }
        .fileImporter(
            isPresented: $isImportingSideStoreAccount,
            allowedContentTypes: [.sideStoreConfiguration, .json, .data],
            allowsMultipleSelection: false
        ) { result in
            importSideStoreAccount(result)
        }

        .sheet(isPresented: $viewModel.loginModalShow, onDismiss: {
            viewModel.cancelAuthentication()
        }) {
            loginModal
        }
        .sheet(isPresented: $viewModel.teamSelectionShow) {
            teamSelectionView
        }
    }
    
    var loginModal: some View {
        NavigationView {
            Form {
                Section {
                    TextField("", text: $viewModel.appleID)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .disabled(viewModel.isLoginInProgress)
                } header: {
                    Text("Apple ID")
                }
                Section {
                    SecureField("", text: $viewModel.password)
                        .disabled(viewModel.isLoginInProgress)
                } header: {
                    Text("Password")
                }
                if viewModel.needVerificationCode {
                    Section {
                        Text("Enter the code shown on your trusted device (or sent by SMS).")
                            .font(.footnote)
                        TextField("", text: $viewModel.verificationCode)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .disabled(viewModel.isVerificationCodeSubmitting)
                    } header: {
                        Text("Verification Code")
                    }
                }
                Section {
                    Button("Continue") {
                        Task{ await loginButtonClicked() }
                    }
                    .disabled(continueButtonDisabled)
                }
                
                Section {
                    Text(viewModel.logs)
                        .font(.system(.subheadline, design: .monospaced))
                        .textSelection(.enabled)
                    Button("Copy Logs") {
                        UIPasteboard.general.string = viewModel.logs
                    }
                    .disabled(viewModel.logs.isEmpty)
                } header: {
                    Text("Debugging")
                }
            }
            .navigationTitle("Sign in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", role: .cancel) {
                        viewModel.cancelAuthentication()
                        viewModel.loginModalShow = false
                    }
                }
            }
        }
        .onAppear {
            if let email = Keychain.shared.appleIDEmailAddress, let password = Keychain.shared.appleIDPassword {
                viewModel.appleID = email
                viewModel.password = password
            }
        }
    }
    
    var teamSelectionView: some View {
        NavigationView {
            List {
                ForEach(Array(viewModel.availableTeams.enumerated()), id: \.offset) { _, team in
                    Button {
                        selectTeam(team)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(team.name)
                                .foregroundStyle(.primary)
                            Text("\(team.identifier) · \(teamTypeDescription(team.type))")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Choose Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", role: .cancel) {
                        cancelTeamSelection()
                    }
                }
            }
        }
    }
    
    func loginButtonClicked() async {
        do {
            if viewModel.needVerificationCode {
                viewModel.submitVerificationCode()
                return
            }
            
            let result = try await viewModel.authenticate()
            if result {
                await MainActor.run {
                    viewModel.loginModalShow = false
                    email = sharedModel.account!.appleID
                    teamId = ""
                }

                if viewModel.availableTeams.count == 1,
                   let team = viewModel.availableTeams.first {
                    await MainActor.run {
                        selectTeam(team)
                    }
                } else {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    await MainActor.run {
                        viewModel.teamSelectionShow = true
                    }
                }
            }
            
        } catch is CancellationError {
            return
        } catch {
            errorInfo = error.detailedDescription
            errorShow = true
        }
    }

    private var continueButtonDisabled: Bool {
        if viewModel.needVerificationCode {
            return viewModel.isVerificationCodeSubmitting ||
                viewModel.verificationCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        return viewModel.isLoginInProgress
    }
    
    func cleanUp() {
        Keychain.shared.adiPb = nil
        Keychain.shared.adiPbProvisioningContext = nil
        Keychain.shared.identifier = nil
        Keychain.shared.appleIDPassword = nil
        Keychain.shared.appleIDEmailAddress = nil
        AnisetteDataHelper.shared.resetClientInfo()
        sharedModel.session = nil
        sharedModel.account = nil
        sharedModel.team = nil
        sharedModel.isLogin = false
        viewModel.availableTeams = []
        viewModel.teamSelectionShow = false
        email = ""
        teamId = ""
    }
    
    func importSideStoreAccount(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else {
                throw "No file selected."
            }

            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)

            // Newer SideStore versions export an encrypted .sideconf file, older ones plain JSON.
            guard !SideStoreAccountImporter.requiresPassword(for: data) else {
                pendingSideStoreAccountData = data
                sideStoreFilePassword = ""
                // Give the document picker time to dismiss before presenting the alert.
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    sideStoreFilePasswordShow = true
                }
                return
            }

            let account = try SideStoreAccountImporter.importAccount(from: data)
            applyImportedSideStoreAccount(account)
        } catch {
            errorInfo = error.detailedDescription
            errorShow = true
        }
    }

    func importEncryptedSideStoreAccount() {
        let data = pendingSideStoreAccountData
        let filePassword = sideStoreFilePassword
        pendingSideStoreAccountData = nil
        sideStoreFilePassword = ""

        // Wait for the password alert to dismiss, otherwise the follow up alert is swallowed.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            do {
                guard let data else {
                    throw "No file selected."
                }

                let account = try SideStoreAccountImporter.importAccount(from: data, filePassword: filePassword)
                applyImportedSideStoreAccount(account)
            } catch {
                errorInfo = error.detailedDescription
                errorShow = true
            }
        }
    }

    func cancelSideStoreFilePassword() {
        pendingSideStoreAccountData = nil
        sideStoreFilePassword = ""
    }

    func applyImportedSideStoreAccount(_ account: SideStoreAccount) {
        viewModel.appleID = account.email
        viewModel.password = account.password ?? ""
        sharedModel.session = nil
        sharedModel.account = nil
        sharedModel.team = nil
        sharedModel.isLogin = false
        viewModel.availableTeams = []
        viewModel.teamSelectionShow = false
        email = account.email
        teamId = ""
        if account.password == nil {
            // SideStore only stores the Apple ID password when "Include Account Password" was ticked.
            importResultInfo = "Imported \(account.email).\nThe file does not contain your Apple ID password, so tap \"Sign in\" and enter it to continue."
        } else {
            importResultInfo = "Imported \(account.email).\nTap \"Sign in\" to continue."
        }
        importResultShow = true
    }

    func selectTeam(_ team: Team) {
        sharedModel.team = team
        sharedModel.isLogin = true
        email = sharedModel.account?.appleID ?? email
        teamId = team.identifier
        viewModel.availableTeams = []
        viewModel.teamSelectionShow = false
    }
    
    func cancelTeamSelection() {
        viewModel.availableTeams = []
        viewModel.teamSelectionShow = false
        sharedModel.session = nil
        sharedModel.account = nil
        sharedModel.team = nil
        sharedModel.isLogin = false
        email = ""
        teamId = ""
    }
    
    func teamTypeDescription(_ type: TeamType) -> String {
        switch type {
        case .free:
            return "Free"
        case .individual:
            return "Individual"
        case .organization:
            return "Organization"
        case .unknown:
            return "Unknown"
        }
    }

}

extension UTType {
    /// The encrypted account backup exported by SideStore. It is not a registered type,
    /// so fall back to a dynamic type built from the file extension.
    static let sideStoreConfiguration = UTType(filenameExtension: "sideconf") ?? .data
}
