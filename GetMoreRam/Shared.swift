//
//  Shared.swift
//  GetMoreRam
//
//  Created by s s on 2025/3/15.
//
import SwiftUI
import StosSign_API
import StosSign_Auth
import StosSign_Common

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
        
//    private static var enBundle : Bundle? = {
//        let language = "en"
//        let path = Bundle.main.path(forResource:language, ofType: "lproj")
//        let bundle = Bundle(path: path!)
//        return bundle
//    }()
    
    var loc: String {
//        let message = NSLocalizedString(self, comment: "")
//        if message != self {
//            return message
//        }
//
//        if let forcedString = String.enBundle?.localizedString(forKey: self, value: nil, table: nil){
//            return forcedString
//        }else {
            return self
//        }
    }
    
    func localizeWithFormat(_ arguments: CVarArg...) -> String{
        String.localizedStringWithFormat(self.loc, arguments)
    }
    
}

class SharedModel: ObservableObject {
    @Published var isLogin = false
    @AppStorage("AnisetteServer") var anisetteServerURL = "https://ani.jkcoxson.com"
    var session: AppleAPISession?
    var account: Account?
    var team: Team?
    
    init() {
        AnisetteDataHelper.shared.url = URL(string: anisetteServerURL)
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
