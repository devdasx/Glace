import CommonCrypto
import CryptoKit
import Foundation
import Security

enum WatchWalletVaultError: Error, Equatable {
    case encryptionFailed
    case invalidPasscode
    case keyDerivationFailed
    case keychainFailure(OSStatus)
}

enum WatchWalletVault {
    private static let service = "com.devdasx.glace.watch-wallet"
    private static let account = "primary"
    private static let derivationRounds: UInt32 = 210_000

    static func save(
        _ record: WatchWalletRecord,
        passcode: String
    ) throws {
        let encodedRecord = try JSONEncoder().encode(record)
        let envelope = try seal(encodedRecord, passcode: passcode)
        let encodedEnvelope = try JSONEncoder().encode(envelope)

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData] = encodedEnvelope
        attributes[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw WatchWalletVaultError.keychainFailure(status)
        }
    }

    static func load(passcode: String) throws -> WatchWalletRecord {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            throw WatchWalletVaultError.keychainFailure(status)
        }

        let envelope = try JSONDecoder().decode(WatchEncryptedEnvelope.self, from: data)
        let recordData = try open(envelope, passcode: passcode)
        return try JSONDecoder().decode(WatchWalletRecord.self, from: recordData)
    }

    static func seal(
        _ plaintext: Data,
        passcode: String
    ) throws -> WatchEncryptedEnvelope {
        var salt = [UInt8](repeating: 0, count: 16)
        guard SecRandomCopyBytes(kSecRandomDefault, salt.count, &salt) == errSecSuccess else {
            throw WatchWalletVaultError.encryptionFailed
        }
        let saltData = Data(salt)
        let key = try derivedKey(passcode: passcode, salt: saltData)
        let box = try AES.GCM.seal(plaintext, using: key)
        return WatchEncryptedEnvelope(
            version: 1,
            salt: saltData,
            nonce: box.nonce.withUnsafeBytes { Data($0) },
            ciphertext: box.ciphertext,
            tag: box.tag
        )
    }

    static func open(
        _ envelope: WatchEncryptedEnvelope,
        passcode: String
    ) throws -> Data {
        guard envelope.version == 1 else {
            throw WatchWalletVaultError.encryptionFailed
        }
        do {
            let box = try AES.GCM.SealedBox(
                nonce: AES.GCM.Nonce(data: envelope.nonce),
                ciphertext: envelope.ciphertext,
                tag: envelope.tag
            )
            return try AES.GCM.open(
                box,
                using: derivedKey(passcode: passcode, salt: envelope.salt)
            )
        } catch let error as WatchWalletVaultError {
            throw error
        } catch {
            throw WatchWalletVaultError.invalidPasscode
        }
    }

    private static func derivedKey(
        passcode: String,
        salt: Data
    ) throws -> SymmetricKey {
        let password = Array(passcode.utf8)
        let saltBytes = Array(salt.base64EncodedString().utf8)
        var output = [UInt8](repeating: 0, count: 32)
        let status = password.withUnsafeBufferPointer { passwordBuffer in
            saltBytes.withUnsafeBufferPointer { saltBuffer in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordBuffer.baseAddress?.withMemoryRebound(
                        to: Int8.self,
                        capacity: passwordBuffer.count,
                        { $0 }
                    ),
                    passwordBuffer.count,
                    saltBuffer.baseAddress,
                    saltBuffer.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA512),
                    derivationRounds,
                    &output,
                    output.count
                )
            }
        }
        guard status == kCCSuccess else {
            throw WatchWalletVaultError.keyDerivationFailed
        }
        return SymmetricKey(data: output)
    }
}

struct WatchEncryptedEnvelope: Codable, Equatable, Sendable {
    let version: Int
    let salt: Data
    let nonce: Data
    let ciphertext: Data
    let tag: Data
}
