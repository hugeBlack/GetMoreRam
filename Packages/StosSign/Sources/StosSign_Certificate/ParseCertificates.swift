//
//  ParseCertificates.swift
//  StosSign
//
//  Created by Stossy11 on 09/12/2025.
//

import Foundation
import X509

public class CertificateParser {
    public static func parseCerts(_ cert: Data) -> (String, String)? {
        let bytes = [UInt8](cert)
        
        let certificate: X509.Certificate
        
        
        
        if let certDer = try? X509.Certificate(derEncoded: bytes) {
            certificate = certDer
        } else if let pemString = String(data: cert, encoding: .utf8),
                  let certPem = try? X509.Certificate(pemEncoded: pemString) {
            certificate = certPem
        } else {
            return nil
        }
        
        let serial = certificate.serialNumber.bytes
            .map { String(format: "%02X", $0) }
            .joined()
        
        let commonName = String(describing: certificate.subject[1])
        
        return (commonName, serial)
    }
}
