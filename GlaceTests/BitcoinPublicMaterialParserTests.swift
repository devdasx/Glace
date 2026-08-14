import Foundation
import Testing
#if SWIFT_PACKAGE
@testable import GlaceCore
#else
@testable import Glace
#endif

struct BitcoinPublicMaterialParserTests {
    @Test
    func parsesBase58AddressFamilies() throws {
        let legacy = try parseAddress("1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa")
        #expect(legacy.materialKind == .legacyAddress)
        #expect(legacy.network == .mainnet)

        let scriptHash = try parseAddress("3J98t1WpEZ73CNmQviecrnyiWrnqRhWNLy")
        #expect(scriptHash.materialKind == .scriptHashAddress)
        #expect(scriptHash.network == .mainnet)
    }

    @Test
    func parsesPublishedBech32AndBech32mVectors() throws {
        let nativeSegWit = try parseAddress(
            "BC1QW508D6QEJXTDG4Y5R3ZARVARY0C5XW7KV8F3T4"
        )
        #expect(nativeSegWit.materialKind == .nativeSegWitAddress)
        #expect(nativeSegWit.network == .mainnet)

        let taproot = try parseAddress(
            "bc1p0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7vqzk5jj0"
        )
        #expect(taproot.materialKind == .taprootAddress)
        #expect(taproot.network == .mainnet)
    }

    @Test
    func parsesBIP32MasterPublicKeyVector() throws {
        let record = try BitcoinPublicMaterialParser.parse(
            value: "xpub661MyMwAqRbcFtXgS5sYJABqqG9YLmC4Q1Rdap9gSE8NqtwybGhePY2gZ29ESFjqJoCu1Rupje8YtGqsefD265TMg7usUDFdp6W1EGMcet8",
            importKind: .extendedPublicKey,
            walletStandard: .legacyBIP44
        )
        #expect(record.materialKind == .standardExtendedPublicKey)
        #expect(record.network == .mainnet)
    }

    @Test
    func standardXpubRequiresExplicitWalletStandard() {
        #expect(throws: BitcoinPublicMaterialError.self) {
            _ = try BitcoinPublicMaterialParser.parse(
                value: "xpub661MyMwAqRbcFtXgS5sYJABqqG9YLmC4Q1Rdap9gSE8NqtwybGhePY2gZ29ESFjqJoCu1Rupje8YtGqsefD265TMg7usUDFdp6W1EGMcet8",
                importKind: .extendedPublicKey,
                walletStandard: nil
            )
        }
    }

    @Test
    func rejectsBadAddressChecksum() {
        #expect(throws: BitcoinPublicMaterialError.self) {
            _ = try parseAddress("1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNb")
        }
    }

    @Test
    func rejectsTestnetAddressesAndExtendedPublicKeys() throws {
        #expect(throws: BitcoinPublicMaterialError.self) {
            _ = try parseAddress("mipcBbFg9gMiCh81Kj8tqqdgoZub1ZJRfn")
        }

        let xpub = "xpub661MyMwAqRbcFtXgS5sYJABqqG9YLmC4Q1Rdap9gSE8NqtwybGhePY2gZ29ESFjqJoCu1Rupje8YtGqsefD265TMg7usUDFdp6W1EGMcet8"
        var payload = try BitcoinPublicEncoding.base58CheckDecode(xpub)
        payload.replaceSubrange(0..<4, with: [0x04, 0x35, 0x87, 0xcf])
        let tpub = BitcoinPublicEncoding.base58CheckEncode(payload)

        #expect(throws: BitcoinPublicMaterialError.self) {
            _ = try BitcoinPublicMaterialParser.parse(
                value: tpub,
                importKind: .extendedPublicKey,
                walletStandard: .legacyBIP44
            )
        }
    }

    @Test
    func encryptedEnvelopeRejectsWrongPasscode() throws {
        let plaintext = Data("public wallet record".utf8)
        let envelope = try WatchWalletVault.seal(
            plaintext,
            passcode: "123456"
        )
        #expect(
            try WatchWalletVault.open(envelope, passcode: "123456")
                == plaintext
        )
        #expect(throws: WatchWalletVaultError.self) {
            _ = try WatchWalletVault.open(envelope, passcode: "654321")
        }
    }

    private func parseAddress(_ address: String) throws -> WatchWalletRecord {
        try BitcoinPublicMaterialParser.parse(
            value: address,
            importKind: .address,
            walletStandard: nil
        )
    }
}
