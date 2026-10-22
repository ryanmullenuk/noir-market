import SwiftUI
#if os(macOS)
import AppKit
typealias PlatformFont = NSFont
#else
import UIKit
typealias PlatformFont = UIFont
#endif

/// Small shims so one SwiftUI codebase runs as a native iPhone and Mac app.
extension View {
    /// Capitalise each word when typing a name (iOS only; Mac keyboards don't auto-capitalise).
    @ViewBuilder func wordsCapitalized() -> some View {
        #if os(iOS)
        textInputAutocapitalization(.words)
        #else
        self
        #endif
    }

    /// Number pad for amounts on iPhone.
    @ViewBuilder func numberKeyboard() -> some View {
        #if os(iOS)
        keyboardType(.numberPad)
        #else
        self
        #endif
    }

    /// Full-screen cover on iPhone; on the Mac, the same content fills the window over the game.
    @ViewBuilder func coverScreen<Content: View>(isPresented: Bool, @ViewBuilder content: @escaping () -> Content) -> some View {
        #if os(iOS)
        fullScreenCover(isPresented: .constant(isPresented), content: content)
        #else
        overlay {
            if isPresented {
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isPresented)
        #endif
    }
}

extension Image {
    /// A SwiftUI image from a rendered platform image.
    init(platformImage: PlatformImage) {
        #if os(macOS)
        self.init(nsImage: platformImage)
        #else
        self.init(uiImage: platformImage)
        #endif
    }
}

#if os(macOS)
typealias PlatformImage = NSImage
#else
typealias PlatformImage = UIImage
#endif

extension ImageRenderer {
    @MainActor var platformImage: PlatformImage? {
        #if os(macOS)
        nsImage
        #else
        uiImage
        #endif
    }
}

extension Notification.Name {
    /// Mac menu commands.
    static let noirNewGame = Notification.Name("noirNewGame")
    static let noirSettings = Notification.Name("noirSettings")
}

/// Mac sheets: a sensible size and a close button that also answers to Esc
/// (iPhone sheets close with a swipe instead).
private struct MacSheetChrome: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    func body(content: Content) -> some View {
        #if os(macOS)
        content
            .frame(minWidth: 480, idealWidth: 540, minHeight: 640, idealHeight: 800)
            .overlay(alignment: .topTrailing) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .bold))
                }
                .buttonStyle(AmberTile(size: 34))
                .keyboardShortcut(.cancelAction)
                .padding(14)
                .accessibilityLabel("Close")
            }
        #else
        content
        #endif
    }
}

extension View {
    func macSheet() -> some View { modifier(MacSheetChrome()) }

    /// Mac sheet size only, for screens with their own close button.
    @ViewBuilder func macSheetSize() -> some View {
        #if os(macOS)
        frame(minWidth: 480, idealWidth: 540, minHeight: 640, idealHeight: 800)
        #else
        self
        #endif
    }

    /// On the Mac, keep the game a readable width in the middle of a wide window.
    @ViewBuilder func macReadableWidth() -> some View {
        #if os(macOS)
        frame(maxWidth: 680)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Noir.ink.ignoresSafeArea())
        #else
        self
        #endif
    }
}

#if os(macOS)
/// The Mac menu bar: New Game and Settings.
struct NoirCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Game") { NotificationCenter.default.post(name: .noirNewGame, object: nil) }
                .keyboardShortcut("n")
        }
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") { NotificationCenter.default.post(name: .noirSettings, object: nil) }
                .keyboardShortcut(",")
        }
    }
}
#endif

#if DEBUG && os(macOS)
/// DEBUG: `-snapshot PATH [-snapshotDelay S]` saves the main window to a PNG, for checking the Mac layout.
enum MacSnapshot {
    @MainActor static func scheduleIfRequested() {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-snapshot"), i + 1 < args.count else { return }
        let path = args[i + 1]
        let delay = args.firstIndex(of: "-snapshotDelay").flatMap { Double(args[$0 + 1]) } ?? 6
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            // The main window, then any sheet on it as PATH-sheet.png.
            for window in NSApp.windows where window.isVisible {
                guard let view = window.contentView, view.bounds.width > 100,
                      let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { continue }
                view.cacheDisplay(in: view.bounds, to: rep)
                let out = window.sheetParent == nil ? path : path.replacingOccurrences(of: ".png", with: "-sheet.png")
                try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: out))
            }
        }
    }
}
#endif
