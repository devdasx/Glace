import SwiftUI

struct WatchSetupFlowView: View {
    @State private var path = [WatchSetupRoute]()
    @State private var pendingPasscode = ""
    @State private var showsPasscodeMismatch = false
    @State private var draft = WatchImportDraft()
    @State private var importedRecord: WatchWalletRecord?

    var body: some View {
        NavigationStack(path: $path) {
            OnboardingView {
                pendingPasscode = ""
                showsPasscodeMismatch = false
                draft = WatchImportDraft()
                importedRecord = nil
                path.append(.setPasscode)
            }
            .navigationDestination(for: WatchSetupRoute.self) { route in
                switch route {
                case .setPasscode:
                    PasscodeSetupView(
                        mode: .creation,
                        showsPreviousMismatch: showsPasscodeMismatch,
                        onSubmit: { passcode in
                            let confirmation = PasscodeConfirmation(
                                expectedPasscode: passcode
                            )
                            pendingPasscode = passcode
                            showsPasscodeMismatch = false
                            path.append(.confirmPasscode(confirmation))
                        }
                    )

                case let .confirmPasscode(confirmation):
                    PasscodeSetupView(
                        mode: .confirmation(confirmation),
                        onMismatch: resetPasscodeAfterMismatch,
                        onSubmit: { passcode in
                            pendingPasscode = passcode
                            showsPasscodeMismatch = false
                            removeCompletedPasscodeRoutes()
                            path.append(.importWallet)
                        }
                    )

                case .importWallet:
                    WatchWalletImportView(draft: $draft) {
                        importWallet()
                    }

                case .success:
                    if let importedRecord {
                        WatchWalletImportSuccessView(record: importedRecord) {
                            finish()
                        }
                    } else {
                        WatchWalletImportFailureView {
                            restart()
                        }
                    }
                }
            }
        }
    }

    private func resetPasscodeAfterMismatch() {
        guard let currentRoute = path.last,
              case .confirmPasscode = currentRoute else {
            return
        }

        pendingPasscode = ""
        showsPasscodeMismatch = true
        path.removeLast()
    }

    private func removeCompletedPasscodeRoutes() {
        guard let currentRoute = path.last,
              case .confirmPasscode = currentRoute else {
            return
        }

        path.removeLast()
        if path.last == .setPasscode {
            path.removeLast()
        }
    }

    private func importWallet() {
        do {
            let record = try BitcoinPublicMaterialParser.parse(
                value: draft.publicMaterial,
                importKind: draft.importKind,
                walletName: draft.walletName,
                derivationPath: draft.derivationPath,
                gapLimit: draft.gapLimit,
                walletStandard: draft.walletStandard
            )
            try WatchWalletVault.save(record, passcode: pendingPasscode)
            pendingPasscode = ""
            draft.validationError = nil
            draft.publicMaterial = ""
            importedRecord = record
            path.append(.success)
        } catch let error as BitcoinPublicMaterialError {
            switch error {
            case .empty:
                draft.validationError = .empty
            case .invalidAddress:
                draft.validationError = .address
            case .invalidExtendedPublicKey:
                draft.validationError = .extendedPublicKey
            case .ambiguousExtendedPublicKey:
                draft.validationError = .extendedPublicKeyStandard
            case .invalidDerivationPath:
                draft.validationError = .derivationPath
            }
        } catch {
            draft.validationError = .secureStorage
        }
    }

    private func restart() {
        pendingPasscode = ""
        showsPasscodeMismatch = false
        draft = WatchImportDraft()
        importedRecord = nil
        path.removeAll()
    }

    private func finish() {
        pendingPasscode = ""
        showsPasscodeMismatch = false
        draft = WatchImportDraft()
        importedRecord = nil
        path.removeAll()
    }
}

private enum WatchSetupRoute: Hashable {
    case setPasscode
    case confirmPasscode(PasscodeConfirmation)
    case importWallet
    case success
}

struct WatchImportDraft {
    var importKind: WatchImportKind = .address
    var publicMaterial = ""
    var walletName = ""
    var derivationPath = ""
    var gapLimit = 20
    var walletStandard: WatchWalletStandard?
    var showsAdvancedSettings = false
    var validationError: WatchImportValidationError?
}

enum WatchImportValidationError: Hashable {
    case empty
    case address
    case extendedPublicKey
    case extendedPublicKeyStandard
    case derivationPath
    case secureStorage

    var localizedKey: LocalizedStringKey {
        switch self {
        case .empty: "watch.import.error.empty"
        case .address: "watch.import.error.address"
        case .extendedPublicKey: "watch.import.error.extended_public_key"
        case .extendedPublicKeyStandard: "watch.import.error.extended_public_key_standard"
        case .derivationPath: "watch.import.error.derivation_path"
        case .secureStorage: "watch.import.error.secure_storage"
        }
    }
}

private struct WatchWalletImportView: View {
    @Binding var draft: WatchImportDraft
    let onImport: () -> Void

    var body: some View {
        Form {
            Section {
                Text("watch.import.title")
                    .font(.largeTitle.bold())
                    .fontDesign(.rounded)

                Text("watch.import.body")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                Picker("watch.import.type.label", selection: $draft.importKind) {
                    ForEach(WatchImportKind.allCases) { kind in
                        Text(kind.titleKey).tag(kind)
                    }
                }
                .pickerStyle(.navigationLink)
            } header: {
                Text("watch.import.type.section")
                    .fontDesign(.rounded)
            }

            Section {
                TextField(inputPlaceholderKey, text: $draft.publicMaterial)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .environment(\.layoutDirection, .leftToRight)
            } header: {
                Text(draft.importKind.titleKey)
                    .fontDesign(.rounded)
            } footer: {
                Text(draft.importKind.helpKey)
            }

            DisclosureGroup(
                isExpanded: $draft.showsAdvancedSettings
            ) {
                TextField("watch.import.wallet_name.placeholder", text: $draft.walletName)

                if draft.importKind == .extendedPublicKey {
                    TextField(
                        "watch.import.derivation.placeholder",
                        text: $draft.derivationPath
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .environment(\.layoutDirection, .leftToRight)

                    Stepper(
                        value: $draft.gapLimit,
                        in: 1...1_000,
                        step: 1
                    ) {
                        LabeledContent("watch.import.gap_limit.label") {
                            Text(draft.gapLimit, format: .number)
                        }
                    }

                    Picker(
                        "watch.import.wallet_standard.label",
                        selection: $draft.walletStandard
                    ) {
                        Text("watch.import.wallet_standard.unspecified")
                            .tag(nil as WatchWalletStandard?)
                        ForEach(WatchWalletStandard.allCases) { standard in
                            Text(standard.titleKey).tag(Optional(standard))
                        }
                    }

                    Text("watch.import.wallet_standard.note")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("watch.import.passphrase.title")
                        .font(.headline)
                        .fontDesign(.rounded)
                    Text("watch.import.passphrase.body")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            } label: {
                Text("watch.import.advanced.title")
                    .font(.headline)
                    .fontDesign(.rounded)
            }

            if let validationError = draft.validationError {
                Section {
                    Text(validationError.localizedKey)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaBar(edge: .bottom, spacing: 0) {
            Button {
                onImport()
            } label: {
                Text("watch.import.action.import")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(
                draft.publicMaterial
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty
            )
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
        }
        .sensoryFeedback(.selection, trigger: draft.importKind)
        .sensoryFeedback(.error, trigger: draft.validationError)
        .onChange(of: draft.importKind) { _, _ in
            draft.publicMaterial = ""
            draft.derivationPath = ""
            draft.walletStandard = nil
            draft.validationError = nil
        }
        .onChange(of: draft.publicMaterial) { _, _ in
            draft.validationError = nil
        }
    }

    private var inputPlaceholderKey: LocalizedStringKey {
        switch draft.importKind {
        case .address: "watch.import.address.placeholder"
        case .extendedPublicKey: "watch.import.extended_public_key.placeholder"
        }
    }
}

private struct WatchWalletImportSuccessView: View {
    @State private var successFeedback = 0

    let record: WatchWalletRecord
    let onDone: () -> Void

    var body: some View {
        Form {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.green)
                        .accessibilityHidden(true)

                    VStack(spacing: 8) {
                        Text("watch.success.title")
                            .font(.largeTitle.bold())
                            .fontDesign(.rounded)
                            .multilineTextAlignment(.center)

                        Text("watch.success.body")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }

            Section {
                LabeledContent("watch.success.network.label") {
                    Text(record.network.titleKey)
                }

                LabeledContent("watch.success.type.label") {
                    Text(record.materialKind.titleKey)
                }

                if let walletStandard = record.walletStandard {
                    LabeledContent("watch.success.standard.label") {
                        Text(walletStandard.titleKey)
                    }
                }

                if !record.walletName.isEmpty {
                    LabeledContent("watch.success.name.label") {
                        Text(verbatim: record.walletName)
                    }
                }

                Text(verbatim: record.importedValue)
                    .font(.footnote.monospaced())
                    .textSelection(.enabled)
                    .environment(\.layoutDirection, .leftToRight)
            } header: {
                Text("watch.success.summary.section")
                    .fontDesign(.rounded)
            }
        }
        .navigationBarBackButtonHidden(true)
        .safeAreaBar(edge: .bottom, spacing: 0) {
            Button {
                onDone()
            } label: {
                Text("watch.success.action.done")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
        }
        .sensoryFeedback(.success, trigger: successFeedback)
        .onAppear {
            successFeedback += 1
        }
    }
}

private struct WatchWalletImportFailureView: View {
    @State private var errorFeedback = 0

    let onRestart: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label {
                Text("watch.failure.title")
                    .fontDesign(.rounded)
            } icon: {
                Image(systemName: "exclamationmark.triangle")
            }
        } description: {
            Text("watch.failure.body")
        } actions: {
            Button("watch.failure.action.restart", action: onRestart)
        }
        .navigationBarBackButtonHidden(true)
        .sensoryFeedback(.error, trigger: errorFeedback)
        .onAppear {
            errorFeedback += 1
        }
    }
}

private extension WatchImportKind {
    var titleKey: LocalizedStringKey {
        switch self {
        case .address: "watch.import.type.address"
        case .extendedPublicKey: "watch.import.type.extended_public_key"
        }
    }

    var helpKey: LocalizedStringKey {
        switch self {
        case .address: "watch.import.help.address"
        case .extendedPublicKey: "watch.import.help.extended_public_key"
        }
    }
}

private extension BitcoinNetwork {
    var titleKey: LocalizedStringKey {
        switch self {
        case .mainnet: "bitcoin.network.mainnet"
        case .testnet: "bitcoin.network.testnet"
        }
    }
}

private extension BitcoinPublicMaterialKind {
    var titleKey: LocalizedStringKey {
        switch self {
        case .legacyAddress: "watch.material.legacy_address"
        case .scriptHashAddress: "watch.material.script_hash_address"
        case .nativeSegWitAddress: "watch.material.native_segwit_address"
        case .nativeSegWitScriptAddress: "watch.material.native_segwit_script_address"
        case .taprootAddress: "watch.material.taproot_address"
        case .witnessAddress: "watch.material.witness_address"
        case .standardExtendedPublicKey: "watch.material.xpub"
        case .nestedSegWitExtendedPublicKey: "watch.material.ypub"
        case .nativeSegWitExtendedPublicKey: "watch.material.zpub"
        case .nestedMultisigExtendedPublicKey: "watch.material.multisig_nested"
        case .nativeMultisigExtendedPublicKey: "watch.material.multisig_native"
        }
    }
}

private extension WatchWalletStandard {
    var titleKey: LocalizedStringKey {
        switch self {
        case .legacyBIP44: "watch.standard.legacy"
        case .nestedSegWitBIP49: "watch.standard.nested_segwit"
        case .nativeSegWitBIP84: "watch.standard.native_segwit"
        case .taprootBIP86: "watch.standard.taproot"
        case .nestedSegWitMultisig: "watch.standard.nested_multisig"
        case .nativeSegWitMultisig: "watch.standard.native_multisig"
        }
    }
}

#Preview {
    WatchSetupFlowView()
        .preferredColorScheme(.light)
}
