//
//  Shared.swift
//  ram 6itoon
//

import SwiftUI
import StosSign_API
import StosSign_Auth
import StosSign_Common

struct AnisetteServerOption: Identifiable, Hashable {
    let id: String
    let name: String
    let url: String
    let isCustom: Bool
    
    init(name: String, url: String, isCustom: Bool = false) {
        self.id = isCustom ? "custom" : url
        self.name = name
        self.url = url
        self.isCustom = isCustom
    }
}

let presetAnisetteServers: [AnisetteServerOption] = [
    .init(name: "jkcoxson (Windows ADI)", url: "https://ani.jkcoxson.com"),
    .init(name: "jkcoxson (Mac ADI)", url: "https://mac-ani.jkcoxson.com"),
    .init(name: "StikStore (Windows ADI)", url: "https://ani2.stikstore.app"),
    .init(name: "SideStore", url: "https://ani.sidestore.io"),
    .init(name: "SideStore (.app)", url: "https://ani.sidestore.app"),
    .init(name: "nythepegasus", url: "https://ani.npeg.us"),
    .init(name: "neoarz", url: "https://ani.neoarz.com"),
    .init(name: "Custom…", url: "", isCustom: true),
]

class AlertHelper<T> : ObservableObject {
    @Published var show = false
    private var result : T?
    private var c : CheckedContinuation<Void, Never>? = nil
    
    func open() async -> T? {
        await withCheckedContinuation { c in
            self.c = c
            Task { await MainActor.run {
                self.show = true
            }}
        }
        return self.result
    }
    
    func close(result: T?) {
        if let c {
            self.result = result
            c.resume()
            self.c = nil
        }
        DispatchQueue.main.async {
            self.show = false
        }
    }
}
typealias YesNoHelper = AlertHelper<Bool>

class InputHelper : AlertHelper<String> {
    @Published var initVal = ""
    
    func open(initVal: String) async -> String? {
        self.initVal = initVal
        return await super.open()
    }
    
    override func open() async -> String? {
        self.initVal = ""
        return await super.open()
    }
}

extension String: @retroactive Error {}
extension String: @retroactive LocalizedError {
    public var errorDescription: String? { return self }
    
    var loc: String {
        let message = NSLocalizedString(self, comment: "")
        if message != self {
            return message
        }
        return self
    }
    
    func localizeWithFormat(_ arguments: CVarArg...) -> String{
        String.localizedStringWithFormat(self.loc, arguments)
    }
}

class SharedModel: ObservableObject {
    @Published var isLogin = false
    @AppStorage("AnisetteServer") var anisetteServerURL = "https://ani.jkcoxson.com"
    @AppStorage("AnisetteServerPresetId") var anisettePresetId = "https://ani.jkcoxson.com"
    var session: AppleAPISession?
    var account: Account?
    var team: Team?
    
    init() {
        AnisetteDataHelper.shared.url = URL(string: anisetteServerURL)
    }
    
    func applyAnisetteServer(_ url: String) {
        anisetteServerURL = url
        AnisetteDataHelper.shared.url = URL(string: url)
        AnisetteDataHelper.shared.resetClientInfo()
    }
}

class DataManager {
    static let shared = DataManager()
    let model = SharedModel()
}

extension Error {
    var detailedDescription: String {
        let localizedError = self as? LocalizedError
        var lines: [String] = []
        
        if let description = localizedError?.errorDescription, !description.isEmpty {
            lines.append(description)
        } else {
            let nsError = self as NSError
            lines.append(nsError.localizedDescription)
        }
        
        if let failureReason = localizedError?.failureReason, !failureReason.isEmpty {
            lines.append("Reason: \(failureReason)")
        }
        
        if let recoverySuggestion = localizedError?.recoverySuggestion, !recoverySuggestion.isEmpty {
            lines.append("Suggestion: \(recoverySuggestion)")
        }
        
        let nsError = self as NSError
        if nsError.domain != NSCocoaErrorDomain || nsError.code != 0 {
            lines.append("Domain: \(nsError.domain)")
            lines.append("Code: \(nsError.code)")
        }
        
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            lines.append("Underlying: \(underlying.detailedDescription)")
        }
        
        return lines.joined(separator: "\n")
    }
}
