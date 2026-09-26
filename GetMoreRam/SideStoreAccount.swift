//
//  SideStoreAccount.swift
//  GetMoreRam
//
//  Created by Codex on 2026/7/7.
//

import Foundation
import CryptoKit

/// The account payload SideStore writes when exporting an account.
///
/// SideStore has shipped a few different shapes of this file:
///  * pre 2.0 plain JSON, using `adiPB` / `local_user`
///  * 2.0 JSON, using `anisetteAdiBlob` / `anisetteIdentifier`, with an optional `password`
///  * 2.0 JSON wrapped in an encrypted `.sideconf` container
///
/// Everything certificate related is ignored here, GetMoreRam only needs the Apple ID and
/// the anisette material.
struct SideStoreAccount: Decodable {
    let version: String
    let email: String
    let password: String?
    let adiPB: String
    let localUser: String

    enum CodingKeys: String, CodingKey {
        case version
        case email
        case password
        // 2.0 keys
        case anisetteAdiBlob
        case anisetteIdentifier
        // legacy keys
        case adiPB
        case adiPb
        case adipb
        case localUser = "local_user"
        case localuser
        case localUserCamel = "localUser"
    }

    init(version: String = "2.0", email: String, password: String?, adiPB: String, localUser: String) {
        self.version = version
        self.email = email
        self.password = password
        self.adiPB = adiPB
        self.localUser = localUser
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(String.self, forKey: .version) ?? "1.0"
        email = try container.decodeIfPresent(String.self, forKey: .email) ?? ""
        // The Apple ID password is optional: SideStore only writes it when the user ticked
        // "Include Account Password" while exporting.
        password = try container.decodeIfPresent(String.self, forKey: .password)
        adiPB = try container.decodeIfPresent(String.self, forKey: .anisetteAdiBlob)
            ?? container.decodeIfPresent(String.self, forKey: .adiPB)
            ?? container.decodeIfPresent(String.self, forKey: .adiPb)
            ?? container.decodeIfPresent(String.self, forKey: .adipb)
            ?? ""
        localUser = try container.decodeIfPresent(String.self, forKey: .anisetteIdentifier)
            ?? container.decodeIfPresent(String.self, forKey: .localUser)
            ?? container.decodeIfPresent(String.self, forKey: .localuser)
            ?? container.decodeIfPresent(String.self, forKey: .localUserCamel)
            ?? ""
    }
}

enum SideStoreAccountImportError: LocalizedError {
    case missingRequiredField(String)
    case invalidLocalUser
    case invalidFileFormat
    case passwordRequired
    case decryptionFailed

    var errorDescription: String? {
        switch self {
        case .missingRequiredField(let field):
            return "The SideStore account file is missing \(field)."
        case .invalidLocalUser:
            return "The SideStore account file has an invalid anisette identifier."
        case .invalidFileFormat:
            return "This file is not a SideStore account file."
        case .passwordRequired:
            return "This SideStore account file is encrypted."
        case .decryptionFailed:
            return "Incorrect password or corrupted SideStore account file."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .missingRequiredField:
            return "Export the account again from SideStore (Settings > Export Account) and import the resulting .sideconf file."
        case .invalidLocalUser:
            return "The anisette identifier should be a base64 encoded 16-byte value."
        case .invalidFileFormat:
            return "Choose the .sideconf file exported from SideStore."
        case .passwordRequired:
            return "Enter the file password chosen while exporting the account from SideStore."
        case .decryptionFailed:
            return "Double check the file password chosen while exporting the account from SideStore."
        }
    }
}

/// Reads the `.sideconf` container SideStore writes when exporting an account.
///
/// Layout (see `scripts/sideconf/decrypt_sideconf.py` and `ImportExport.swift` in SideStore):
///
///     [ 16 byte salt ][ 12 byte GCM nonce ][ ciphertext ][ 16 byte GCM tag ]
///
/// The key is PBKDF2-HMAC-SHA256 over the file password, 10 000 iterations, 32 bytes long.
enum SideStoreConfigurationFile {
    static let saltLength = 16
    static let iterations = 10_000
    static let keyLength = 32
    /// 12 byte nonce + 16 byte tag, the smallest possible AES-GCM payload.
    static let minimumSealedBoxLength = 28

    /// The older SideStore export was plain JSON, the `.sideconf` container is raw binary.
    static func isEncrypted(_ data: Data) -> Bool {
        !looksLikeJSON(data)
    }

    static func looksLikeJSON(_ data: Data) -> Bool {
        // The legacy export is a JSON document, while a .sideconf container is a random
        // salt followed by AES-GCM output. Actually parsing is the only reliable test:
        // sniffing the first byte misreads a container whose salt happens to start with
        // "{", and that misread ends up as an unexplained JSON decoding error instead of
        // a password prompt.
        var bytes = data
        // JSONSerialization is picky about a leading UTF-8 BOM, no SideStore export has
        // one but stripping it costs nothing.
        if bytes.starts(with: [0xEF, 0xBB, 0xBF]) {
            bytes = bytes.dropFirst(3)
        }
        return (try? JSONSerialization.jsonObject(with: bytes)) != nil
    }

    static func decrypt(_ data: Data, password: String) throws -> Data {
        guard data.count > saltLength else { throw SideStoreAccountImportError.invalidFileFormat }

        let salt = Data(data.prefix(saltLength))
        let sealedBoxData = Data(data.dropFirst(saltLength))
        guard sealedBoxData.count >= minimumSealedBoxLength else {
            throw SideStoreAccountImportError.invalidFileFormat
        }

        let key = try deriveKey(password: password, salt: salt)

        do {
            let sealedBox = try AES.GCM.SealedBox(combined: sealedBoxData)
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            throw SideStoreAccountImportError.decryptionFailed
        }
    }

    /// PBKDF2-HMAC-SHA256, matching SideStore
    /// `CCKeyDerivationPBKDF(kCCPBKDF2, ..., kCCPRFHmacAlgSHA256, 10000, ..., 32)`.
    static func deriveKey(password: String, salt: Data) throws -> SymmetricKey {
        guard !password.isEmpty else { throw SideStoreAccountImportError.passwordRequired }

        let passwordKey = SymmetricKey(data: Data(password.utf8))
        let hashLength = SHA256.byteCount
        let blockCount = (keyLength + hashLength - 1) / hashLength

        var derived = Data()
        derived.reserveCapacity(blockCount * hashLength)

        for block in 1...max(blockCount, 1) {
            var salted = salt
            // INT_32_BE(block)
            salted.append(UInt8(truncatingIfNeeded: block >> 24))
            salted.append(UInt8(truncatingIfNeeded: block >> 16))
            salted.append(UInt8(truncatingIfNeeded: block >> 8))
            salted.append(UInt8(truncatingIfNeeded: block))

            var u = Data(HMAC<SHA256>.authenticationCode(for: salted, using: passwordKey))
            var result = u

            for _ in 1 ..< iterations {
                u = Data(HMAC<SHA256>.authenticationCode(for: u, using: passwordKey))
                for index in result.indices {
                    result[index] ^= u[index]
                }
            }

            derived.append(result)
        }

        return SymmetricKey(data: derived.prefix(keyLength))
    }
}

enum SideStoreAccountImporter {
    /// `true` when the file is an encrypted `.sideconf` container, so a file password is needed.
    static func requiresPassword(for data: Data) -> Bool {
        SideStoreConfigurationFile.isEncrypted(data)
    }

    static func importAccount(from data: Data, filePassword: String? = nil) throws -> SideStoreAccount {
        let jsonData: Data

        if SideStoreConfigurationFile.isEncrypted(data) {
            guard let filePassword, !filePassword.isEmpty else {
                throw SideStoreAccountImportError.passwordRequired
            }
            jsonData = try SideStoreConfigurationFile.decrypt(data, password: filePassword)
        } else {
            jsonData = data
        }

        let decoded: SideStoreAccount
        do {
            decoded = try JSONDecoder().decode(SideStoreAccount.self, from: jsonData)
        } catch {
            throw SideStoreAccountImportError.invalidFileFormat
        }

        let email = decoded.email.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = decoded.password?.trimmingCharacters(in: .whitespacesAndNewlines)
        let adiPB = decoded.adiPB.trimmingCharacters(in: .whitespacesAndNewlines)
        let localUser = decoded.localUser.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !email.isEmpty else { throw SideStoreAccountImportError.missingRequiredField("email") }
        guard !adiPB.isEmpty else { throw SideStoreAccountImportError.missingRequiredField("anisetteAdiBlob") }
        guard !localUser.isEmpty else { throw SideStoreAccountImportError.missingRequiredField("anisetteIdentifier") }
        guard let decodedLocalUser = Data(base64Encoded: localUser), decodedLocalUser.count == 16 else {
            throw SideStoreAccountImportError.invalidLocalUser
        }

        let account = SideStoreAccount(
            version: decoded.version,
            email: email,
            // SideStore omits the Apple ID password unless the user asked for it to be included.
            password: (password?.isEmpty == false) ? password : nil,
            adiPB: adiPB,
            localUser: localUser
        )

        Keychain.shared.appleIDEmailAddress = account.email
        Keychain.shared.appleIDPassword = account.password
        Keychain.shared.adiPb = account.adiPB
        Keychain.shared.identifier = account.localUser
        AnisetteDataHelper.shared.resetClientInfo()

        return account
    }
}
