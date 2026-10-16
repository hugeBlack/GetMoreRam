//
//  ContentView.swift
//  ram 6itoon
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            AppIDView(viewModel: AppIDViewModel())
                .tabItem {
                    Label("App IDs".loc, systemImage: "square.stack.3d.up.fill")
                }
            SettingsView(viewModel: LoginViewModel())
                .tabItem {
                    Label("Settings".loc, systemImage: "gearshape.fill")
                }
        }
        .tint(AppTheme.accent)
        .environmentObject(DataManager.shared.model)
    }
}

#Preview {
    ContentView()
}
