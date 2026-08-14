import Foundation
import P256K

enum BitcoinNetwork: String, Codable, Hashable, Sendable {
    case mainnet
    case testnet
}

enum WatchImportKind: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case address
    case extendedPublicKey

    var id: Self { self }
}

enum WatchWalletStandard: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case legacyBIP44
    case nestedSegWitBIP49
    case nativeSegWitBIP84
    case taprootBIP86
    case nestedSegWitMultisig
    case nativeSegWitMultisig

    var id: Self { self }
}

enum BitcoinPublicMaterialKind: String, Codable, Hashable, Sendable {
    case legacyAddress
    case scriptHashAddress
    case nativeSegWitAddress
    case nativeSegWitScriptAddress
    case taprootAddress
    case witnessAddress
    case standardExtendedPublicKey
    case nestedSegWitExtendedPublicKey
    case nativeSegWitExtendedPublicKey
    case nestedMultisigExtendedPublicKey
    case nativeMultisigExtendedPublicKey
}

enum BitcoinPublicMaterialError: Error, Equatable {
    case empty
    case invalidAddress
    case invalidExtendedPublicKey
    case ambiguousExtendedPublicKey
    case invalidDerivationPath
}

struct WatchWalletRecord: Codable, Equatable, Sendable {
    let importedValue: String
    let importKind: WatchImportKind
    let materialKind: BitcoinPublicMaterialKind
    let network: BitcoinNetwork
    let walletStandard: WatchWalletStandard?
    let walletName: String
    let derivationPath: String
    let gapLimit: Int
}

enum BitcoinPublicMaterialParser {
    static func parse(
        value: String,
        importKind: WatchImportKind,
        walletName: String,
        derivationPath: String,
        gapLimit: Int,
        walletStandard: WatchWalletStandard?
    ) throws -> WatchWalletRecord {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            throw BitcoinPublicMaterialError.empty
        }
        guard derivationPath.isEmpty || isValidDerivationPath(derivationPath) else {
            throw BitcoinPublicMaterialError.invalidDerivationPath
        }

        let parsed: (
            kind: BitcoinPublicMaterialKind,
            network: BitcoinNetwork,
            walletStandard: WatchWalletStandard?
        )
        switch importKind {
        case .address:
            let address = try parseAddress(value)
            parsed = (address.0, address.1, nil)
        case .extendedPublicKey:
            parsed = try parseExtendedPublicKey(
                value,
                selectedStandard: walletStandard
            )
        }

        return WatchWalletRecord(
            importedValue: value,
            importKind: importKind,
            materialKind: parsed.kind,
            network: parsed.network,
            walletStandard: parsed.walletStandard,
            walletName: walletName.trimmingCharacters(in: .whitespacesAndNewlines),
            derivationPath: derivationPath.trimmingCharacters(in: .whitespacesAndNewlines),
            gapLimit: min(max(gapLimit, 1), 1_000)
        )
    }

    private static func parseAddress(
        _ value: String
    ) throws -> (BitcoinPublicMaterialKind, BitcoinNetwork) {
        if let payload = try? BitcoinPublicEncoding.base58CheckDecode(value),
           payload.count == 21 {
            switch payload[0] {
            case 0x00: return (.legacyAddress, .mainnet)
            case 0x05: return (.scriptHashAddress, .mainnet)
            case 0x6f: return (.legacyAddress, .testnet)
            case 0xc4: return (.scriptHashAddress, .testnet)
            default: break
            }
        }

        do {
            let decoded = try BitcoinPublicEncoding.decodeSegWitAddress(value)
            let network: BitcoinNetwork
            switch decoded.humanReadablePart {
            case "bc": network = .mainnet
            case "tb": network = .testnet
            default: throw BitcoinPublicMaterialError.invalidAddress
            }

            switch (decoded.witnessVersion, decoded.witnessProgram.count) {
            case (0, 20): return (.nativeSegWitAddress, network)
            case (0, 32): return (.nativeSegWitScriptAddress, network)
            case (1, 32): return (.taprootAddress, network)
            default: return (.witnessAddress, network)
            }
        } catch {
            throw BitcoinPublicMaterialError.invalidAddress
        }
    }

    private static func parseExtendedPublicKey(
        _ value: String,
        selectedStandard: WatchWalletStandard?
    ) throws -> (
        kind: BitcoinPublicMaterialKind,
        network: BitcoinNetwork,
        walletStandard: WatchWalletStandard
    ) {
        let payload: Data
        do {
            payload = try BitcoinPublicEncoding.base58CheckDecode(value)
        } catch {
            throw BitcoinPublicMaterialError.invalidExtendedPublicKey
        }
        guard payload.count == 78,
              let version = try? BitcoinPublicEncoding.uint32(Data(payload[0..<4])),
              let versionInfo = extendedPublicVersions[version] else {
            throw BitcoinPublicMaterialError.invalidExtendedPublicKey
        }

        let depth = payload[4]
        if depth == 0 {
            guard payload[5..<13].allSatisfy({ $0 == 0 }) else {
                throw BitcoinPublicMaterialError.invalidExtendedPublicKey
            }
        }

        let keyData = Data(payload[45..<78])
        do {
            _ = try P256K.Signing.PublicKey(
                dataRepresentation: keyData,
                format: .compressed
            )
        } catch {
            throw BitcoinPublicMaterialError.invalidExtendedPublicKey
        }
        let standard: WatchWalletStandard
        if let inferredStandard = versionInfo.inferredStandard {
            standard = inferredStandard
        } else {
            guard let selectedStandard else {
                throw BitcoinPublicMaterialError.ambiguousExtendedPublicKey
            }
            standard = selectedStandard
        }
        return (versionInfo.kind, versionInfo.network, standard)
    }

    private static func isValidDerivationPath(_ value: String) -> Bool {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = normalized.split(separator: "/", omittingEmptySubsequences: false)
        guard let root = components.first, root == "m" || root == "M" else {
            return false
        }
        if components.count == 1 {
            return true
        }

        return components.dropFirst().allSatisfy { component in
            guard !component.isEmpty else {
                return false
            }
            var number = String(component)
            if let suffix = number.last, suffix == "'" || suffix == "h" || suffix == "H" {
                number.removeLast()
            }
            guard let index = UInt32(number), index < 0x8000_0000 else {
                return false
            }
            return true
        }
    }

    private struct VersionInfo {
        let kind: BitcoinPublicMaterialKind
        let network: BitcoinNetwork
        let inferredStandard: WatchWalletStandard?
    }

    private static let extendedPublicVersions: [UInt32: VersionInfo] = [
        0x0488_b21e: VersionInfo(kind: .standardExtendedPublicKey, network: .mainnet, inferredStandard: nil),
        0x049d_7cb2: VersionInfo(kind: .nestedSegWitExtendedPublicKey, network: .mainnet, inferredStandard: .nestedSegWitBIP49),
        0x04b2_4746: VersionInfo(kind: .nativeSegWitExtendedPublicKey, network: .mainnet, inferredStandard: .nativeSegWitBIP84),
        0x0295_b43f: VersionInfo(kind: .nestedMultisigExtendedPublicKey, network: .mainnet, inferredStandard: .nestedSegWitMultisig),
        0x02aa_7ed3: VersionInfo(kind: .nativeMultisigExtendedPublicKey, network: .mainnet, inferredStandard: .nativeSegWitMultisig),
        0x0435_87cf: VersionInfo(kind: .standardExtendedPublicKey, network: .testnet, inferredStandard: nil),
        0x044a_5262: VersionInfo(kind: .nestedSegWitExtendedPublicKey, network: .testnet, inferredStandard: .nestedSegWitBIP49),
        0x045f_1cf6: VersionInfo(kind: .nativeSegWitExtendedPublicKey, network: .testnet, inferredStandard: .nativeSegWitBIP84),
        0x0242_89ef: VersionInfo(kind: .nestedMultisigExtendedPublicKey, network: .testnet, inferredStandard: .nestedSegWitMultisig),
        0x0257_5483: VersionInfo(kind: .nativeMultisigExtendedPublicKey, network: .testnet, inferredStandard: .nativeSegWitMultisig)
    ]
}
