//
//  AppIDView.swift
//  GetMoreRam
//
//  Created by s s on 2025/3/15.
//
import SwiftUI

struct AppIDEditView : View {
    @ObservedObject var viewModel : AppIDModel

    @State private var errorShow = false
    @State private var errorInfo = ""
    @State private var isWorking = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                BrandHeader(icon: "memorychip.fill",
                            title: viewModel.bundleID,
                            subtitle: "Increased Memory Limit".loc) {
                    EmptyView()
                }
                .cascadeItem(0)

                Button {
                    Task { await addIncreasedMemoryLimit() }
                } label: {
                    HStack(spacing: 10) {
                        if isWorking {
                            ProgressView().tint(.white)
                        }
                        Text("Add Increased Memory Limit".loc)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isWorking)
                .cascadeItem(1)

                if !viewModel.result.isEmpty {
                    PanelCard {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionTitle(title: "Server Response".loc, systemImage: "terminal.fill")
                            Text(viewModel.result)
                                .font(.system(.footnote, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                }
            }
            .padding(20)
            .animation(.smooth, value: viewModel.result)
        }
        .background(AppBackground())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error".loc, isPresented: $errorShow) {
            Button("OK".loc, action: {})
        } message: {
            Text(errorInfo)
        }
    }

    func addIncreasedMemoryLimit() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await viewModel.addIncreasedMemory()
        } catch {
            errorInfo = error.detailedDescription
            errorShow = true
        }
    }
}


struct AppIDView : View {
    @StateObject var viewModel : AppIDViewModel
    @EnvironmentObject private var sharedModel : SharedModel

    @State private var errorShow = false
    @State private var errorInfo = ""
    @State private var isRefreshing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    BrandHeader(icon: "square.stack.3d.up.fill",
                                title: "App IDs".loc,
                                subtitle: "Increased Memory Limit".loc) {
                        StatusPill(
                            text: "\(viewModel.appIDs.count) " + "App IDs".loc,
                            systemImage: "number",
                            color: Theme.accent2
                        )
                    }
                    .cascadeItem(0)

                    Button {
                        Task { await refreshButtonClicked() }
                    } label: {
                        HStack(spacing: 10) {
                            if isRefreshing {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text("Refresh".loc)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isRefreshing)
                    .cascadeItem(1)

                    if viewModel.appIDs.isEmpty {
                        PanelCard {
                            VStack(spacing: 10) {
                                Image(systemName: "tray")
                                    .font(.system(size: 30, weight: .semibold))
                                    .foregroundStyle(Theme.brand)
                                Text("No App IDs found".loc)
                                    .font(.subheadline.weight(.semibold))
                                Text(sharedModel.isLogin
                                     ? "Tap Refresh to load your App IDs.".loc
                                     : "Sign in from Settings first.".loc)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                        }
                        .cascadeItem(2)
                    } else {
                        PanelCard {
                            VStack(alignment: .leading, spacing: 0) {
                                SectionTitle(title: "App IDs".loc, systemImage: "square.stack.3d.up.fill")
                                    .padding(.bottom, 14)
                                ForEach(Array(viewModel.appIDs.enumerated()), id: \.element) { index, appID in
                                    if index > 0 {
                                        Divider().overlay(Color.white.opacity(0.08))
                                    }
                                    NavigationLink {
                                        AppIDEditView(viewModel: appID)
                                    } label: {
                                        HStack(spacing: 12) {
                                            IconBadge(systemImage: "app.fill")
                                            Text(appID.bundleID)
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(.primary)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
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
                        .cascadeItem(2)
                    }
                }
                .padding(20)
            }
            .background(AppBackground())
            .toolbar(.hidden, for: .navigationBar)
            .alert("Error".loc, isPresented: $errorShow) {
                Button("OK".loc, action: {})
            } message: {
                Text(errorInfo)
            }
        }
    }

    func refreshButtonClicked() async {
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            try await viewModel.fetchAppIDs()
        } catch {
            errorInfo = error.detailedDescription
            errorShow = true
        }
    }
}
