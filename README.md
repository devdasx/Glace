# Glace: Bitcoin Wallet - BTC

Glace is the online, watch-only half of a two-application Bitcoin wallet for native iOS. It will import public Bitcoin addresses, public keys, extended public keys, and supported output descriptors without ever requesting or handling signing secrets.

Its independent companion is [Glace Signer: Offline Bitcoin Signer - BTC](https://github.com/devdasx/Glace-Signer), which is designed to review and sign Bitcoin transactions on a separate, disconnected iOS device. The repositories, application targets, bundle identifiers, and security responsibilities remain independent.

## Project status

Glace is in early design and development. This repository currently contains the native onboarding experience for the watch-only app. Wallet import, balance monitoring, transaction construction, PSBT exchange, broadcasting, and the companion signing workflow have not been implemented yet. No release or usable wallet is available. Do not use this repository or any unofficial artifact to secure real funds.

## How the two apps complement each other

The planned workflow preserves an explicit air gap:

1. Glace imports public wallet data, monitors Bitcoin, and prepares an unsigned Partially Signed Bitcoin Transaction (PSBT).
2. The unsigned PSBT is transferred manually to Glace Signer without transferring any seed phrase or private key.
3. Glace Signer independently displays the transaction for human review and signs it while offline.
4. Only the signed result is returned to Glace, which verifies it before any network broadcast.

Interoperability will use standardized Bitcoin PSBT data, with BIP174 and BIP370 compatibility evaluated and tested before implementation. The air-gap encoding and transport have not been selected or implemented yet; neither app currently exchanges transaction data.

## Core principles

- Bitcoin only, with comprehensive support planned for established address, script, public-key, and derivation standards, including BIP32, BIP44, BIP49, BIP84, and BIP86.
- Native iOS 26 interfaces built with current Apple frameworks and Swift APIs.
- Localization-ready UI with English source strings first, native LTR/RTL behavior, adaptive iPhone/iPad layouts, Dynamic Type, and complete light/dark appearance support.
- Deliberate, restrained interaction design with meaningful animation, accessibility, and semantic haptic feedback.
- Public source history and a verifiable release process designed to connect future binaries to exact source revisions, build inputs, signatures, provenance, and checksums.

## Development build

The current project is generated and verified with:

- Xcode 26.6 (`17F113`)
- Apple Swift 6.3.3
- XcodeGen 2.45.4
- iOS 26.0 deployment target

Generate and build the project from a clean checkout:

```sh
xcodegen generate --spec project.yml
xcodebuild -project Glace.xcodeproj -scheme Glace -destination 'generic/platform=iOS Simulator' build
```

The app currently has no third-party runtime dependencies. Simulator builds verify compilation and layout behavior; the meaning and physical feel of haptic feedback must also be checked on supported hardware before release.

## Security

Glace will never request, derive, store, or transmit seed phrases, private keys, WIF keys, extended private keys, or other signing secrets. Signing belongs exclusively to the separate Glace Signer repository and application. Public wallet data and unsigned or signed PSBTs are not secrets, but they can expose financial privacy and must still be validated and protected appropriately.

No software can honestly guarantee absolute safety. Future Glace releases must state exactly what was verified, publish the available verification evidence, and disclose residual risks and any Apple-controlled build or distribution steps that cannot be reproduced independently.
