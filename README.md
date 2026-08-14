# Glace: Bitcoin Wallet - BTC

Glace is a Bitcoin-only native iOS wallet project built around two strictly separated applications:

- A watch-only app that imports public Bitcoin addresses, public keys, extended public keys, and supported wallet descriptors without handling private keys or seed phrases.
- A future offline app dedicated to signing Bitcoin transactions in an isolated environment.

The first development phase will focus exclusively on the watch-only app.

## Project status

Glace is in early design and development. The native iOS project currently contains coordinated onboarding experiences for the watch-only wallet and the separate offline signer. Wallet import, secret handling, transaction exchange, and Bitcoin signing have not been implemented yet. No release or usable wallet is available. Do not use this repository or any unofficial artifact to secure real funds.

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
xcodebuild -project Glace.xcodeproj -scheme GlaceSigner -destination 'generic/platform=iOS Simulator' build
```

The app currently has no third-party runtime dependencies. Simulator builds verify compilation and layout behavior; the meaning and physical feel of haptic feedback must also be checked on supported hardware before release.

## Security

The watch-only application will never request or store seed phrases, private keys, WIF keys, or other signing secrets. The signing application is a separate product and security boundary intended for a permanently disconnected device. Its current onboarding is a design prototype only; it does not yet import, protect, derive, or use secret material.

No software can honestly guarantee absolute safety. Future Glace releases must state exactly what was verified, publish the available verification evidence, and disclose residual risks and any Apple-controlled build or distribution steps that cannot be reproduced independently.
