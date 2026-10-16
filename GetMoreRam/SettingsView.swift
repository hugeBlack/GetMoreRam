//
//  SettingsView.swift
//  ram 6itoon
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
    
    @State private var errorShow = false
    @State private var errorInfo = ""
    @State private var importResultShow = false
    @State private var importResultInfo = ""
    @State private var isImportingSideStoreAccount = false
    @State private var showAnisettePicker = false
    @State private var customServerText = ""
    @State private var showCustomServerAlert = false

    private var selectedServerName: String {
        if let match = presetAnisetteServers.first(where: { !$0.isCustom && $0.url == sharedModel.anisetteServerURL }) {
            return match.name
        }
        return "Custom".loc
    }

    var body: some View {
        NavigationView {
            List {
                // Header
                Section {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [AppTheme.accent, AppTheme.accentSecondary],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 56, height: 56)
                            Image(systemName: "memorychip.fill")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ram 6itoon")
                                .font(.title2.bold())
                            Text("Increased Memory Limit".loc)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 6)
                    .listRowBackground(Color.clear)
                }
                
                // Account
                Section {
                    if sharedModel.isLogin {
                        HStack {
                            Label("Email".loc, systemImage: "envelope.fill")
                            Spacer()
                            Text(email)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        HStack {
                            Label("Team ID".loc, systemImage: "person.3.fill")
                            Spacer()
                            Text(teamId)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    } else {
                        Button {
                            viewModel.loginModalShow = true
                        } label: {
                            Label("Sign in".loc, systemImage: "person.crop.circle.badge.plus")
                                .font(.body.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accent)
                        .listRowBackground(Color.clear)
                        
                        Button {
                            isImportingSideStoreAccount = true
                        } label: {
                            Label("Import SideStore Account".loc, systemImage: "square.and.arrow.down")
                        }
                    }
                } header: {
                    Text("Account".loc)
                }
                
                // Anisette
                Section {
                    Button {
                        showAnisettePicker = true
                    } label: {
                        HStack {
                            Label("Anisette Server".loc, systemImage: "server.rack")
                            Spacer()
                            Text(selectedServerName)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)
                    
                    if !sharedModel.anisetteServerURL.isEmpty {
                        Text(sharedModel.anisetteServerURL)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                } header: {
                    Text("Anisette".loc)
                } footer: {
                    Text("Recommended: jkcoxson (Windows ADI) or StikStore (Windows ADI)".loc)
                }
                
                // Actions
                Section {
                    Button(role: .destructive) {
                        cleanUp()
                    } label: {
                        Label("Clean Up Keychain".loc, systemImage: "trash")
                    }
                } footer: {
                    Text("If something went wrong during signing in, please try to clean up the keychain, repoen the app and try again. \n \nIf you use SideStore and are already signed in, please also try exporting SideStore Account from SideStore settings and import it here to sign in.".loc)
                }
            }
            .navigationTitle("Settings".loc)
            .navigationBarTitleDisplayMode(.large)
        }
        .navigationViewStyle(.stack)
        .confirmationDialog("Anisette Server".loc, isPresented: $showAnisettePicker, titleVisibility: .visible) {
            ForEach(presetAnisetteServers) { server in
                Button(server.name) {
                    if server.isCustom {
                        customServerText = sharedModel.anisetteServerURL
                        showCustomServerAlert = true
                    } else {
                        sharedModel.anisettePresetId = server.id
                        sharedModel.applyAnisetteServer(server.url)
                    }
                }
            }
            Button("Cancel".loc, role: .cancel) {}
        }
        .alert("Custom Server".loc, isPresented: $showCustomServerAlert) {
            TextField("https://…", text: $customServerText)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
            Button("OK".loc) {
                let url = customServerText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !url.isEmpty else { return }
                sharedModel.anisettePresetId = "custom"
                sharedModel.applyAnisetteServer(url)
            }
            Button("Cancel".loc, role: .cancel) {}
        } message: {
            Text("Enter a full Anisette V3 server URL".loc)
        }
        .alert("Error".loc, isPresented: $errorShow){
            Button("OK".loc, action: {})
        } message: {
            Text(errorInfo)
        }
        .alert("SideStore Account".loc, isPresented: $importResultShow){
            Button("OK".loc, action: {})
        } message: {
            Text(importResultInfo)
        }
        .fileImporter(
            isPresented: $isImportingSideStoreAccount,
            allowedContentTypes: [.json],
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
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .disabled(viewModel.isLoginInProgress)
                } header: {
                    Text("Apple ID".loc)
                }
                Section {
                    SecureField("", text: $viewModel.password)
                        .disabled(viewModel.isLoginInProgress)
                } header: {
                    Text("Password".loc)
                }
                if viewModel.needVerificationCode {
                    Section {
                        TextField("", text: $viewModel.verificationCode)
                            .disabled(viewModel.isVerificationCodeSubmitting)
                    } header: {
                        Text("Verification Code".loc)
                    }
                }
                Section {
                    Button("Continue".loc) {
                        Task{ await loginButtonClicked() }
                    }
                    .disabled(continueButtonDisabled)
                    .tint(AppTheme.accent)
                }
                
                Section {
                    Text(viewModel.logs)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Debugging".loc)
                }
            }
            .navigationTitle("Sign in".loc)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel".loc, role: .cancel) {
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
            .navigationTitle("Choose Team".loc)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel".loc, role: .cancel) {
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
            let account = try SideStoreAccountImporter.importAccount(from: data)
            
            viewModel.appleID = account.email
            viewModel.password = account.password
            sharedModel.session = nil
            sharedModel.account = nil
            sharedModel.team = nil
            sharedModel.isLogin = false
            viewModel.availableTeams = []
            viewModel.teamSelectionShow = false
            email = account.email
            teamId = ""
            importResultInfo = "Imported \(account.email).\nTap \"Sign In\" to continue."
            importResultShow = true
        } catch {
            errorInfo = error.detailedDescription
            errorShow = true
        }
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
            return "Free".loc
        case .individual:
            return "Individual".loc
        case .organization:
            return "Organization".loc
        case .unknown:
            return "Unknown".loc
        }
    }
}
