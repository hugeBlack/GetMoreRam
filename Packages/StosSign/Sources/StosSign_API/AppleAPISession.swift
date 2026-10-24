//
//  AppleAPISession.swift
//  StosSign
//
//  Created by Stossy11 on 18/03/2025.
//

import Foundation
import StosSign_Common

public class AppleAPISession {
    public var dsid: String
    public var authToken: String
    public var authTokens: [String: String]
    public var anisetteData: AnisetteData

    public init(dsid: String, authToken: String, anisetteData: AnisetteData) {
        self.dsid = dsid
        self.authToken = authToken
        self.authTokens = ["com.apple.gs.xcode.auth": authToken]
        self.anisetteData = anisetteData
    }
    
    public init(dsid: String, authTokens: [String: String], anisetteData: AnisetteData) {
        self.dsid = dsid
        self.authToken = authTokens.first?.value ?? ""
        self.authTokens = authTokens
        self.anisetteData = anisetteData
    }
}
