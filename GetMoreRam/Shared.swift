//
//  Shared.swift
//  GetMoreRam
//
//  Created by s s on 2025/3/15.
//
import SwiftUI
import SideSign
import AnisetteKit

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
    @AppStorage("AnisetteServer") var anisetteServerURL = "https://new.ani.sidestore.io"
    @AppStorage("AnisetteClientInfo") var anisetteClientInfo = "<MacBookPro13,3> <Mac OS X;10.12.6;16G29> <com.apple.AuthKit/1 (com.apple.akd/1.0)>"
    @AppStorage("AnisetteUA") var anisetteUA = "akd/1.0 CFNetwork/811.5.4 Darwin/16.7.0"
    var anisetteHeader: AnisetteRequestHeaders?
    var session: Session?
    var account: Account?
    var team: Team?
}

class DataManager {
    static let shared = DataManager()
    let model = SharedModel()
    
    public static func fetchAnisetteData(logger: (((String) async->Void))? = nil ) async throws -> AnisetteData {
        let server = DataManager.shared.model.anisetteServerURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: server), url.host != nil,
              let scheme = url.scheme?.lowercased(), ["https", "http"].contains(scheme) else {
            throw AnisetteError.invalidURL
        }
        await logger?("Anisette URL: \(url.absoluteString)\n")

        let keychain = Keychain.shared
        let savedIdentifier = keychain.anisetteDeviceIdentifier
        let identifier = savedIdentifier ?? UUID()
        let savedBlob = savedIdentifier == nil ? nil : keychain.adiPb.flatMap { Data(base64Encoded: $0) }
        let manager = AnisetteDataManager(mode: .remote(server: url))

        let result: (data: AnisetteData, newAdiBlob: Data?)
        let headers = AnisetteRequestHeaders().with {
            $0.clientInfo = DataManager.shared.model.anisetteClientInfo
            $0.userAgent = DataManager.shared.model.anisetteUA
        }
        DataManager.shared.model.anisetteHeader = headers
        do {
            result = try await manager.fetchAnisetteData(identifier: identifier, existingAdiBlob: savedBlob, headers: headers)
            
        } catch SideSign.AnisetteError.badServerResponse(_, let payload)
            where savedBlob != nil && payload.contains("-45061") && !Task.isCancelled {
            await logger?("Anisette provisioning expired. Retrying…\n")
            keychain.adiPb = nil
            result = try await manager.fetchAnisetteData(identifier: identifier, headers: headers)
        }

        guard !Task.isCancelled else { throw CancellationError() }
        if let newBlob = result.newAdiBlob {
            keychain.identifier = withUnsafeBytes(of: identifier.uuid) { Data($0).base64EncodedString() }
            keychain.adiPb = newBlob.base64EncodedString()
        }
        await logger?("Successfully fetched Anisette data\n")
        return result.data
    }
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
