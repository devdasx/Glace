import Foundation
import P256K

enum BitcoinNetwork: String, Codable, Hashable, Sendable {
    case mainnet
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

    static let userSelectableCases: [Self] = [
        .legacyBIP44,
        .nestedSegWitBIP49,
        .nativeSegWitBIP84,
        .taprootBIP86
    ]

    static let automaticDiscoveryOrder: [Self] = [
        .nativeSegWitBIP84,
        .taprootBIP86,
        .nestedSegWitBIP49,
        .legacyBIP44
    ]
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
}

struct WatchWalletRecord: Codable, Equatable, Sendable {
    let importedValue: String
    let importKind: WatchImportKind
    let materialKind: BitcoinPublicMaterialKind
    let network: BitcoinNetwork
    let walletStandard: WatchWalletStandard?
    let candidateWalletStandards: [WatchWalletStandard]

    init(
        importedValue: String,
        importKind: WatchImportKind,
        materialKind: BitcoinPublicMaterialKind,
        network: BitcoinNetwork,
        walletStandard: WatchWalletStandard?,
        candidateWalletStandards: [WatchWalletStandard]
    ) {
        self.importedValue = importedValue
        self.importKind = importKind
        self.materialKind = materialKind
        self.network = network
        self.walletStandard = walletStandard
        self.candidateWalletStandards = candidateWalletStandards
    }

    private enum CodingKeys: String, CodingKey {
        case importedValue
        case importKind
        case materialKind
        case network
        case walletStandard
        case candidateWalletStandards
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        importedValue = try container.decode(String.self, forKey: .importedValue)
        importKind = try container.decode(WatchImportKind.self, forKey: .importKind)
        materialKind = try container.decode(BitcoinPublicMaterialKind.self, forKey: .materialKind)
        network = try container.decode(BitcoinNetwork.self, forKey: .network)
        walletStandard = try container.decodeIfPresent(
            WatchWalletStandard.self,
            forKey: .walletStandard
        )
        candidateWalletStandards = try container.decodeIfPresent(
            [WatchWalletStandard].self,
            forKey: .candidateWalletStandards
        ) ?? walletStandard.map { [$0] } ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(importedValue, forKey: .importedValue)
        try container.encode(importKind, forKey: .importKind)
        try container.encode(materialKind, forKey: .materialKind)
        try container.encode(network, forKey: .network)
        try container.encodeIfPresent(walletStandard, forKey: .walletStandard)
        try container.encode(
            candidateWalletStandards,
            forKey: .candidateWalletStandards
        )
    }
}

enum BitcoinPublicMaterialParser {
    static func parse(
        value: String,
        importKind: WatchImportKind,
        walletStandard: WatchWalletStandard?
    ) throws -> WatchWalletRecord {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            throw BitcoinPublicMaterialError.empty
        }
        let parsed: (
            kind: BitcoinPublicMaterialKind,
            network: BitcoinNetwork,
            walletStandards: [WatchWalletStandard]
        )
        switch importKind {
        case .address:
            let address = try parseAddress(value)
            parsed = (address.0, address.1, [])
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
            walletStandard: parsed.walletStandards.first,
            candidateWalletStandards: parsed.walletStandards
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
            default: break
            }
        }

        do {
            let decoded = try BitcoinPublicEncoding.decodeSegWitAddress(value)
            guard decoded.humanReadablePart == "bc" else {
                throw BitcoinPublicMaterialError.invalidAddress
            }

            switch (decoded.witnessVersion, decoded.witnessProgram.count) {
            case (0, 20): return (.nativeSegWitAddress, .mainnet)
            case (0, 32): return (.nativeSegWitScriptAddress, .mainnet)
            case (1, 32): return (.taprootAddress, .mainnet)
            default: return (.witnessAddress, .mainnet)
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
        walletStandards: [WatchWalletStandard]
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
        let standards: [WatchWalletStandard]
        if let selectedStandard {
            // An explicit user choice always overrides prefix inference.
            standards = [selectedStandard]
        } else if let inferredStandard = versionInfo.inferredStandard {
            standards = [inferredStandard]
        } else {
            // xpub does not encode its script standard. Keep every supported
            // single-signature interpretation available for discovery.
            standards = WatchWalletStandard.automaticDiscoveryOrder
        }
        return (versionInfo.kind, versionInfo.network, standards)
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
        0x02aa_7ed3: VersionInfo(kind: .nativeMultisigExtendedPublicKey, network: .mainnet, inferredStandard: .nativeSegWitMultisig)
    ]
}
