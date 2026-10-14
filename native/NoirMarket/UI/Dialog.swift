import SwiftUI

/// One button in a game-style dialog.
struct DialogAction: Identifiable {
    let id = UUID()
    let title: String
    var kind: NoirButtonStyle.Kind = .secondary
    var action: () -> Void = {}
}

/// In-game replacement for system alerts and action sheets: dimmed backdrop, glowing card.
struct NoirDialog: View {
    let title: String
    let message: String
    var icon: String = "exclamationmark.triangle.fill"
    var tint: Color = Noir.amber
    let actions: [DialogAction]
    var dismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    GlowIcon(symbol: icon, color: tint, size: 34)
                    Text(title.uppercased()).font(Noir.label(14)).tracking(1.6).foregroundStyle(tint)
                }
                Text(message)
                    .font(Noir.ui(14))
                    .foregroundStyle(Noir.paper)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 10) {
                    ForEach(actions) { a in
                        Button(a.title) {
                            Audio.shared.play(.click, volume: 0.5)
                            dismiss()
                            a.action()
                        }
                        .buttonStyle(NoirButtonStyle(kind: a.kind))
                    }
                }
                .padding(.top, 4)
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color(white: 0.07)))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(tint.opacity(0.75), lineWidth: 1.2))
            .shadow(color: tint.opacity(0.3), radius: 24)
            .padding(.horizontal, 26)
            .transition(.scale(scale: 0.92).combined(with: .opacity))
        }
        .onAppear { Audio.shared.buzz(.warning) }
    }
}

extension View {
    func noirDialog(isPresented: Binding<Bool>, title: String, message: String, icon: String = "exclamationmark.triangle.fill",
                    tint: Color = Noir.amber, actions: [DialogAction]) -> some View {
        overlay {
            if isPresented.wrappedValue {
                NoirDialog(title: title, message: message, icon: icon, tint: tint, actions: actions) {
                    withAnimation(.easeOut(duration: 0.2)) { isPresented.wrappedValue = false }
                }
                .zIndex(10)
            }
        }
        .animation(.spring(duration: 0.3), value: isPresented.wrappedValue)
    }

    /// Shows the store's error, if any, as a game-style notice.
    func noirErrors(_ store: GameStore, when visible: Bool = true) -> some View {
        noirDialog(isPresented: Binding(get: { visible && store.error != nil }, set: { if !$0 { store.error = nil } }),
                   title: "Not so fast", message: store.error ?? "", icon: "hand.raised.fill", tint: Noir.red,
                   actions: [DialogAction(title: "OK", kind: .secondary)])
    }
}
