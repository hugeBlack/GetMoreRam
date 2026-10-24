//
//  Authentication.swift
//  StosSign
//
//  Created by Stossy11 on 18/12/2025.
//

import Foundation
import StosSign_API
import StosSign_Common
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public typealias AppleAPISession = StosSign_API.AppleAPISession
public typealias AppleAPIError = StosSign_API.AppleAPIError

public final class Authentication {
    public init() { }
    
    public static let dateFormatter = ISO8601DateFormatter()

    // GetMoreRam patch: configurable headers / hooks for GrandSlam requests.
    /// User-Agent sent to gsa.apple.com (sign-in and 2FA). nil keeps StosSign's defaults.
    public static var userAgentOverride: String?
    /// User-Agent for the 2FA requests. nil uses userAgentOverride.
    public static var twoFactorUserAgentOverride: String?
    /// Shape GrandSlam/2FA requests exactly like SideStore 2.0's SideSign (full cpd, Accept */*,
    /// buddyml 2FA requests) instead of AltSign#61. Used with identities imported from SideStore.
    public static var useSideSignRequestFormat = false
    public static var xcodeVersion = "27.0 (27A5218g)"
    /// Called to get fresh anisette data (new one-time password) between steps.
    public static var anisetteDataRefreshHandler: (() async throws -> AnisetteData)?
    /// Receives human readable progress messages for debugging.
    public static var progressHandler: ((String) -> Void)?

    enum TwoFactorChallenge: Equatable {
        case trustedDevice(codeAlreadySent: Bool)
        case sms
    }

    // Apple can push a code itself, answering hsc=409 with a missing or empty au.
    // See SideStore/SideSign#5 and rileytestut/AltSign#59.
    static func twoFactorChallenge(in response: [String: Any]) -> TwoFactorChallenge? {
        let status = response["Status"] as? [String: Any] ?? [:]
        let authType = [status["au"] as? String, response["au"] as? String]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        switch authType {
        case "trustedDeviceSecondaryAuth", "trustedDevice":
            return .trustedDevice(codeAlreadySent: false)
        case "secondaryAuth", "sms", "voice", "phone":
            return .sms
        case nil where (status["hsc"] as? Int) == 409:
            return .trustedDevice(codeAlreadySent: true)
        default:
            return nil
        }
    }

    static func refreshedAnisetteData(_ fallback: AnisetteData) async throws -> AnisetteData {
        try await anisetteDataRefreshHandler?() ?? fallback
    }

    /// gsa.apple.com currently answers a large share of requests with an HTML 503 page,
    /// independently of their content. Such requests were not processed, so send them again.
    public static func dataRetryingUnavailable(
        for request: URLRequest,
        session: URLSession = AppleAPI.shared.session,
        attempts: Int = 5
    ) async throws -> (Data, URLResponse) {
        var attempt = 1
        while true {
            let (data, response) = try await session.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 503, attempt < attempts else {
                return (data, response)
            }
            progressHandler?("Apple returned HTTP 503 for \(request.url?.lastPathComponent ?? "request"), retrying (\(attempt)/\(attempts - 1))")
            try await Task.sleep(nanoseconds: UInt64(attempt) * 1_000_000_000)
            attempt += 1
        }
    }
    
    public static func authenticate(
        appleID unsanitizedAppleID: String,
        password: String,
        anisetteData: AnisetteData,
        twoFactorAttempt: Int = 0,
        verificationHandler: ((@escaping (String?) -> Void) async -> Void)? = nil
    ) async throws -> (Account, AppleAPISession) {
        let sanitizedAppleID = unsanitizedAppleID.lowercased()
        
        // GetMoreRam patch: same cpd as clients that currently sign in successfully (see rileytestut/AltSign#61)
        func makeClientDictionary(_ anisetteData: AnisetteData) -> [String: Any] {
            if useSideSignRequestFormat {
                // SideSign Authentication.swift
                return [
                    "bootstrap": true,
                    "icscrec": true,
                    "pbe": false,
                    "prkgen": true,
                    "svct": "iCloud",
                    "loc": anisetteData.locale.identifier,
                    "X-Apple-Locale": anisetteData.locale.identifier,
                    "X-Apple-I-MD": anisetteData.oneTimePassword,
                    "X-Apple-I-MD-M": anisetteData.machineID,
                    "X-Mme-Device-Id": anisetteData.deviceUniqueIdentifier,
                    "X-Apple-I-MD-LU": anisetteData.localUserID,
                    "X-Apple-I-MD-RINFO": anisetteData.routingInfo,
                    "X-Apple-I-SRL-NO": anisetteData.deviceSerialNumber,
                    "X-Apple-I-Client-Time": dateFormatter.string(from: anisetteData.date),
                    "X-Apple-I-TimeZone": anisetteData.timeZone.abbreviation() ?? "UTC"
                ]
            }
            return [
            "bootstrap": "true",
            "icscrec": "true",
            "pbe": "false",
            "prkgen": "true",
            "svct": "iCloud",
            "loc": "en_US",
            "X-Apple-I-MD": anisetteData.oneTimePassword,
            "X-Apple-I-MD-M": anisetteData.machineID,
            "X-Mme-Device-Id": anisetteData.deviceUniqueIdentifier
            ]
        }
        let clientDictionary = makeClientDictionary(anisetteData)
        
        let context = GSAContext(username: sanitizedAppleID, password: password)
        guard let publicKey = context.start() else {
            throw AppleAPIError.authenticationHandshakeFailed
        }
        
        let initialParameters: [String: Any] = [
            "A2k": publicKey,
            "cpd": clientDictionary,
            "ps": ["s2k", "s2k_fo"],
            "o": "init",
            "u": sanitizedAppleID
        ]
        
        progressHandler?("GSA: init (password handshake)")
        let responseDictionary = try await sendAuthenticationRequest(
            parameters: initialParameters,
            anisetteData: anisetteData
        )
        
        guard let c = responseDictionary["c"] as? String,
              let salt = responseDictionary["s"] as? Data,
              let iterations = responseDictionary["i"] as? Int,
              let serverPublicKey = responseDictionary["B"] as? Data
        else {
            throw URLError(.badServerResponse)
        }
        
        context.salt = salt
        context.serverPublicKey = serverPublicKey
        
        let sp = responseDictionary["sp"] as? String
        let isHexadecimal = (sp == "s2k_fo")
        
        guard let verificationMessage = context.makeVerificationMessage(
            iterations: iterations,
            isHexadecimal: isHexadecimal
        ) else {
            throw AppleAPIError.authenticationHandshakeFailed
        }
        
        let verificationParameters: [String: Any] = [
            "c": c,
            "cpd": clientDictionary,
            "M1": verificationMessage,
            "o": "complete",
            "u": sanitizedAppleID
        ]
        
        progressHandler?("GSA: complete (password handshake)")
        let verificationResponse = try await sendAuthenticationRequest(
            parameters: verificationParameters,
            anisetteData: anisetteData
        )
        
        guard let serverVerificationMessage = verificationResponse["M2"] as? Data,
              let serverDictionary = verificationResponse["spd"] as? Data,
              let statusDictionary = verificationResponse["Status"] as? [String: Any]
        else {
            throw URLError(.badServerResponse)
        }
        
        guard context.verifyServerVerificationMessage(serverVerificationMessage) else {
            throw AppleAPIError.authenticationHandshakeFailed
        }
        
        guard let decryptedData = serverDictionary.decryptedCBC(context: context) else {
            throw AppleAPIError.authenticationHandshakeFailed
        }
        
        guard let decryptedDictionary = try PropertyListSerialization.propertyList(
            from: decryptedData,
            format: nil
        ) as? [String: Any],
              let dsid = decryptedDictionary["adsid"] as? String,
              let idmsToken = decryptedDictionary["GsIdmsToken"] as? String
        else {
            throw URLError(.badServerResponse)
        }
        
        context.dsid = dsid
        
        progressHandler?("GSA: password accepted, hsc=\(statusDictionary["hsc"] as? Int ?? 0), au=\(statusDictionary["au"] as? String ?? "<none>")")
        switch twoFactorChallenge(in: verificationResponse) {
        case .trustedDevice(let codeAlreadySent)?:
            guard twoFactorAttempt == 0, let verificationHandler = verificationHandler else {
                throw AppleAPIError.requiresTwoFactorAuthentication
            }
            
            progressHandler?(codeAlreadySent
                             ? "2FA: Apple already pushed a code to your trusted devices, waiting for it"
                             : "2FA: requesting a code on your trusted devices")
            try await requestTrustedDeviceTwoFactorCode(
                dsid: dsid,
                idmsToken: idmsToken,
                anisetteData: anisetteData,
                codeAlreadySent: codeAlreadySent,
                verificationHandler: verificationHandler
            )
            
            progressHandler?("2FA: code accepted, signing in again")
            return try await authenticate(
                appleID: unsanitizedAppleID,
                password: password,
                anisetteData: try await refreshedAnisetteData(anisetteData),
                twoFactorAttempt: twoFactorAttempt + 1,
                verificationHandler: verificationHandler
            )
            
        case .sms?:
            guard twoFactorAttempt == 0, let verificationHandler = verificationHandler else {
                throw AppleAPIError.requiresTwoFactorAuthentication
            }
            
            progressHandler?("2FA: requesting an SMS code")
            try await requestSMSTwoFactorCode(
                dsid: dsid,
                idmsToken: idmsToken,
                anisetteData: anisetteData,
                verificationHandler: verificationHandler
            )
            
            progressHandler?("2FA: code accepted, signing in again")
            return try await authenticate(
                appleID: unsanitizedAppleID,
                password: password,
                anisetteData: try await refreshedAnisetteData(anisetteData),
                twoFactorAttempt: twoFactorAttempt + 1,
                verificationHandler: verificationHandler
            )
            
        default:
            guard let sessionKey = decryptedDictionary["sk"] as? Data,
                  let c = decryptedDictionary["c"] as? Data
            else {
                throw URLError(.badServerResponse)
            }
            
            context.sessionKey = sessionKey
            
            let app = "com.apple.gs.xcode.auth"
            guard let checksum = context.makeChecksum(appName: app) else {
                throw AppleAPIError.authenticationHandshakeFailed
            }
            
            // The one-time password was already used by init/complete: get a fresh one,
            // like AltSign does, otherwise Apple answers -80046.
            let tokenAnisetteData = try await refreshedAnisetteData(anisetteData)
            let tokenParameters: [String: Any] = [
                "app": [app],
                "c": c,
                "checksum": checksum,
                "cpd": makeClientDictionary(tokenAnisetteData),
                "o": "apptokens",
                "t": idmsToken,
                "u": dsid
            ]
            
            progressHandler?("GSA: requesting app token")
            let token = try await fetchAuthToken(
                app: app,
                parameters: tokenParameters,
                context: context,
                anisetteData: tokenAnisetteData
            )
            
            let session = AppleAPISession(
                dsid: dsid,
                authToken: token,
                anisetteData: tokenAnisetteData
            )
            
            let account = try await AppleAPI.shared.fetchAccount(session: session)
            return (account, session)
        }
    }
    
    public static func authenticate(
        appleID unsanitizedAppleID: String,
        password: String,
        anisetteData: AnisetteData,
        verificationHandler: ((@escaping (String?) -> Void) -> Void)? = nil,
        completionHandler: @escaping (Account?, AppleAPISession?, Error?) -> Void
    ) {
        Task {
            do {
                let success = try await authenticate(appleID: unsanitizedAppleID, password: password, anisetteData: anisetteData) { veri in
                    verificationHandler?(veri)
                }
                
                completionHandler(success.0, success.1, nil)
            } catch {
                completionHandler(nil, nil, error)
            }
        }
    }
    

    public static func sendAuthenticationRequest(
        parameters requestParameters: [String: Any],
        anisetteData: AnisetteData
    ) async throws -> [String: Any] {
        guard let requestURL = URL(string: "https://gsa.apple.com/grandslam/GsService2") else {
            throw AppleAPIError.unknown
        }
        
        let parameters: [String: Any] = [
            "Header": ["Version": "1.0.1"],
            "Request": requestParameters
        ]
        
        var httpHeaders = [
            "Content-Type": "text/x-xml-plist",
            "X-MMe-Client-Info": anisetteData.deviceDescription,
            "Accept": "text/x-xml-plist",
            "X-Xcode-Version": xcodeVersion,
            "X-Apple-App-Info": "com.apple.gs.xcode.auth",
            "User-Agent": userAgentOverride ?? "akd/1.0 CFNetwork/808.1.4",
            "Connection": "close"
        ]
        if useSideSignRequestFormat {
            httpHeaders["Accept"] = "*/*"
            httpHeaders["X-Xcode-Version"] = nil
            httpHeaders["X-Apple-App-Info"] = nil
        }
        
        let bodyData = try PropertyListSerialization.data(
            fromPropertyList: parameters,
            format: .xml,
            options: 0
        )
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        httpHeaders.forEach { request.addValue($0.value, forHTTPHeaderField: $0.key) }
        
        let (data, response) = try await dataRetryingUnavailable(for: request)
        
        guard let responseDictionary = try? PropertyListSerialization.propertyList(
            from: data,
            format: nil
        ) as? [String: Any],
              let dictionary = responseDictionary["Response"] as? [String: Any],
              let status = dictionary["Status"] as? [String: Any]
        else {
            let httpStatus = (response as? HTTPURLResponse)?.statusCode ?? 0
            let body = String(data: data.prefix(300), encoding: .utf8) ?? "<binary>"
            progressHandler?("GSA: unexpected response HTTP \(httpStatus): \(body)")
            throw AppleAPIError.customError(code: httpStatus, message: "Apple returned an unexpected response (HTTP \(httpStatus)). Try another anisette server or User-Agent.")
        }
        
        let errorCode = status["ec"] as? Int ?? 0
        let operation = requestParameters["o"] as? String ?? "?"
        progressHandler?("GSA \(operation): ec=\(errorCode) hsc=\(status["hsc"] as? Int ?? 0) au=\(status["au"] as? String ?? "<none>")\(errorCode == 0 ? "" : " em=\(status["em"] as? String ?? "")")")
        guard errorCode == 0 else {
            switch errorCode {
            case -20101, -22406:
                throw AppleAPIError.incorrectCredentials
            case -22421:
                throw AppleAPIError.invalidAnisetteData
            case -20209:
                throw AppleAPIError.accountLocked
            default:
                guard let errorDescription = status["em"] as? String else {
                    throw AppleAPIError.unknown
                }
                
                let localizedDescription = "\(errorDescription) (\(errorCode))"
                throw AppleAPIError.customError(code: errorCode, message: localizedDescription)
            }
        }
        
        return dictionary
    }

    public static func makeTwoFactorCodeRequest(
        url: URL,
        dsid: String,
        idmsToken: String,
        anisetteData: AnisetteData
    ) -> URLRequest {
        let identityToken = "\(dsid):\(idmsToken)"
        let encodedIdentityToken = identityToken.data(using: .utf8)?.base64EncodedString() ?? ""
        
        let sideSign = useSideSignRequestFormat
        let httpHeaders = [
            "Accept": sideSign ? "application/x-buddyml" : "text/x-xml-plist",
            "Accept-Language": "en-us",
            "Content-Type": sideSign ? "application/x-plist" : "text/x-xml-plist",
            "User-Agent": twoFactorUserAgentOverride ?? userAgentOverride ?? "akd/1.0 CFNetwork/808.1.4",
            "X-Apple-App-Info": "com.apple.gs.xcode.auth",
            "X-Xcode-Version": xcodeVersion,
            "X-Apple-Identity-Token": encodedIdentityToken,
            "X-Apple-I-MD-M": anisetteData.machineID,
            "X-Apple-I-MD": anisetteData.oneTimePassword,
            "X-Apple-I-MD-LU": anisetteData.localUserID,
            "X-Apple-I-MD-RINFO": "\(anisetteData.routingInfo)",
            "X-Mme-Device-Id": anisetteData.deviceUniqueIdentifier,
            "X-MMe-Client-Info": anisetteData.deviceDescription,
            "X-Apple-I-Client-Time": dateFormatter.string(from: anisetteData.date),
            "X-Apple-Locale": anisetteData.locale.identifier,
            "X-Apple-I-TimeZone": anisetteData.timeZone.abbreviation() ?? "PST",
            "Connection": "close"
        ]
        
        var request = URLRequest(url: url)
        httpHeaders.forEach { request.addValue($0.value, forHTTPHeaderField: $0.key) }
        
        return request
    }
    
    
    // Private funcs :3

    public static func fetchAuthToken(
        app: String,
        parameters: [String: Any],
        context: GSAContext,
        anisetteData: AnisetteData
    ) async throws -> String {
        let responseDictionary = try await sendAuthenticationRequest(
            parameters: parameters,
            anisetteData: anisetteData
        )
        
        guard let encryptedToken = responseDictionary["et"] as? Data else {
            throw URLError(.badServerResponse)
        }
        
        guard let token = encryptedToken.decryptedGCM(context: context) else {
            throw AppleAPIError.authenticationHandshakeFailed
        }
        
        guard let tokensDictionary = try PropertyListSerialization.propertyList(
            from: token,
            format: nil
        ) as? [String: Any] else {
            throw URLError(.badServerResponse)
        }
        
        guard let appTokens = tokensDictionary["t"] as? [String: Any],
              let tokens = appTokens[app] as? [String: Any],
              let authToken = tokens["token"] as? String
        else {
            throw URLError(.badServerResponse)
        }
        
        return authToken
    }

    public static func requestTrustedDeviceTwoFactorCode(
        dsid: String,
        idmsToken: String,
        anisetteData: AnisetteData,
        codeAlreadySent: Bool = false,
        verificationHandler: @escaping (@escaping (String?) -> Void) async -> Void
    ) async throws {
        let requestURL = URL(string: "https://gsa.apple.com/auth/verify/trusteddevice")!
        let verifyURL = URL(string: "https://gsa.apple.com/grandslam/GsService2/validate")!
        
        let request = makeTwoFactorCodeRequest(
            url: requestURL,
            dsid: dsid,
            idmsToken: idmsToken,
            anisetteData: anisetteData
        )
        
        if !codeAlreadySent {
            let (_, response) = try await dataRetryingUnavailable(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            progressHandler?("2FA: trusted device request -> HTTP \(status)"
                             + ((200..<300).contains(status) ? "" : " (not confirmed; enter a code if one arrived)"))
        }
        
        let verificationCode = try await withCheckedThrowingContinuation { continuation in
            Task {
                await verificationHandler { code in
                    continuation.resume(returning: code)
                }
            }
        }
        
        guard let code = verificationCode else {
            throw AppleAPIError.requiresTwoFactorAuthentication
        }
        
        var verifyRequest = makeTwoFactorCodeRequest(
            url: verifyURL,
            dsid: dsid,
            idmsToken: idmsToken,
            anisetteData: try await refreshedAnisetteData(anisetteData)
        )
        verifyRequest.allHTTPHeaderFields?["security-code"] = code
        
        let (data, _) = try await AppleAPI.shared.session.data(for: verifyRequest)
        
        guard let responseDictionary = try PropertyListSerialization.propertyList(
            from: data,
            format: nil
        ) as? [String: Any] else {
            throw URLError(.badServerResponse)
        }
        
        let errorCode = responseDictionary["ec"] as? Int ?? 0
        guard errorCode == 0 else {
            switch errorCode {
            case -21669:
                throw AppleAPIError.incorrectVerificationCode
            default:
                guard let errorDescription = responseDictionary["em"] as? String else {
                    throw AppleAPIError.unknown
                }
                
                let localizedDescription = errorDescription + " (\(errorCode))"
                throw AppleAPIError.customError(code: errorCode, message: errorDescription)
            }
        }
    }

    // GetMoreRam patch: JSON SMS flow used by SideStore's apple-private-apis.
    // The legacy flow always targets phoneNumber.id 1, which may not be the account's number.
    public static func requestSMSTwoFactorCode(
        dsid: String,
        idmsToken: String,
        anisetteData: AnisetteData,
        verificationHandler: @escaping (@escaping (String?) -> Void) async -> Void
    ) async throws {
        func jsonRequest(_ url: URL, method: String, body: [String: Any]? = nil) throws -> URLRequest {
            var request = makeTwoFactorCodeRequest(url: url, dsid: dsid, idmsToken: idmsToken, anisetteData: anisetteData)
            request.httpMethod = method
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if let body {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            }
            return request
        }
        func describe(_ data: Data, _ response: URLResponse) -> String {
            "HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0) \(String(data: data.prefix(300), encoding: .utf8) ?? "")"
        }

        // 1. Trusted phone numbers (201 means Apple already sent an SMS to the first one)
        let (extrasData, extrasResponse) = try await dataRetryingUnavailable(
            for: try jsonRequest(URL(string: "https://gsa.apple.com/auth")!, method: "GET"))
        let extrasStatus = (extrasResponse as? HTTPURLResponse)?.statusCode ?? 0
        // A bare 403: Apple asked for a code by text and won't send one (macOS-ADI servers,
        // 2026-10). Send it to the trusted devices instead and ask for it anyway (SideInstaller 1.6.1).
        func fallBackToTrustedDevices(_ why: String) async throws {
            progressHandler?("2FA: \(why), sending the code to your trusted devices instead")
            try await requestTrustedDeviceTwoFactorCode(dsid: dsid, idmsToken: idmsToken, anisetteData: anisetteData,
                                                        verificationHandler: verificationHandler)
        }
        if extrasStatus == 403 {
            progressHandler?("2FA: GET /auth -> \(describe(extrasData, extrasResponse))")
            try await fallBackToTrustedDevices("Apple refused to list the trusted phone numbers (403)")
            return
        }
        guard let extras = try? JSONSerialization.jsonObject(with: extrasData) as? [String: Any],
              let phones = extras["trustedPhoneNumbers"] as? [[String: Any]],
              let phone = phones.first,
              let phoneID = phone["id"] as? Int else {
            progressHandler?("2FA: couldn't list trusted phone numbers (\(describe(extrasData, extrasResponse))), using legacy SMS request")
            try await requestLegacySMSTwoFactorCode(dsid: dsid, idmsToken: idmsToken, anisetteData: anisetteData, verificationHandler: verificationHandler)
            return
        }
        progressHandler?("2FA: trusted numbers: " + phones.map { "\($0["numberWithDialCode"] as? String ?? "?") (id \($0["id"] ?? "?"))" }.joined(separator: ", "))

        // 2. Ask for the SMS unless Apple already sent it
        if extrasStatus == 201 {
            progressHandler?("2FA: Apple already sent an SMS to id \(phoneID)")
        } else {
            let (data, response) = try await dataRetryingUnavailable(
                for: try jsonRequest(URL(string: "https://gsa.apple.com/auth/verify/phone/")!, method: "PUT",
                                     body: ["phoneNumber": ["id": phoneID], "mode": "sms"]))
            progressHandler?("2FA: SMS request to id \(phoneID) -> \(describe(data, response))")
            if (response as? HTTPURLResponse)?.statusCode == 403 {
                try await fallBackToTrustedDevices("Apple refused to send the SMS (403)")
                return
            }
            guard let status = (response as? HTTPURLResponse)?.statusCode, (200..<300).contains(status) else {
                throw AppleAPIError.customError(code: (response as? HTTPURLResponse)?.statusCode ?? 0,
                                                message: "Apple refused to send the SMS code.")
            }
        }

        let verificationCode = try await withCheckedThrowingContinuation { continuation in
            Task {
                await verificationHandler { code in
                    continuation.resume(returning: code)
                }
            }
        }
        guard let code = verificationCode else {
            throw AppleAPIError.requiresTwoFactorAuthentication
        }

        // 3. Validate the code
        let (data, response) = try await dataRetryingUnavailable(
            for: try jsonRequest(URL(string: "https://gsa.apple.com/auth/verify/phone/securitycode")!, method: "POST",
                                 body: ["phoneNumber": ["id": phoneID], "mode": "sms", "securityCode": ["code": code]]))
        progressHandler?("2FA: SMS code check -> \(describe(data, response))")
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw AppleAPIError.incorrectVerificationCode
        }
    }

    static func requestLegacySMSTwoFactorCode(
        dsid: String,
        idmsToken: String,
        anisetteData: AnisetteData,
        verificationHandler: @escaping (@escaping (String?) -> Void) async -> Void
    ) async throws {
        let requestURL = URL(string: "https://gsa.apple.com/auth/verify/phone/put?mode=sms")!
        let verifyURL = URL(string: "https://gsa.apple.com/auth/verify/phone/securitycode?referrer=/auth/verify/phone/put")!
        
        var request = makeTwoFactorCodeRequest(
            url: requestURL,
            dsid: dsid,
            idmsToken: idmsToken,
            anisetteData: anisetteData
        )
        request.httpMethod = "POST"
        
        let bodyXML = [
            "serverInfo": [
                "phoneNumber.id": "1"
            ]
        ] as [String: Any]
        
        let bodyData = try PropertyListSerialization.data(
            fromPropertyList: bodyXML,
            format: .xml,
            options: 0
        )
        request.httpBody = bodyData
        
        let (_, smsResponse) = try await AppleAPI.shared.session.data(for: request)
        progressHandler?("2FA: SMS request -> HTTP \((smsResponse as? HTTPURLResponse)?.statusCode ?? 0)")
        
        let verificationCode = try await withCheckedThrowingContinuation { continuation in
            Task {
                await verificationHandler { code in
                    continuation.resume(returning: code)
                }
            }
        }
        
        guard let code = verificationCode else {
            throw AppleAPIError.requiresTwoFactorAuthentication
        }
        
        var verifyRequest = makeTwoFactorCodeRequest(
            url: verifyURL,
            dsid: dsid,
            idmsToken: idmsToken,
            anisetteData: anisetteData
        )
        verifyRequest.httpMethod = "POST"
        
        let verifyBodyXML = [
            "securityCode.code": code,
            "serverInfo": [
                "mode": "sms",
                "phoneNumber.id": "1"
            ]
        ] as [String: Any]
        
        let verifyBodyData = try PropertyListSerialization.data(
            fromPropertyList: verifyBodyXML,
            format: .xml,
            options: 0
        )
        verifyRequest.httpBody = verifyBodyData
        
        let (_, response) = try await AppleAPI.shared.session.data(for: verifyRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              httpResponse.allHeaderFields.keys.contains("X-Apple-PE-Token")
        else {
            throw AppleAPIError.incorrectVerificationCode
        }
    }
}
