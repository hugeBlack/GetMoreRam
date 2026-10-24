//
//  AppleAPI+Cert.swift
//  StosSign
//
//  Created by Stossy11 on 12/9/2026.
//

import Foundation
import StosSign_API
import StosSign_Common


public extension AppleAPI {
    private func generate() -> (csr: Data?, privateKey: Data?)? {
        do {
            let (csrData, privateKeyData) = try CSR.generateCSR()
            
            return (csrData, privateKeyData)
        } catch {
            return nil
        }
    }
    
    func addCertificateWithMachineName(machineName: String, team: Team, session: AppleAPISession) async throws -> Certificate {
        guard let certificateRequest = generate(), let csr = certificateRequest.csr, let csrString = String(data: csr, encoding: .utf8) else {
            print("Failed to generate CSR")
            throw AppleAPIError.invalidCertificateRequest
        }

        print("PKey: \(String(data: certificateRequest.privateKey ?? Data(), encoding: .utf8) ?? "nil")")

        let url = qhURL.appendingPathComponent("ios/submitDevelopmentCSR.action")
        
        let responseDictionary = try await sendRequestWithURL(requestURL: url,
                       additionalParameters: [
                        "csrContent": csrString,
                        "machineId": UUID().uuidString,
                        "machineName": machineName
                       ], session: session, team: team)
        
        guard let certRequestDict = responseDictionary["certRequest"] as? [String: Any] else {
            print("Failed to parse certificate request response: \(String(describing: responseDictionary))")

            if let resultCode = responseDictionary["resultCode"] as? Int {
                switch resultCode {
                case 7460:
                    throw AppleAPIError.customError(code: 7460, message: "You already have a current iOS Development certificate or a pending certificate request.")
                default:
                    if let data = responseDictionary["error"] as? String {
                throw AppleAPIError.customError(code: 0, message: data)
            }
            throw AppleAPIError.badServerResponse
                }
            }

            if let data = responseDictionary["error"] as? String {
                throw AppleAPIError.customError(code: 0, message: data)
            }
            throw AppleAPIError.badServerResponse
        }
        

        print("Certificate Request Response: \(certRequestDict)")
        
        guard let certificate = Certificate(response: certRequestDict, certData: csr) else {
            if let data = responseDictionary["error"] as? String {
                throw AppleAPIError.customError(code: 0, message: data)
            }
            throw AppleAPIError.badServerResponse
        }
        
        certificate.privateKey = certificateRequest.privateKey
        return certificate
    }
    
    func fetchCertificatesForTeam(team: Team, session: AppleAPISession) async throws -> [Certificate] {
        let url = v1URL.appendingPathComponent("certificates")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let responseDictionary = try await sendServicesRequest(originalRequest: request, additionalParameters: ["filter[certificateType]": "IOS_DEVELOPMENT"], session: session, team: team)
        
        guard let data = responseDictionary["data"] as? [[String: Any]] else {
            print("Failed to parse certificates response: \(String(describing: responseDictionary))")
            if let data = responseDictionary["error"] as? String {
                throw AppleAPIError.customError(code: 0, message: data)
            }
            if let data = responseDictionary["error"] as? String {
                throw AppleAPIError.customError(code: 0, message: data)
            }
            throw AppleAPIError.badServerResponse
        }

        print("Certificates Response: \(data)")
        
        let certificates = data.compactMap { dict -> Certificate? in
            return Certificate(response: dict)
        }
        
        return certificates
    }
    
    func fetchAllDeviceCertificatesForTeam(team: Team, session: AppleAPISession) async throws -> [Certificate] {
        let url = v1URL.appendingPathComponent("certificates")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let responseDictionary = try await sendServicesRequest(originalRequest: request, session: session, team: team)
        
        guard let data = responseDictionary["data"] as? [[String: Any]] else {
            print("Failed to parse certificates response: \(String(describing: responseDictionary))")
            if let data = responseDictionary["error"] as? String {
                throw AppleAPIError.customError(code: 0, message: data)
            }
            throw AppleAPIError.badServerResponse
        }

        print("Certificates Response: \(data)")
        
        let certificates = data.compactMap { dict -> Certificate? in
            print(dict)
            return Certificate(response: dict)
        }
        
        return certificates
    }
    
    public func revokeCertificate(certificate: Certificate, team: Team, session: AppleAPISession) async throws -> Bool {
        let url = v1URL.appendingPathComponent("certificates").appendingPathComponent(certificate.identifier ?? "")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let responseDictionary = try await sendServicesRequest(originalRequest: request, additionalParameters: nil, session: session, team: team)
        return !responseDictionary.isEmpty
    }
}
