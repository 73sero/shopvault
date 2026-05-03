import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct ShopVaultMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup("ShopVault Viewer") {
            ContentView()
                .frame(minWidth: 1100, minHeight: 720)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
    }
}

@MainActor
@Observable
final class AppViewModel {
    var dataset: VaultDataset?
    var selectedFileURL: URL?
    var passphrase: String = ""
    var isDecrypting: Bool = false
    var importError: String?

    func decryptSelectedFile() async {
        guard let url = selectedFileURL else {
            importError = "Bitte zuerst eine .shopvault Datei wählen."
            return
        }

        importError = nil
        isDecrypting = true
        let passphraseCopy = passphrase

        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let result = try await VaultExportDecoder.decode(
                fileURL: url,
                passphrase: passphraseCopy
            )
            dataset = DatasetDecoder.decode(result)
            passphrase = ""
            isDecrypting = false
        } catch let error as DecodeError {
            importError = error.localizedDescription
            isDecrypting = false
        } catch {
            importError = error.localizedDescription
            isDecrypting = false
        }
    }

    func resetSession() {
        dataset = nil
        selectedFileURL = nil
        passphrase = ""
        importError = nil
    }
}

struct ContentView: View {
    @State private var viewModel = AppViewModel()
    @State private var hiddenStore = HiddenItemsStore()

    var body: some View {
        ZStack {
            AnimatedMeshBackground()

            if let dataset = viewModel.dataset {
                MainShell(dataset: dataset, onLock: viewModel.resetSession)
                    .environment(hiddenStore)
            } else {
                ImportView(viewModel: viewModel)
            }
        }
    }
}
