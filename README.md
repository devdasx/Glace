# Glace: Bitcoin Wallet - BTC

Glace is the online, watch-only half of a two-application Bitcoin wallet for native iOS. Its current setup flow imports supported public Bitcoin addresses and extended public keys without requesting or handling signing secrets.

Its independent companion is [Glace Signer: Offline Bitcoin Signer - BTC](https://github.com/devdasx/Glace-Signer), which is designed to review and sign Bitcoin transactions on a separate, disconnected iOS device. The repositories, application targets, bundle identifiers, and security responsibilities remain independent.

## Project status

Glace is in early development. The repository now implements the complete first-time watch-only setup slice:

- Native onboarding followed by separate Set Passcode and Confirm Passcode screens with a six-digit, LTR, ASCII keypad.
- Local checksum and structure validation for supported mainnet and testnet Base58, Bech32, and Bech32m addresses.
- Validation for standard BIP32 and supported SLIP-132 extended-public-key versions, including `xpub`, `tpub`, `ypub`, `upub`, `zpub`, `vpub`, and their supported multisignature variants.
- Explicit wallet-standard selection for ambiguous `xpub` and `tpub` data, so BIP44, BIP49, BIP84, BIP86, and supported multisignature semantics are not guessed.
- Advanced public metadata for a local wallet name, optional BIP32 origin path, and address gap limit.
- AES-GCM protection derived from the confirmed passcode and this-device-only Keychain persistence, followed by an import summary and success screen.

Glace deliberately does not accept a BIP39 passphrase. A passphrase changes signing keys and belongs only in Glace Signer; this app imports the resulting public account key instead.

Balance monitoring, address derivation from imported account keys, transaction construction, PSBT exchange, broadcasting, wallet unlocking, migration, backup, and release distribution are not implemented yet. There is no production release or independently audited wallet. Do not use this repository or an unofficial artifact to secure real funds.

## Visual identity

<img src="Brand/GlaceBrandMark.svg" alt="Glace brand mark: a blue open geometric G without a background" width="144">

Glace and Glace Signer share the same bold, open geometric `G`, making them immediately recognizable as two parts of one Bitcoin wallet. The watch-only app uses the standalone mark in blue; the companion signer uses the identical mark in black. Both applications intentionally stay in native iOS light appearance. The background-free [brand-mark master](Brand/GlaceBrandMark.svg) is rendered directly in onboarding, while the opaque [app-icon master](Brand/GlaceAppIcon.svg) satisfies the iOS application-icon requirements.

## How the two apps complement each other

The planned workflow preserves an explicit air gap:

1. Glace imports public wallet data, monitors Bitcoin, and prepares an unsigned Partially Signed Bitcoin Transaction (PSBT).
2. The unsigned PSBT is transferred manually to Glace Signer without transferring any seed phrase or private key.
3. Glace Signer independently displays the transaction for human review and signs it while offline.
4. Only the signed result is returned to Glace, which verifies it before any network broadcast.

Interoperability will use standardized Bitcoin PSBT data, with BIP174 and BIP370 compatibility evaluated and tested before implementation. The air-gap encoding and transport have not been selected or implemented yet; neither app currently exchanges transaction data.

## Core principles

- Bitcoin only, with comprehensive support planned for established address, script, public-key, and derivation standards, including BIP32, BIP44, BIP49, BIP84, and BIP86.
- Native iOS 26 interfaces built only with Apple UI frameworks and current Swift APIs. Reviewed external packages may be used only below the interface for Bitcoin or security-critical core work.
- Localization-ready UI with English source strings first, native LTR/RTL behavior, adaptive iPhone/iPad layouts, Dynamic Type, and a deliberate native light-only appearance.
- Apple system typography throughout, with the native rounded San Francisco design reserved for titles and headings.
- Deliberate, restrained interaction design with meaningful animation, accessibility, and semantic haptic feedback.
- Public source history and a verifiable release process designed to connect future binaries to exact source revisions, build inputs, signatures, provenance, and checksums.

## Development build

The current project is generated and verified with:

- Xcode 26.6 (`17F113`)
- Apple Swift 6.3.3
- XcodeGen 2.45.4
- iOS 26.0 deployment target

The reproducible core-test manifest and Xcode project both pin `swift-secp256k1` 0.23.2. It is used only to validate secp256k1 extended-public-key material; it provides no app UI or runtime network client. Both `Package.resolved` files record the resolved upstream revision.

Run the deterministic Bitcoin and encrypted-vault checks without Simulator:

```sh
swift test
```

Generate the Xcode project and compile the app plus its iOS unit-test target for a generic device:

```sh
xcodegen generate --spec project.yml
xcodebuild -project Glace.xcodeproj -scheme Glace -sdk iphoneos -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build-for-testing
```

The host suite currently executes six focused checks for published address vectors, BIP32 public-key parsing, checksums, standard ambiguity, path validation, and wrong-passcode authenticated-decryption failure. The Xcode command performs a compile-only generic iOS build without booting Simulator. Runtime layout and interaction validation remains with the project owner, and haptic timing must be checked on supported physical hardware before release.

## Security

Glace must never request, derive, store, or transmit seed phrases, BIP39 passphrases, private keys, WIF keys, extended private keys, or other signing secrets. Signing belongs exclusively to the separate Glace Signer repository and application. Public wallet data and future unsigned or signed PSBTs are not signing secrets, but they can expose financial privacy and must still be validated and protected appropriately.

The current vault uses PBKDF2-HMAC-SHA512 with 210,000 rounds, a random salt, AES-GCM authenticated encryption, and `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. This implementation and its six-digit passcode threat model have not received an independent security audit. A source build passing the included vectors is evidence for those tested behaviors, not proof that the app is safe for funds.

No software can honestly guarantee absolute safety. Future Glace releases must state exactly what was verified, publish the available verification evidence, and disclose residual risks and any Apple-controlled build or distribution steps that cannot be reproduced independently.
