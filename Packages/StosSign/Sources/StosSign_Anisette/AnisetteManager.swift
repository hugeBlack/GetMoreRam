//
//  AnisetteManager.swift
//  StosSign
//
//  Created by Stossy11 on 13/8/2026.
//

import Foundation
import CryptoSwift
import StosSign_Common
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct AnisetteResponse {
    var anisette: AnisetteData
    var adiPb: String?
    var localIdentifier: String?
}

public final class AnisetteManager {
    private var webSocketTask: URLSessionWebSocketTask?
    private var session = URLSession(configuration: .default)
    
    private var url: URL?
    private var startProvisioningURL: URL?
    private var endProvisioningURL: URL?
    
    private var clientInfo: String?
    private var userAgent: String?
    
    private var mdLu: String?
    private var deviceId: String?
    
    private var menuAnisetteURL: String?
    
    private var localIdentifier: String?
    private var localAdiPb: String?
    
    private var provisioningContinuation: CheckedContinuation<AnisetteData, Error>?
    
    private var isLoggingEnabled = true
    
    public var isLoggingIn: Bool = false
    
    
    public func clearLocalData() {
        localIdentifier = nil
        localAdiPb = nil
        // logger.info("Cleared local anisette data")
    }
    
    public func hasLocalData() -> Bool {
        return localIdentifier != nil && localAdiPb != nil
    }
    
    public func setClientInfo(clientInfo: String?, userAgent: String?) {
        self.clientInfo = clientInfo
        self.userAgent = userAgent
    }
    
    public func getAnisetteData(anisetteURL: URL, refresh: Bool = false, identifier: String? = nil, adiPb: String? = nil) async throws -> AnisetteResponse {
        url = anisetteURL
        
        self.localIdentifier = identifier ?? self.localIdentifier
        self.localAdiPb = adiPb ?? self.localAdiPb
        
        guard url != nil else {
            throw AnisetteError.noServerFound
        }
        
        if let localIdentifier = localIdentifier,
           let localAdiPb = localAdiPb,
           !refresh {
            let ani = try await fetchAnisetteV3(localIdentifier, localAdiPb)
            return .init(anisette: ani, adiPb: localAdiPb, localIdentifier: localIdentifier)
        }
        
        let ani = try await provision()
        return .init(anisette: ani, adiPb: localAdiPb, localIdentifier: localIdentifier)
    }
    
    public init() {}
    
    private func provision() async throws -> AnisetteData {
        try await fetchClientInfo()
        // logger.info("Getting provisioning URLs")
        
        let request = buildAppleRequest(url: URL(string: "https://gsa.apple.com/grandslam/GsService2/lookup")!)
        let (data, _) = try await session.data(for: request)
        
        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: [String: Any]],
              let startProvisioningString = plist["urls"]?["midStartProvisioning"] as? String,
              let startProvisioningURL = URL(string: startProvisioningString),
              let endProvisioningString = plist["urls"]?["midFinishProvisioning"] as? String,
              let endProvisioningURL = URL(string: endProvisioningString) else {
            // logger.error("Apple didn't give valid URLs! Response: \(String(data: data, encoding: .utf8) ?? "not utf8")")
            throw AnisetteError.invalidProvisioningURLs
        }
        
        self.startProvisioningURL = startProvisioningURL
        self.endProvisioningURL = endProvisioningURL
        // logger.debug("startProvisioningURL: \(startProvisioningURL.absoluteString)")
        // logger.debug("endProvisioningURL: \(endProvisioningURL.absoluteString)")
        // logger.info("Starting a provisioning session")
        
        return try await startProvisioningSession()
    }
    
    private func startProvisioningSession() async throws -> AnisetteData {
        guard let url = url else { throw AnisetteError.noServerFound }
        
        let url1 = url.appendingPathComponent("v3").appendingPathComponent("provisioning_session")
        let url2 = url1.absoluteString.replacingOccurrences(of: "https://", with: "wss://")
        let provisioningSessionURL = URL(string: url2)!
        
        
        let task = session.webSocketTask(with: provisioningSessionURL)
        webSocketTask = task
        
        task.resume()
        
        return try await withCheckedThrowingContinuation { continuation in
            provisioningContinuation = continuation
            receiveMessage()
        }
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleWebSocketMessage(text)
                case .data(let data):
                    if let string = String(data: data, encoding: .utf8) {
                        self.handleWebSocketMessage(string)
                    }
                    break
                @unknown default:
                    self.failProvisioning(with: AnisetteError.unknownMessageType)
                }
                
                self.receiveMessage()
                
            case .failure(let error):
                // self.// logger.critical("WebSocket error: \(error.localizedDescription)")
                self.failProvisioning(with: error)
            }
        }
    }
    private func handleWebSocketMessage(_ messageText: String) {
        guard let data = messageText.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? String else {
            failProvisioning(with: AnisetteError.invalidServerResponse)
            return
        }
        
        // logger.info("Received result: \(result)")
        
        switch result {
        case "GiveIdentifier":
            // logger.info("Giving identifier")
            
            guard let identifier = localIdentifier else {
                failProvisioning(with: AnisetteError.missingIdentifier)
                return
            }
            
            send(json: ["identifier": identifier])
            
        case "GiveStartProvisioningData":
            handleStartProvisioningData()
            
        case "GiveEndProvisioningData":
            guard let cpim = json["cpim"] as? String else {
                failProvisioning(with: AnisetteError.missingCpim)
                return
            }
            handleEndProvisioningData(cpim: cpim)
            
        case "ProvisioningSuccess":
            // logger.info("Provisioning succeeded!")
            guard let adiPb = json["adi_pb"] as? String else {
                failProvisioning(with: AnisetteError.missingAdiPb)
                return
            }
            
            localAdiPb = adiPb
            // logger.info("Stored adi_pb locally")
            
            closeWebSocket()
            
            Task {
                do {
                    let identifier = localIdentifier
                    
                    guard let identifier = identifier else {
                        failProvisioning(with: AnisetteError.missingIdentifier)
                        return
                    }
                    
                    let anisetteData = try await fetchAnisetteV3(identifier, adiPb)
                    provisioningContinuation?.resume(returning: anisetteData)
                    provisioningContinuation = nil
                } catch {
                    failProvisioning(with: error)
                }
            }
            
        default:
            if result.contains("Error") || result.contains("Invalid") ||
               result == "ClosingPerRequest" || result == "Timeout" || result == "TextOnly" {
                let message = (json["message"] as? String) ?? ""
                failProvisioning(with: AnisetteError.serverError(result + message))
            }
        }
    }
    
    private func handleStartProvisioningData() {
        // logger.info("Getting start provisioning data")
        guard let startProvisioningURL = startProvisioningURL else {
            failProvisioning(with: AnisetteError.missingProvisioningURL)
            return
        }
        
        let body: [String: Any] = [
            "Header": [String: Any](),
            "Request": [String: Any]()
        ]
        
        var request = buildAppleRequest(url: startProvisioningURL)
        request.httpMethod = "POST"
        
        do {
            request.httpBody = try PropertyListSerialization.data(fromPropertyList: body, format: .xml, options: 0)
        } catch {
            failProvisioning(with: error)
            return
        }
        
        Task {
            do {
                let (data, _) = try await session.data(for: request)
                guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: [String: Any]],
                      let spim = plist["Response"]?["spim"] as? String else {
                    // logger.error("Apple didn't give valid start provisioning data! Response: \(String(data: data, encoding: .utf8) ?? "not utf8")")
                    failProvisioning(with: AnisetteError.invalidStartProvisioningData)
                    return
                }
                
                // logger.info("Giving start provisioning data")
                send(json: ["spim": spim])
            } catch {
                failProvisioning(with: error)
            }
        }
    }
    
    private func handleEndProvisioningData(cpim: String) {
        // logger.info("Getting end provisioning data")
        guard let endProvisioningURL = endProvisioningURL else {
            failProvisioning(with: AnisetteError.missingProvisioningURL)
            return
        }
        
        let body: [String: Any] = [
            "Header": [String: Any](),
            "Request": ["cpim": cpim]
        ]
        
        var request = buildAppleRequest(url: endProvisioningURL)
        request.httpMethod = "POST"
        
        do {
            request.httpBody = try PropertyListSerialization.data(fromPropertyList: body, format: .xml, options: 0)
        } catch {
            failProvisioning(with: error)
            return
        }
        
        Task {
            do {
                let (data, _) = try await session.data(for: request)
                guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: [String: Any]],
                      let ptm = plist["Response"]?["ptm"] as? String,
                      let tk = plist["Response"]?["tk"] as? String else {
                    // logger.error("Apple didn't give valid end provisioning data! Response: \(String(data: data, encoding: .utf8) ?? "not utf8")")
                    failProvisioning(with: AnisetteError.invalidEndProvisioningData)
                    return
                }
                
                // logger.info("Giving end provisioning data")
                send(json: ["ptm": ptm, "tk": tk])
            } catch {
                failProvisioning(with: error)
            }
        }
    }
    
    private func send(json: [String: String]) {
        do {
            let data = try JSONSerialization.data(withJSONObject: json)
            if let message = String(data: data, encoding: .utf8) {
                webSocketTask?.send(.string(message)) { [weak self] error in
                    if let error = error {
                        // self?.logger.error("Failed to send message: \(error.localizedDescription)")
                        self?.failProvisioning(with: error)
                    }
                }
            }
        } catch {
            // logger.error("Failed to serialize JSON: \(error.localizedDescription)")
            failProvisioning(with: error)
        }
    }
    
    private func failProvisioning(with error: Error) {
        // logger.error("Provisioning failed: \(error.localizedDescription)")
        closeWebSocket()
        provisioningContinuation?.resume(throwing: error)
        provisioningContinuation = nil
    }
    
    private func closeWebSocket() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
    }
    
    private func fetchClientInfo() async throws {
        if clientInfo != nil && userAgent != nil && mdLu != nil &&
           deviceId != nil && localIdentifier != nil {
            // logger.info("Skipping client_info fetch since all properties are available")
            return
        }
        
        // logger.info("Trying to get client_info")
        guard let url = url else { throw AnisetteError.noServerFound }
        
        let clientInfoURL = url.appendingPathComponent("v3").appendingPathComponent("client_info")
        let (data, _) = try await session.data(from: clientInfoURL)
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let clientInfo = json["client_info"] else {
            throw AnisetteError.invalidClientInfo
        }
        
        // logger.info("Server is V3")
        self.clientInfo = self.clientInfo ?? clientInfo
        
        guard let userAgent = json["user_agent"] else {
            throw AnisetteError.missingUserAgent
        }
        
        self.userAgent = self.userAgent ?? userAgent
        // logger.debug("Client-Info: \(clientInfo)")
        // logger.debug("User-Agent: \(userAgent)")
        
        // Check if identifier exists in account or local storage
        if localIdentifier == nil {
            // logger.info("Generating identifier")
            var bytes = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
            
            if status != errSecSuccess {
                // logger.error("ERROR GENERATING IDENTIFIER!!! \(status)")
                throw AnisetteError.identifierGenerationFailed
            }
            
            print("Identifier \(bytes)")
            
            let identifier = Data(bytes).base64EncodedString()
            
            // Store to local variable
            localIdentifier = identifier
            // logger.info("Stored identifier locally")
        }
        
        guard let identifier = localIdentifier,
              let identifierData = Data(base64Encoded: identifier) else {
            throw AnisetteError.missingIdentifier
        }
        
        mdLu = identifierData.sha256().hexEncodedString()
        // logger.debug("X-Apple-I-MD-LU: \(self.mdLu!)")
        
        let uuid = UUID(uuid: identifierData.withUnsafeBytes { $0.load(as: uuid_t.self) })
        deviceId = uuid.uuidString.uppercased()
        // logger.debug("X-Mme-Device-Id: \(self.deviceId!)")
    }
    
    private func fetchAnisetteV3(_ identifier: String, _ adiPb: String) async throws -> AnisetteData {
        try await fetchClientInfo()
        // logger.info("Fetching anisette V3")
        
        guard let url = url else { throw AnisetteError.noServerFound }
        
        var request = URLRequest(url: url.appendingPathComponent("v3").appendingPathComponent("get_headers"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = ["identifier": identifier, "adi_pb": adiPb]
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await session.data(for: request)
        return try await extractAnisetteData(data, response as? HTTPURLResponse, v3: true)
    }
    
    private func buildAppleRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        
        if let clientInfo = clientInfo {
            request.setValue(clientInfo, forHTTPHeaderField: "X-Mme-Client-Info")
        }
        
        if let userAgent = userAgent {
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        }
        
        request.setValue("text/x-xml-plist", forHTTPHeaderField: "Content-Type")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        
        if let mdLu = mdLu {
            request.setValue(mdLu, forHTTPHeaderField: "X-Apple-I-MD-LU")
        }
        
        if let deviceId = deviceId {
            request.setValue(deviceId, forHTTPHeaderField: "X-Mme-Device-Id")
        }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        let dateString = formatter.string(from: Date())
        
        request.setValue(dateString, forHTTPHeaderField: "X-Apple-I-Client-Time")
        request.setValue(Locale.current.identifier, forHTTPHeaderField: "X-Apple-Locale")
        request.setValue(TimeZone.current.abbreviation(), forHTTPHeaderField: "X-Apple-I-TimeZone")
        
        return request
    }
    
    private func extractAnisetteData(_ data: Data, _ response: HTTPURLResponse?, v3: Bool) async throws -> AnisetteData {
        guard var json = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            throw AnisetteError.invalidAnisetteFormat
        }
        
        if json["X-MMe-Client-Info"] != nil {
            json["X-MMe-Client-Info"] = "<iMac18,3> <macOS;27.0;26A5378j> <com.apple.AuthKit/1 (com.apple.dt.Xcode/25183.54.10)>"
        }
        
        if v3 && json["result"] == "GetHeadersError" {
            let message = json["message"] ?? "Unknown error"
            // logger.error("Error getting V3 headers: \(message)")
            
            if message.contains("-45061") {
                // logger.notice("Error message contains -45061 (not provisioned), resetting adi.pb and retrying")
                
                // Clear both account and local storage
                localAdiPb = nil
                
                return try await provision()
            } else {
                throw AnisetteError.headerError(message)
            }
        }
        
        // Build the anisette data dictionary
        var formattedJSON: [String: String] = ["deviceSerialNumber": "0"]
        
        if let machineID = json["X-Apple-I-MD-M"] { formattedJSON["machineID"] = machineID }
        if let oneTimePassword = json["X-Apple-I-MD"] { formattedJSON["oneTimePassword"] = oneTimePassword }
        if let routingInfo = json["X-Apple-I-MD-RINFO"] { formattedJSON["routingInfo"] = routingInfo }
        
        if v3 {
            guard let clientInfo = self.clientInfo,
                  let mdLu = self.mdLu,
                  let deviceId = self.deviceId else {
                throw AnisetteError.missingClientInfo
            }
            
            formattedJSON["deviceDescription"] = clientInfo
            formattedJSON["localUserID"] = mdLu
            formattedJSON["deviceUniqueIdentifier"] = deviceId
            
            // Generate date stuff on client
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.timeZone = TimeZone.current
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
            let dateString = formatter.string(from: Date())
            
            formattedJSON["date"] = dateString
            formattedJSON["locale"] = Locale.current.identifier
            formattedJSON["timeZone"] = TimeZone.current.abbreviation()
        } else {
            if let deviceDescription = json["X-MMe-Client-Info"] { formattedJSON["deviceDescription"] = deviceDescription }
            if let localUserID = json["X-Apple-I-MD-LU"] { formattedJSON["localUserID"] = localUserID }
            if let deviceUniqueIdentifier = json["X-Mme-Device-Id"] { formattedJSON["deviceUniqueIdentifier"] = deviceUniqueIdentifier }
            
            if let date = json["X-Apple-I-Client-Time"] { formattedJSON["date"] = date }
            if let locale = json["X-Apple-Locale"] { formattedJSON["locale"] = locale }
            if let timeZone = json["X-Apple-I-TimeZone"] { formattedJSON["timeZone"] = timeZone }
        }
        
        if let response = response,
           let version = response.value(forHTTPHeaderField: "Implementation-Version") {
            // logger.debug("Implementation-Version: \(version)")
        } else {
            // logger.debug("No Implementation-Version header")
        }
        
        // logger.debug("Anisette used: \(formattedJSON)")
        // logger.debug("Original JSON: \(json)")
        
        do {
            let jsonData = try JSONEncoder().encode(formattedJSON)
            let anisette = try JSONDecoder().decode(AnisetteData.self, from: jsonData)
            // logger.info("Anisette is valid!")
            return anisette
        } catch {
            // logger.error("Anisette is invalid!!!!")
            throw AnisetteError.invalidAnisetteData
        }
    }
    

}

extension Data {
    func hexEncodedString() -> String {
        return self.map { String(format: "%02hhX", $0) }.joined()
    }
}

enum AnisetteError: LocalizedError {
    case noServerFound
    case invalidProvisioningURLs
    case invalidClientInfo
    case missingUserAgent
    case identifierGenerationFailed
    case missingIdentifier
    case missingClientInfo
    case invalidAnisetteFormat
    case invalidAnisetteData
    case headerError(String)
    case unknownMessageType
    case invalidServerResponse
    case missingCpim
    case missingAdiPb
    case missingProvisioningURL
    case invalidStartProvisioningData
    case invalidEndProvisioningData
    case serverError(String)
    case noAccountSelected
    
    var errorDescription: String? {
        switch self {
        case .noServerFound:
            return "No Anisette Server Found!"
        case .invalidProvisioningURLs:
            return "Apple didn't give valid URLs. Please try again later."
        case .invalidClientInfo:
            return "Couldn't fetch client info. The returned data may not be in JSON."
        case .missingUserAgent:
            return "User agent is missing from client info."
        case .identifierGenerationFailed:
            return "Couldn't generate identifier."
        case .missingIdentifier:
            return "Identifier is missing."
        case .missingClientInfo:
            return "Client info is missing."
        case .invalidAnisetteFormat:
            return "Invalid anisette (the returned data may not be in JSON)."
        case .invalidAnisetteData:
            return "Invalid anisette (the returned data may not have all the required fields)."
        case .headerError(let message):
            return "Header error: \(message)"
        case .unknownMessageType:
            return "Unknown WebSocket message type received."
        case .invalidServerResponse:
            return "Invalid server response."
        case .missingCpim:
            return "The server didn't provide a cpim."
        case .missingAdiPb:
            return "The server didn't provide an adi.pb file."
        case .missingProvisioningURL:
            return "Provisioning URL is missing."
        case .invalidStartProvisioningData:
            return "Apple didn't give valid start provisioning data."
        case .invalidEndProvisioningData:
            return "Apple didn't give valid end provisioning data."
        case .serverError(let message):
            return "Server error: \(message)"
        case .noAccountSelected:
            return "No account selected. Please select an account before getting anisette data."
        }
    }
}
