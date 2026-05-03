import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {
    @Bindable var viewModel: AppViewModel
    @State private var showingFileImporter = false

    private static let exportContentType = UTType(filenameExtension: "shopvault") ?? .data

    var body: some View {
        ZStack {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [Self.exportContentType, .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    viewModel.selectedFileURL = url
                    viewModel.importError = nil
                }
            case .failure(let error):
                viewModel.importError = "Datei-Auswahl fehlgeschlagen: \(error.localizedDescription)"
            }
        }
    }

    private var content: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()

            VStack(spacing: AppSpacing.md) {
                ZStack {
                    Circle()
                        .fill(LinearGradient.appAccent.opacity(0.18))
                        .frame(width: 110, height: 110)
                        .blur(radius: 18)
                    Circle()
                        .stroke(LinearGradient.appAccent, lineWidth: 1.5)
                        .frame(width: 88, height: 88)
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(LinearGradient.appAccent)
                }

                VStack(spacing: AppSpacing.xs) {
                    Text("ShopVault")
                        .font(Font.App.largeTitle)
                        .foregroundStyle(Color.App.textPrimary)

                    Text("Verschlüsseltes Snapshot Interface")
                        .font(Font.App.body)
                        .foregroundStyle(Color.App.textSecondary)
                }
            }

            VStack(spacing: AppSpacing.sm) {
                fileSelector

                SecureField("", text: $viewModel.passphrase, prompt: passphrasePrompt)
                    .textFieldStyle(.plain)
                    .font(Font.App.body)
                    .foregroundStyle(Color.App.textPrimary)
                    .padding(AppSpacing.sm)
                    .background(Color.App.bgTertiary.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.small)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .frame(maxWidth: 420)
                    .disabled(viewModel.isDecrypting)
                    .onSubmit { triggerDecrypt() }

                Button(action: triggerDecrypt) {
                    HStack(spacing: AppSpacing.xs) {
                        if viewModel.isDecrypting {
                            ProgressView().controlSize(.small).tint(.white)
                            Text("Entschlüssele …")
                        } else {
                            Image(systemName: "key.fill")
                            Text("Entsperren")
                        }
                    }
                    .font(Font.App.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.sm)
                    .background(canDecrypt ? AnyShapeStyle(LinearGradient.appAccent) : AnyShapeStyle(Color.white.opacity(0.1)))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                .disabled(!canDecrypt)
                .frame(maxWidth: 420)
            }
            .padding(AppSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.large)
                    .fill(Color.App.bgSecondary.opacity(0.7))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.large)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            .frame(maxWidth: 480)

            if let error = viewModel.importError {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.App.danger)
                    Text(error)
                        .font(Font.App.caption)
                        .foregroundStyle(Color.App.textPrimary)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.xs)
                .background(Color.App.danger.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                .frame(maxWidth: 480)
            }

            Spacer()

            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(Color.App.accentPrimary.opacity(0.7))
                Text("AES-256-GCM · PBKDF2-HMAC-SHA256 · 600 000 Iterations · Lokal")
                    .font(Font.App.smallCaption)
                    .foregroundStyle(Color.App.textTertiary)
            }
            .padding(.bottom, AppSpacing.lg)
        }
        .padding(.horizontal, AppSpacing.xl)
    }

    private var passphrasePrompt: Text {
        Text("Export-Passwort")
            .foregroundStyle(Color.App.textTertiary)
    }

    private var fileSelector: some View {
        Button {
            showingFileImporter = true
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: viewModel.selectedFileURL == nil ? "folder.badge.plus" : "doc.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.App.accentPrimary)
                    .frame(width: 32, height: 32)
                    .background(Color.App.accentPrimary.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.selectedFileURL == nil ? "Snapshot-Datei wählen" : viewModel.selectedFileURL!.lastPathComponent)
                        .font(Font.App.caption)
                        .foregroundStyle(Color.App.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(viewModel.selectedFileURL == nil ? ".shopvault vom iPhone" : "Bereit zum Entsperren")
                        .font(Font.App.smallCaption)
                        .foregroundStyle(Color.App.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.App.textTertiary)
            }
            .padding(AppSpacing.sm)
            .background(Color.App.bgTertiary.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.small)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isDecrypting)
        .frame(maxWidth: 420)
    }

    private var canDecrypt: Bool {
        viewModel.selectedFileURL != nil
            && !viewModel.passphrase.isEmpty
            && !viewModel.isDecrypting
    }

    private func triggerDecrypt() {
        guard canDecrypt else { return }
        Task { await viewModel.decryptSelectedFile() }
    }
}
