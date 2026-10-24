//
//  AppleAPI+Authentication.swift
//  StosSign
//
//  Created by Stossy11 on 06/12/2025.
//

import Foundation
import StosSign_API
import StosSign_Common

extension AppleAPI {
    public func authenticate(
        appleID unsanitizedAppleID: String,
        password: String,
        anisetteData: AnisetteData,
        verificationHandler: ((@escaping (String?) -> Void) async -> Void)? = nil
    ) async throws -> (Account, AppleAPISession) {
        try await Authentication.authenticate(appleID: unsanitizedAppleID, password: password, anisetteData: anisetteData, verificationHandler: verificationHandler)
    }
}
