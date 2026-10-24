//
//  Certificate+Parse.swift
//  StosSign
//
//  Created by Stossy11 on 06/12/2025.
//

import Foundation
#if canImport(Security)
import Security
#endif

extension Certificate {
    static func parseP12Data(p12Data: Data, password: String) -> (certificatePEM: Data, privateKeyPEM: Data)? {
#if !canImport(Security)
        return nil
#else
        let options = [kSecImportExportPassphrase as String: password]
        
        var items: CFArray?
        let status = SecPKCS12Import(p12Data as CFData, options as CFDictionary, &items)
        
        guard status == errSecSuccess,
              let array = items as? [[String: Any]],
              let firstItem = array.first else {
            return nil
        }

        let identity = firstItem[kSecImportItemIdentity as String] as! SecIdentity
        
        var certificate: SecCertificate?
        SecIdentityCopyCertificate(identity, &certificate)
        
        guard let cert = certificate else { return nil }
        
        var privateKey: SecKey?
        SecIdentityCopyPrivateKey(identity, &privateKey)
        
        guard let key = privateKey else { return nil }
        
        let certData = SecCertificateCopyData(cert) as Data
        let certPEM = """
        -----BEGIN CERTIFICATE-----
        \(certData.base64EncodedString(options: [.lineLength64Characters]))
        -----END CERTIFICATE-----
        """.data(using: .utf8)!
        
        var error: Unmanaged<CFError>?
        guard let keyData = SecKeyCopyExternalRepresentation(key, &error) as Data? else {
            return nil
        }
        
        let keyPEM = """
        -----BEGIN PRIVATE KEY-----
        \(keyData.base64EncodedString(options: [.lineLength64Characters]))
        -----END PRIVATE KEY-----
        """.data(using: .utf8)!
        
        return (certificatePEM: certPEM, privateKeyPEM: keyPEM)
#endif
    }

}
