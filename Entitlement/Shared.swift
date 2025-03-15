//
//  Shared.swift
//  Entitlement
//
//  Created by s s on 2025/3/15.
//
import SwiftUI
import AltSign

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

extension URLSession {
    public func asyncRequest(url: URL) async throws -> (Data?, URLResponse?) {
        return try await asyncRequest(request: URLRequest(url: url))
    }
    
    public func asyncRequest(request: URLRequest) async throws -> (Data?, URLResponse?) {
        var ansData: Data?
        var ansResponse: URLResponse?
        var ansError: Error?
        await withCheckedContinuation { c in
            let task = self.dataTask(with: request) { data, response, error in
                ansError = error
                ansResponse = response
                ansData = data
                c.resume()
            }
            task.resume()
        }
        if let ansError {
            throw ansError
        }
        return (ansData, ansResponse)
    }
}


class SharedModel: ObservableObject {
    @Published var isLogin = false
    @AppStorage("AnisetteServer") var anisetteServerURL = "https://ani.sidestore.io"
    var session: ALTAppleAPISession?
    var account: ALTAccount?
    var team: ALTTeam?
    
    init() {
        AnisetteDataHelper.shared.url = URL(string: anisetteServerURL)
    }
}

class DataManager {
    static let shared = DataManager()
    let model = SharedModel()
}
