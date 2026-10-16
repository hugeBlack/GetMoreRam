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
    @State private var customServerText = ""
    @State private var showCustomServerAlert = false

    private var selectedServerIsCustom: Bool {
        !presetAnisetteServers.contains { !$0.isCustom && $0.url == sharedModel.anisetteServerURL }
    }

    private var selectedServerName: String {
        if let match = presetAnisetteServers.first(where: { !$0.isCustom && $0.url == sharedModel.anisetteServerURL }) {
            return match.name
        }
        return "Custom".loc
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header.cascadeItem(0)
                    accountCard.cascadeItem(1)
                    anisetteCard.cascadeItem(2)
                    troubleshootingCard.cascadeItem(3)
                    creditsCard.cascadeItem(4)
                }
                .padding(20)
            }
            .background(AppBackground())
            .toolbar(.hidden, for: .navigationBar)
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

    // MARK: Sections

    private var header: some View {
        BrandHeader(icon: "memorychip.fill",
                    title: "ram 6itoon",
                    subtitle: "Increased Memory Limit".loc) {
            StatusPill(
                text: sharedModel.isLogin ? "Signed in".loc : "Not signed in".loc,
                systemImage: sharedModel.isLogin ? "checkmark.seal.fill" : "person.crop.circle.badge.xmark",
                color: sharedModel.isLogin ? .green : .orange
            )
        }
    }

    private var accountCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitle(title: "Account".loc, systemImage: "person.crop.circle.fill")

                if sharedModel.isLogin {
                    infoRow(systemImage: "envelope.fill", title: "Email".loc, value: email)
                    infoRow(systemImage: "person.3.fill", title: "Team ID".loc, value: teamId)
                } else {
                    Button {
                        viewModel.loginModalShow = true
                    } label: {
                        Label("Sign in".loc, systemImage: "person.crop.circle.badge.plus")
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Button {
                        isImportingSideStoreAccount = true
                    } label: {
                        Label("Import SideStore Account".loc, systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
        }
    }

    private func infoRow(systemImage: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            IconBadge(systemImage: systemImage)
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer(minLength: 8)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private var anisetteCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(title: "Anisette".loc, systemImage: "server.rack")

                Menu {
                    ForEach(presetAnisetteServers) { server in
                        Button {
                            if server.isCustom {
                                customServerText = sharedModel.anisetteServerURL
                                showCustomServerAlert = true
                            } else {
                                sharedModel.anisettePresetId = server.id
                                sharedModel.applyAnisetteServer(server.url)
                            }
                        } label: {
                            if server.isCustom ? selectedServerIsCustom : (server.url == sharedModel.anisetteServerURL) {
                                Label(server.name, systemImage: "checkmark")
                            } else {
                                Text(server.name)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text("Anisette Server".loc)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Spacer(minLength: 8)
                        Text(selectedServerName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .fieldBackground()
                }

                if !sharedModel.anisetteServerURL.isEmpty {
                    Text(sharedModel.anisetteServerURL)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }

                Text("Recommended: jkcoxson (Windows ADI) or StikStore (Windows ADI)".loc)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var troubleshootingCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(title: "Troubleshooting".loc, systemImage: "wrench.and.screwdriver.fill")

                Button(role: .destructive) {
                    cleanUp()
                } label: {
                    Label("Clean Up Keychain".loc, systemImage: "trash")
                }
                .buttonStyle(SecondaryButtonStyle(tint: .red))

                Text("If something went wrong during signing in, clean up the keychain, reopen the app and try again.".loc)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("If you use SideStore and are already signed in, you can also export your SideStore account from its settings and import it here.".loc)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var creditsCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitle(title: "Credits".loc, systemImage: "heart.fill")
                LinkRow(systemImage: "memorychip.fill",
                        title: "GetMoreRam",
                        detail: "Original project by hugeBlack".loc,
                        url: "https://github.com/hugeBlack/GetMoreRam")
                LinkRow(systemImage: "paintbrush.fill",
                        title: "SideInstaller",
                        detail: "Design by FrizzleM".loc,
                        url: "https://github.com/FrizzleM/SideInstaller")
                LinkRow(systemImage: "chevron.left.forwardslash.chevron.right",
                        title: "ram-6itoon",
                        detail: "Source code".loc,
                        url: "https://github.com/6itoon/ram-6itoon")
            }
        }
    }

    // MARK: Sheets

    var loginModal: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    PanelCard {
                        VStack(alignment: .leading, spacing: 16) {
                            SectionTitle(title: "Sign in".loc, systemImage: "person.crop.circle.fill")

                            fieldLabel("Apple ID".loc)
                            TextField("name@example.com", text: $viewModel.appleID)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                                .disabled(viewModel.isLoginInProgress)
                                .fieldBackground()

                            fieldLabel("Password".loc)
                            SecureField("••••••••", text: $viewModel.password)
                                .disabled(viewModel.isLoginInProgress)
                                .fieldBackground()

                            if viewModel.needVerificationCode {
                                fieldLabel("Verification Code".loc)
                                TextField("000000", text: $viewModel.verificationCode)
                                    .keyboardType(.numberPad)
                                    .disabled(viewModel.isVerificationCodeSubmitting)
                                    .fieldBackground()
                            }
                        }
                    }

                    Button {
                        Task{ await loginButtonClicked() }
                    } label: {
                        HStack(spacing: 10) {
                            if viewModel.isLoginInProgress || viewModel.isVerificationCodeSubmitting {
                                ProgressView().tint(.white)
                            }
                            Text("Continue".loc)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(continueButtonDisabled)

                    if !viewModel.logs.isEmpty {
                        PanelCard {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionTitle(title: "Debugging".loc, systemImage: "terminal.fill")
                                Text(viewModel.logs)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(AppBackground())
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
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
        .onAppear {
            if let email = Keychain.shared.appleIDEmailAddress, let password = Keychain.shared.appleIDPassword {
                viewModel.appleID = email
                viewModel.password = password
            }
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    var teamSelectionView: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    PanelCard {
                        VStack(alignment: .leading, spacing: 0) {
                            SectionTitle(title: "Choose Team".loc, systemImage: "person.3.fill")
                                .padding(.bottom, 14)
                            ForEach(Array(viewModel.availableTeams.enumerated()), id: \.offset) { index, team in
                                if index > 0 {
                                    Divider().overlay(Color.white.opacity(0.08))
                                }
                                Button {
                                    selectTeam(team)
                                } label: {
                                    HStack(spacing: 12) {
                                        IconBadge(systemImage: "person.3.fill")
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(team.name)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(.primary)
                                            Text("\(team.identifier) · \(teamTypeDescription(team.type))")
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer(minLength: 8)
                                        Image(systemName: "chevron.forward")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(.vertical, 10)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(AppBackground())
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
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
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
