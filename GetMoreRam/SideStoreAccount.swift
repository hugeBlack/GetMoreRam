//
//  SideStoreAccount.swift
//  GetMoreRam
//
//  Created by Codex on 2026/7/7.
//

import Foundation

struct SideStoreAccount: Decodable {
    let email: String
    let password: String
    let adiPB: String
    let localUser: String
    
    enum CodingKeys: String, CodingKey {
        case email
        case password
        case adiPB
        case adiPb
        case adipb
        case localUser = "local_user"
        case localuser
        case localUserCamel = "localUser"
    }
    
    init(email: String, password: String, adiPB: String, localUser: String) {
        self.email = email
        self.password = password
        self.adiPB = adiPB
        self.localUser = localUser
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        email = try container.decodeIfPresent(String.self, forKey: .email) ?? ""
        password = try container.decodeIfPresent(String.self, forKey: .password) ?? ""
        adiPB = try container.decodeIfPresent(String.self, forKey: .adiPB)
            ?? container.decodeIfPresent(String.self, forKey: .adiPb)
            ?? container.decodeIfPresent(String.self, forKey: .adipb)
            ?? ""
        localUser = try container.decodeIfPresent(String.self, forKey: .localUser)
            ?? container.decodeIfPresent(String.self, forKey: .localuser)
            ?? container.decodeIfPresent(String.self, forKey: .localUserCamel)
            ?? ""
    }
}

enum SideStoreAccountImportError: LocalizedError {
    case missingRequiredField(String)
    case invalidLocalUser
    
    var errorDescription: String? {
        switch self {
        case .missingRequiredField(let field):
            return "The SideStore account file is missing \(field)."
        case .invalidLocalUser:
            return "The SideStore account file has an invalid local_user value."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .missingRequiredField:
            return "Choose a SideStore account JSON file that contains email, password, adiPB, and local_user."
        case .invalidLocalUser:
            return "local_user should be a base64 encoded 16-byte identifier."
        }
    }
}

enum SideStoreAccountImporter {
    static func importAccount(from data: Data) throws -> SideStoreAccount {
        let account = try JSONDecoder().decode(SideStoreAccount.self, from: data)
        
        let email = account.email.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = account.password.trimmingCharacters(in: .whitespacesAndNewlines)
        let adiPB = account.adiPB.trimmingCharacters(in: .whitespacesAndNewlines)
        let localUser = account.localUser.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !email.isEmpty else { throw SideStoreAccountImportError.missingRequiredField("email") }
        guard !password.isEmpty else { throw SideStoreAccountImportError.missingRequiredField("password") }
        guard !adiPB.isEmpty else { throw SideStoreAccountImportError.missingRequiredField("adiPB") }
        guard !localUser.isEmpty else { throw SideStoreAccountImportError.missingRequiredField("local_user") }
        guard let decodedLocalUser = Data(base64Encoded: localUser), decodedLocalUser.count == 16 else {
            throw SideStoreAccountImportError.invalidLocalUser
        }
        
        Keychain.shared.appleIDEmailAddress = email
        Keychain.shared.appleIDPassword = password
        Keychain.shared.adiPb = adiPB
        Keychain.shared.identifier = localUser
        AnisetteDataHelper.adiPlatform = AnisetteDataHelper.importedADIPlatform
        AnisetteDataHelper.shared.resetClientInfo()
        
        return SideStoreAccount(email: email, password: password, adiPB: adiPB, localUser: localUser)
    }
}
