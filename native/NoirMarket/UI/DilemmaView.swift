import SwiftUI

/// An overnight decision card: two choices, each with what it will do.
struct DilemmaView: View {
    let dilemma: Dilemma

    @Environment(GameStore.self) private var store
    @State private var shown = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    GlowIcon(symbol: dilemma.symbol, color: Noir.amber, size: 40)
                    Text("A DECISION").font(Noir.label(11)).tracking(1.6).foregroundStyle(Noir.amber)
                    Spacer()
                }
                Text(dilemma.title).font(Noir.display(26)).foregroundStyle(Noir.paper)
                    .fixedSize(horizontal: false, vertical: true)
                Text(dilemma.text).font(Noir.type(14)).foregroundStyle(Noir.silver)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 10) {
                    ForEach(Array(dilemma.options.enumerated()), id: \.offset) { i, option in
                        Button { choose(i) } label: {
                            VStack(spacing: 3) {
                                Text(option)
                                Text(dilemma.details[i]).font(Noir.ui(10, weight: .medium)).tracking(0.4).textCase(nil).opacity(0.8)
                            }
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(i == 0 ? NoirButtonStyle(kind: .amber) : NoirButtonStyle(kind: .outline))
                    }
                }
                .padding(.top, 4)
                if let e = store.error {
                    Text(e).font(Noir.ui(12)).foregroundStyle(Noir.red)
                }
            }
            .padding(22)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Noir.surface))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Noir.amber.opacity(0.75), lineWidth: 1.2))
            .shadow(color: Noir.amber.opacity(0.3), radius: 24)
            .padding(.horizontal, 22)
            .scaleEffect(shown ? 1 : 0.92)
            .opacity(shown ? 1 : 0)
        }
        .onAppear {
            Audio.shared.play(.page, volume: 0.5)
            Audio.shared.buzz(.warning)
            withAnimation(.spring(duration: 0.35)) { shown = true }
        }
        .accessibilityAddTraits(.isModal)
    }

    private func choose(_ i: Int) {
        Audio.shared.play(.click, volume: 0.5)
        var result: (title: String, text: String, good: Bool, amount: Int?)?
        let ok = store.act { s in result = try Engine.resolveDilemma(&s, option: i) }
        if ok, let r = result {
            store.error = nil
            store.flash(r.title, r.text, good: r.good, amount: r.amount)
        }
    }
}
