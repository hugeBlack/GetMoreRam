//
//  FetchAnisetteDataOperation.swift
//  AltStore
//
//  Created by Riley Testut on 1/7/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import Foundation
import CommonCrypto
import Starscream
import KeychainAccess

import AltSign

final class AnisetteDataHelper: WebSocketDelegate
{
    var socket: WebSocket!
    
    var url: URL?
    var startProvisioningURL: URL?
    var endProvisioningURL: URL?
    
    var clientInfo: String?
    var userAgent: String?
    
    var mdLu: String?
    var deviceId: String?
    
    var menuAnisetteURL: String?
    
    private var wsContinuation: UnsafeContinuation<(), Error>?
    
    static var shared: AnisetteDataHelper = AnisetteDataHelper()
    
    var cache: ALTAnisetteData?
    func getAnisetteData(refresh: Bool = false) async throws -> ALTAnisetteData
    {
        if let cache, !refresh {
            return cache
        }
        
        if url == nil {
            throw "No Anisette Server Found!"
        }
        
        self.printOut("Anisette URL: \(self.url!.absoluteString)")
        
        let ans : ALTAnisetteData
        if let identifier = Keychain.shared.identifier,
           let adiPb = Keychain.shared.adiPb {
            ans = try await self.fetchAnisetteV3(identifier, adiPb)
        } else {
            ans = try await self.provision()
        }
        cache = ans
        return ans
    }
    
    // MARK: - COMMON
    
    func extractAnisetteData(_ data: Data, _ response: HTTPURLResponse?, v3: Bool) async throws -> ALTAnisetteData {
        // make sure this JSON is in the format we expect
        // convert data to json
        if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: String] {
            if v3 {
                if json["result"] == "GetHeadersError" {
                    let message = json["message"]
                    self.printOut("Error getting V3 headers: \(message ?? "no message")")
                    if let message = message,
                       message.contains("-45061") {
                        self.printOut("Error message contains -45061 (not provisioned), resetting adi.pb and retrying")
                        Keychain.shared.adiPb = nil
                        return try await provision()
                    } else { throw message ?? "Unknown error" }
                }
            }
            
            // try to read out a dictionary
            // for some reason serial number isn't needed but it doesn't work unless it has a value
            var formattedJSON: [String: String] = ["deviceSerialNumber": "0"]
            if let machineID = json["X-Apple-I-MD-M"] { formattedJSON["machineID"] = machineID }
            if let oneTimePassword = json["X-Apple-I-MD"] { formattedJSON["oneTimePassword"] = oneTimePassword }
            if let routingInfo = json["X-Apple-I-MD-RINFO"] { formattedJSON["routingInfo"] = routingInfo }
            
            if v3 {
                formattedJSON["deviceDescription"] = self.clientInfo!
                formattedJSON["localUserID"] = self.mdLu!
                formattedJSON["deviceUniqueIdentifier"] = self.deviceId!
                
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
                self.printOut("Implementation-Version: \(version)")
            } else { self.printOut("No Implementation-Version header") }
            
            self.printOut("Anisette used: \(formattedJSON)")
            self.printOut("Original JSON: \(json)")
            if let anisette = ALTAnisetteData(json: formattedJSON) {
                self.printOut("Anisette is valid!")
                return anisette
            } else {
                self.printOut("Anisette is invalid!!!!")
                if v3 {
                    throw "Invalid anisette (the returned data may not have all the required fields)"
                } else {
                    throw "Invalid anisette (the returned data may not have all the required fields)"
                }
            }
        } else {
            if v3 {
                throw "Invalid anisette (the returned data may not be in JSON)"
            } else {
                throw "Invalid anisette (the returned data may not be in JSON)"
            }
        }
    }
    
    
    // MARK: - V3: PROVISIONING
    
    func provision() async throws -> ALTAnisetteData {
        try await fetchClientInfo()
            self.printOut("Getting provisioning URLs")
            var request = self.buildAppleRequest(url: URL(string: "https://gsa.apple.com/grandslam/GsService2/lookup")!)
            request.httpMethod = "GET"
        let (data, response) = try await URLSession.shared.asyncRequest(request: request)
        if let data = data,
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? Dictionary<String, Dictionary<String, Any>>,
           let startProvisioningString = plist["urls"]?["midStartProvisioning"] as? String,
           let startProvisioningURL = URL(string: startProvisioningString),
           let endProvisioningString = plist["urls"]?["midFinishProvisioning"] as? String,
           let endProvisioningURL = URL(string: endProvisioningString) {
            self.startProvisioningURL = startProvisioningURL
            self.endProvisioningURL = endProvisioningURL
            self.printOut("startProvisioningURL: \(self.startProvisioningURL!.absoluteString)")
            self.printOut("endProvisioningURL: \(self.endProvisioningURL!.absoluteString)")
            self.printOut("Starting a provisioning session")
            return try await self.startProvisioningSession()
        } else {
            self.printOut("Apple didn't give valid URLs! Got response: \(String(data: data ?? Data("nothing".utf8), encoding: .utf8) ?? "not utf8")")
            throw "Apple didn't give valid URLs. Please try again later"
        }

        
    }
    
    func startProvisioningSession() async throws -> ALTAnisetteData{
        let provisioningSessionURL = self.url!.appendingPathComponent("v3").appendingPathComponent("provisioning_session")
        var wsRequest = URLRequest(url: provisioningSessionURL)
        wsRequest.timeoutInterval = 5
        self.socket = WebSocket(request: wsRequest)
        self.socket.delegate = self
        self.socket.connect()
        try await withUnsafeThrowingContinuation { c in
            wsContinuation = c
        }
        return try await self.fetchAnisetteV3(Keychain.shared.identifier!, Keychain.shared.adiPb!)
    }
    
    func didReceive(event: WebSocketEvent, client: WebSocketClient) {
        switch event {
        case .text(let string):
            do {
                if let json = try JSONSerialization.jsonObject(with: string.data(using: .utf8)!, options: []) as? [String: Any] {
                    guard let result = json["result"] as? String else {
                        self.printOut("The server didn't give us a result")
                        client.disconnect(closeCode: 0)
                        wsContinuation?.resume(throwing: "The server didn't give us a result")
                        return
                    }
                    self.printOut("Received result: \(result)")
                    switch result {
                    case "GiveIdentifier":
                        self.printOut("Giving identifier")
                        client.json(["identifier": Keychain.shared.identifier!])
                        
                    case "GiveStartProvisioningData":
                        self.printOut("Getting start provisioning data")
                        let body = [
                            "Header": [String: Any](),
                            "Request": [String: Any](),
                        ]
                        var request = self.buildAppleRequest(url: self.startProvisioningURL!)
                        request.httpMethod = "POST"
                        request.httpBody = try! PropertyListSerialization.data(fromPropertyList: body, format: .xml, options: 0)
                        URLSession.shared.dataTask(with: request) { data, response, error in
                            if let data = data,
                               let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? Dictionary<String, Dictionary<String, Any>>,
                               let spim = plist["Response"]?["spim"] as? String {
                                self.printOut("Giving start provisioning data")
                                client.json(["spim": spim])
                            } else {
                                self.printOut("Apple didn't give valid start provisioning data! Got response: \(String(data: data ?? Data("nothing".utf8), encoding: .utf8) ?? "not utf8")")
                                client.disconnect(closeCode: 0)
                                self.wsContinuation?.resume(throwing: "Apple didn't give valid start provisioning data. Please try again later")
                            }
                        }.resume()
                        
                    case "GiveEndProvisioningData":
                        self.printOut("Getting end provisioning data")
                        guard let cpim = json["cpim"] as? String else {
                            self.printOut("The server didn't give us a cpim")
                            client.disconnect(closeCode: 0)
                            self.wsContinuation?.resume(throwing: "The server didn't give us a cpim")
                            return
                        }
                        let body = [
                            "Header": [String: Any](),
                            "Request": [
                                "cpim": cpim,
                            ],
                        ]
                        var request = self.buildAppleRequest(url: self.endProvisioningURL!)
                        request.httpMethod = "POST"
                        request.httpBody = try! PropertyListSerialization.data(fromPropertyList: body, format: .xml, options: 0)
                        URLSession.shared.dataTask(with: request) { data, response, error in
                            if let data = data,
                               let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? Dictionary<String, Dictionary<String, Any>>,
                               let ptm = plist["Response"]?["ptm"] as? String,
                               let tk = plist["Response"]?["tk"] as? String {
                                self.printOut("Giving end provisioning data")
                                client.json(["ptm": ptm, "tk": tk])
                            } else {
                                self.printOut("Apple didn't give valid end provisioning data! Got response: \(String(data: data ?? Data("nothing".utf8), encoding: .utf8) ?? "not utf8")")
                                client.disconnect(closeCode: 0)
                                self.wsContinuation?.resume(throwing: "Apple didn't give valid end provisioning data. Please try again later")
                            }
                        }.resume()
                        
                    case "ProvisioningSuccess":
                        self.printOut("Provisioning succeeded!")
                        client.disconnect(closeCode: 0)
                        guard let adiPb = json["adi_pb"] as? String else {
                            self.printOut("The server didn't give us an adi.pb file")
                            self.wsContinuation?.resume(throwing: "The server didn't give us an adi.pb file")
                            return
                        }
                        Keychain.shared.adiPb = adiPb
                        wsContinuation?.resume()
                        
                    default:
                        if result.contains("Error") || result.contains("Invalid") || result == "ClosingPerRequest" || result == "Timeout" || result == "TextOnly" {
                            self.printOut("Failing because of \(result)")
                            self.wsContinuation?.resume(throwing: result + (json["message"] as? String ?? ""))
                        }
                    }
                }
            } catch let error as NSError {
                self.printOut("Failed to handle text: \(error.localizedDescription)")
                self.wsContinuation?.resume(throwing: error)
            }
            
        case .connected:
            self.printOut("Connected")
            
        case .disconnected(let string, let code):
            self.printOut("Disconnected: \(code); \(string)")
            
        case .error(let error):
            self.printOut("Got error: \(String(describing: error))")
            
        default:
            self.printOut("Unknown event: \(event)")
        }
    }
    
    func buildAppleRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue(self.clientInfo!, forHTTPHeaderField: "X-Mme-Client-Info")
        request.setValue(self.userAgent!, forHTTPHeaderField: "User-Agent")
        request.setValue("text/x-xml-plist", forHTTPHeaderField: "Content-Type")
        request.setValue("*/*", forHTTPHeaderField: "Accept")

        request.setValue(self.mdLu!, forHTTPHeaderField: "X-Apple-I-MD-LU")
        request.setValue(self.deviceId!, forHTTPHeaderField: "X-Mme-Device-Id")

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
    
    // MARK: - V3: FETCHING
    
    func fetchClientInfo() async throws {
        if  self.clientInfo != nil &&
                self.userAgent != nil &&
                self.mdLu != nil &&
                self.deviceId != nil &&
                Keychain.shared.identifier != nil {
            self.printOut("Skipping client_info fetch since all the properties we need aren't nil")
            return
        }
        self.printOut("Trying to get client_info")
        let clientInfoURL = self.url!.appendingPathComponent("v3").appendingPathComponent("client_info")
        
        let (data, response) = try await URLSession.shared.asyncRequest(url: clientInfoURL)
        

            do {
                guard let data = data else {
                    throw "Couldn't fetch client info. The server may be down"
                }
                
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: String] {
                    if let clientInfo = json["client_info"] {
                        self.printOut("Server is V3")
                        
                        self.clientInfo = clientInfo
                        self.userAgent = json["user_agent"]!
                        self.printOut("Client-Info: \(self.clientInfo!)")
                        self.printOut("User-Agent: \(self.userAgent!)")
                        
                        if Keychain.shared.identifier == nil {
                            self.printOut("Generating identifier")
                            var bytes = [Int8](repeating: 0, count: 16)
                            let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
                            
                            if status != errSecSuccess {
                                self.printOut("ERROR GENERATING IDENTIFIER!!! \(status)")
                                throw "Couldn't generate identifier"
                            }
                            
                            Keychain.shared.identifier = Data(bytes: &bytes, count: bytes.count).base64EncodedString()
                        }
                        
                        let decoded = Data(base64Encoded: Keychain.shared.identifier!)!
                        self.mdLu = decoded.sha256().hexEncodedString()
                        self.printOut("X-Apple-I-MD-LU: \(self.mdLu!)")
                        let uuid: UUID = decoded.object()
                        self.deviceId = uuid.uuidString.uppercased()
                        self.printOut("X-Mme-Device-Id: \(self.deviceId!)")
                        
                        return
                    } else { throw "v1 server is not supported" }
                } else { throw "Couldn't fetch client info. The returned data may not be in JSON" }
            }

    }
    
    func fetchAnisetteV3(_ identifier: String, _ adiPb: String) async throws -> ALTAnisetteData {
        try await fetchClientInfo()
        self.printOut("Fetching anisette V3")
        let url = menuAnisetteURL
        var request = URLRequest(url: self.url!.appendingPathComponent("v3").appendingPathComponent("get_headers"))
        request.httpMethod = "POST"
        request.httpBody = try! JSONSerialization.data(withJSONObject: [
            "identifier": identifier,
            "adi_pb": adiPb
        ], options: [])
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await URLSession.shared.asyncRequest(request: request)

        guard let data else { throw "Couldn't fetch anisette" }
        
        return try await self.extractAnisetteData(data, response as? HTTPURLResponse, v3: true)

    }
    
    
    private func printOut(_ text: String?){
        let isInternalLoggingEnabled = true
        if(isInternalLoggingEnabled){
            // logging enabled, so log it
            text.map{ _ in print(text!) } ?? print()
        }
    }
}

extension WebSocketClient {
    func json(_ dictionary: [String: String]) {
        let data = try! JSONSerialization.data(withJSONObject: dictionary, options: [])
        self.write(string: String(data: data, encoding: .utf8)!)
    }
}

extension Data {
    // https://stackoverflow.com/a/25391020
    func sha256() -> Data {
        var hash = [UInt8](repeating: 0,  count: Int(CC_SHA256_DIGEST_LENGTH))
        self.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(self.count), &hash)
        }
        return Data(hash)
    }
    
    // https://stackoverflow.com/a/40089462
    func hexEncodedString() -> String {
        return self.map { String(format: "%02hhX", $0) }.joined()
    }
    
    // https://stackoverflow.com/a/59127761
    func object<T>() -> T { self.withUnsafeBytes { $0.load(as: T.self) } }
}
