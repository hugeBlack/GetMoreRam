//
//  Certificate.swift
//  StosSign
//
//  Created by Stossy11 on 18/03/2025.
//

import Foundation
#if canImport(StosOpenSSL)
import StosOpenSSL
#endif

public final class Certificate {
    public let name: String
    public let serialNumber: String
    public let data: Data?
    public var privateKey: Data?
    
    public var machineName: String?
    public var machineIdentifier: String?
    public var identifier: String?
    public var expirationDate: Date?
    
    public var certificateType: String?
    
    public init(name: String, serialNumber: String, expirationDate: Date? = nil, identifier: String? = nil, machineName: String? = nil, machineIdentifier: String? = nil, data: Data? = nil, privateKey: Data? = nil, certificateType: String? = nil) {
        self.name = name
        self.serialNumber = serialNumber
        self.identifier = identifier
        self.machineName = machineName
        self.machineIdentifier = machineIdentifier
        self.expirationDate = expirationDate
        self.certificateType = certificateType
        
        if privateKey == nil, let data {
            guard let components = Self.parseP12Data(p12Data: data, password: "") else {
                self.data = data
                self.privateKey = privateKey
                return
            }
            
            self.privateKey = components.privateKeyPEM
            self.data = components.certificatePEM
        } else {
            self.data = data
            self.privateKey = privateKey
        }
    }
    
    public convenience init?(certificateData: Data) {
        let pemData = certificateData
        
        guard let parsed = Self.parse(pemData) else {
            return nil
        }

        let trimmedSerial = parsed.serial.drop(while: { $0 == "0" })
        guard !trimmedSerial.isEmpty else {
            return nil
        }
        
        self.init(
            name: parsed.name,
            serialNumber: String(trimmedSerial),
            data: pemData
        )
    }
    
    public convenience init?(p12Data: Data, password: String? = nil) {
        guard let components = Self.parseP12Data(p12Data: p12Data, password: password ?? "") else {
            return nil
        }
        
        guard let certificate = Certificate(certificateData: components.certificatePEM) else {
            return nil
        }
        
        self.init(
            name: certificate.name,
            serialNumber: certificate.serialNumber,
            data: certificate.data,
            privateKey: components.privateKeyPEM
        )
    }
    
    public convenience init?(response: [String: Any], certData: Data? = nil) {
        let attributes = response["attributes"] as? [String: Any] ?? response
        
        let certificateData = Self.extractCertificateData(from: attributes) ?? certData
        
        let machineName = Self.extractString(attributes["machineName"])
        let machineIdentifier = Self.extractString(attributes["machineId"])
        let identifier2 = Self.extractString(response["id"])
        let identifier = identifier2 ?? Self.extractString(attributes["certificateId"])
        let certificateType = Self.extractString(attributes["certificateType"])
        
        if let data = certificateData, let certificate = Certificate(certificateData: data) {
            self.init(
                name: certificate.name,
                serialNumber: certificate.serialNumber,
                data: certificate.data,
                certificateType: certificateType
            )
        } else {
            let name = Self.extractString(attributes["name"]) ?? ""
            let serial = Self.extractString(attributes["serialNumber"]) ??
                        Self.extractString(attributes["serialNum"]) ?? ""
            self.init(name: name, serialNumber: serial, data: nil, certificateType: certificateType)
        }
        
        if let expirationDate = Self.extractString(attributes["expirationDate"])  {
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX") // set locale to reliable US_POSIX
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            let date = dateFormatter.date(from: expirationDate)
            
            self.expirationDate = date
        }
        
        self.machineName = machineName
        self.machineIdentifier = machineIdentifier
        self.identifier = identifier
    }
    
    public var p12Data: Data? {
        guard let certificateData = data,
              let privateKeyData = privateKey else {
            return nil
        }
        
        print(certificateData)
        return Self.createP12(
            certificate: certificateData,
            privateKey: privateKeyData,
            password: ""
        )
    }
    
    private static func parse(_ pemData: Data) -> (name: String, serial: String)? {        
        return CertificateParser.parseCerts(pemData)
    }
    
    public static func createP12(certificate: Data, privateKey: Data, password: String) -> Data? {
#if canImport(StosOpenSSL)
        OpenSSL_add_all_algorithms()
        
        var p12Pointer: UnsafeMutablePointer<UInt8>?
        var p12Length: size_t = 0
        
        let success = certificate.withUnsafeBytes { certBuffer in
            guard let certBase = certBuffer.baseAddress else { return false }
            return privateKey.withUnsafeBytes { keyBuffer in
                guard let keyBase = keyBuffer.baseAddress else { return false }
                return create_p12_data(
                    certBase.assumingMemoryBound(to: UInt8.self),
                    Int32(certificate.count),
                    keyBase.assumingMemoryBound(to: UInt8.self),
                    Int32(privateKey.count),
                    password.cString(using: .utf8),
                    &p12Pointer,
                    &p12Length
                )
            }
        }
        
        guard success,
              let pointer = p12Pointer,
              p12Length > 0 else {
            return nil
        }
        
        defer { free(p12Pointer) }
        return Data(bytes: pointer, count: p12Length)
        #else
        return Data()
        #endif
    }
    
    private static func extractCertificateData(from attributes: [String: Any]) -> Data? {
        if let data = attributes["certContent"] as? Data {
            return data
        }
    
        if let encoded = attributes["certContent"] as? String {
            if let decoded = Data(base64Encoded: encoded) {
                return decoded
            }
        }
        
        if let encoded = attributes["certificateContent"] as? String {
            if let decoded = Data(base64Encoded: encoded) {
                return decoded
            }
        }
        
        return nil
    }
    
    private static func extractString(_ value: Any?) -> String? {
        guard let string = value as? String,
              !(value is NSNull) else {
            return nil
        }
        return string
    }
}


// extensions, since i wanna try something new :3
extension Certificate: Equatable {
    public static func == (lhs: Certificate, rhs: Certificate) -> Bool {
        lhs.serialNumber == rhs.serialNumber
    }
}

extension Certificate: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(serialNumber)
    }
}

extension String {
    func chunked(into size: Int) -> [String] {
        stride(from: 0, to: count, by: size).map {
            let start = index(startIndex, offsetBy: $0)
            let end = index(start, offsetBy: size, limitedBy: endIndex) ?? endIndex
            return String(self[start..<end])
        }
    }
}

extension Data {
    var isPEM: Bool {
        guard let string = String(data: self, encoding: .utf8) else { return false }
        return string.hasPrefix("-----BEGIN CERTIFICATE-----")
    }
}
