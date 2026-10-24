//
//  AuthenticationSettingsView.swift
//  GetMoreRam
//

import SwiftUI

struct AnisetteServersView: View {
    @ObservedObject var settings = AuthenticationSettings.shared

    @State private var newName = ""
    @State private var newAddress = ""
    @State private var isFetching = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var alertShow = false

    var body: some View {
        Form {
            Section {
                ForEach(settings.servers) { server in
                    Button {
                        settings.selectedServerAddress = server.address
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(server.name)
                                    .foregroundStyle(.primary)
                                Text(server.address)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Text(server.libraryLabel)
                                    .font(.caption2)
                                    .foregroundStyle(server.library == .mac ? Color.green : Color.orange)
                            }
                            Spacer()
                            if server.isRemote {
                                Image(systemName: "icloud.and.arrow.down")
                                    .foregroundStyle(.secondary)
                            }
                            if server.address == settings.selectedServerAddress {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                }
                .onDelete { settings.removeServers(at: $0) }
                .onMove { settings.moveServers(from: $0, to: $1) }

                Toggle("Try other servers if it fails", isOn: $settings.fallbackToOtherServers)
            } header: {
                Text("Servers")
            } footer: {
                Text("Tap a server to use it. Swipe to delete. Since October 21, Apple refuses the sign-in token (-80046) for Android-ADI servers: use a macOS-ADI one with the \"macOS current Mac\" headers. With the toggle on, the other macOS-ADI servers are tried when the selected one fails; they share the same anisette identity.")
            }

            Section {
                TextField("Name (optional)", text: $newName)
                    .autocorrectionDisabled()
                TextField(text: $newAddress, prompt: Text(verbatim: "https://ani.example.com")) {
                    Text("Server URL")
                }
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Add and Select") {
                    addServer()
                }
                .disabled(newAddress.trimmingCharacters(in: .whitespaces).isEmpty)
            } header: {
                Text("Add a Server")
            }

            Section {
                TextField(AuthenticationSettings.defaultServerListURL, text: $settings.serverListURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button {
                    Task { await fetchList() }
                } label: {
                    HStack {
                        Text("Fetch Servers from List")
                        if isFetching {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isFetching)
            } header: {
                Text("Server List (JSON)")
            } footer: {
                Text("Accepts SideStore's format {\"servers\": [{\"name\", \"address\"}]}, an array of {\"name\", \"address\"/\"url\"} objects, or an array of URLs.")
            }

            Section {
                Button("Restore Default Servers", role: .destructive) {
                    settings.resetServers()
                }
            }
        }
        .navigationTitle("Anisette Servers")
        .toolbar { EditButton() }
        .alert(alertTitle, isPresented: $alertShow) {
            Button("OK", action: {})
        } message: {
            Text(alertMessage)
        }
    }

    private func addServer() {
        do {
            let server = try settings.addServer(name: newName, address: newAddress)
            settings.selectedServerAddress = server.address
            newName = ""
            newAddress = ""
        } catch {
            showAlert("Error", error.localizedDescription)
        }
    }

    @MainActor
    private func fetchList() async {
        isFetching = true
        defer { isFetching = false }
        do {
            let added = try await settings.fetchRemoteServers()
            showAlert("Server List", added == 0 ? "No new server (the list is up to date)." : "Added \(added) server(s).")
        } catch {
            showAlert("Error", error.localizedDescription)
        }
    }

    private func showAlert(_ title: String, _ message: String) {
        alertTitle = title
        alertMessage = message
        alertShow = true
    }
}

extension AnisetteServer {
    var libraryLabel: String {
        switch library {
        case .mac: return "macOS ADI"
        case .windows: return "Windows ADI"
        case .android: return "Android ADI or unknown (Apple refuses its token)"
        }
    }
}

struct AuthenticationHeadersView: View {
    @ObservedObject var settings = AuthenticationSettings.shared

    var body: some View {
        Form {
            Section {
                Toggle("Use the anisette server's values", isOn: $settings.useServerClientInfo)
            } footer: {
                Text("When on, Client-Info and User-Agent come from the server's /v3/client_info endpoint (often outdated). Leave off to use the values below.")
            }

            Section {
                ForEach(HeaderPreset.all) { preset in
                    Button {
                        settings.apply(preset)
                    } label: {
                        HStack {
                            Text(preset.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            if settings.currentPresetID == preset.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                }
            } header: {
                Text("Presets")
            }
            .disabled(settings.useServerClientInfo)

            Section {
                TextField("X-MMe-Client-Info", text: $settings.clientInfo, axis: .vertical)
                    .font(.system(.footnote, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("Client Info (X-MMe-Client-Info)")
            }
            .disabled(settings.useServerClientInfo)

            Section {
                TextField("User-Agent", text: $settings.userAgent, axis: .vertical)
                    .font(.system(.footnote, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("User-Agent")
            } footer: {
                Text("Used for anisette provisioning, and for sign-in and two-factor requests unless set below.")
            }
            .disabled(settings.useServerClientInfo)

            Section {
                TextField("Same as User-Agent", text: $settings.grandSlamUserAgent, axis: .vertical)
                    .font(.system(.footnote, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("Sign-in User-Agent (GrandSlam)")
            } footer: {
                Text("SideStore's \"SideSign Configuration\" equivalent. Leave empty to use the User-Agent above. Changes apply on the next sign-in. If Apple keeps refusing, try another preset and \"Clean Up Keychain\".")
            }
        }
        .navigationTitle("Authentication Headers")
    }
}
