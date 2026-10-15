import SwiftUI

/// A centre-screen result for something the player chose: a deal, a tip, a sale, a job.
struct Flash: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let text: String
    let good: Bool
    /// Money won (+) or lost (−), rolled up on screen. Nil for results without a figure.
    let amount: Int?
}

extension GameStore {
    /// Shows a result alert with a positive or negative tone.
    func flash(_ title: String, _ text: String, good: Bool, amount: Int? = nil) {
        flashing = Flash(title: title, text: text, good: good, amount: amount)
        Audio.shared.play(good ? .win : .lose, volume: 0.55)
        Audio.shared.buzz(good ? .success : .danger)
    }

    func flash(_ o: Outcome, amount: Int? = nil) {
        flash(o.title, o.text, good: o.good, amount: amount)
    }
}

/// Rolls a money figure from zero to its value.
private struct MoneyTicker: View {
    let target: Int
    @State private var shown = 0

    var body: some View {
        Text((target >= 0 ? "+" : "−") + Money.gbp(abs(shown)))
            .font(Noir.title(44))
            .monospacedDigit()
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .task {
                let steps = 36
                for i in 1...steps {
                    try? await Task.sleep(for: .milliseconds(24))
                    // Ease out: fast at first, settling on the exact figure.
                    let p = 1 - pow(1 - Double(i) / Double(steps), 3)
                    shown = Int(Double(target) * p)
                    if i % 4 == 0 { Audio.shared.play(.key, volume: 0.08) }
                }
                shown = target
            }
    }
}

/// The alert itself: pops in, rolls the figure, fades after a couple of seconds, or swipe it away.
struct FlashOverlay: View {
    @Environment(GameStore.self) private var store
    @State private var drag: CGSize = .zero
    @State private var appeared = false

    var body: some View {
        ZStack {
            if let f = store.flashing {
                let tint = f.good ? Noir.green : Noir.red
                Color.black.opacity(0.35).ignoresSafeArea()
                    .onTapGesture { dismiss() }
                    .transition(.opacity)
                VStack(spacing: 10) {
                    Image(systemName: f.good ? "checkmark.seal.fill" : "xmark.octagon.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(tint)
                        .shadow(color: tint.opacity(0.8), radius: 10)
                    Text(f.title.uppercased()).font(Noir.label(15)).tracking(2.5).foregroundStyle(tint)
                    if let amount = f.amount, amount != 0 {
                        MoneyTicker(target: amount)
                            .foregroundStyle(tint)
                            .shadow(color: tint.opacity(0.6), radius: 10)
                            .id(f.id)
                    }
                    Text(f.text)
                        .font(Noir.ui(13))
                        .foregroundStyle(Noir.paper.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .lineLimit(5)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("swipe to dismiss").font(Noir.ui(9)).foregroundStyle(Noir.dim).padding(.top, 2)
                }
                .padding(22)
                .frame(maxWidth: 320)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color(white: 0.06)))
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(tint.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(tint.opacity(0.85), lineWidth: 1.4))
                .shadow(color: tint.opacity(0.4), radius: 26)
                .scaleEffect(appeared ? 1 : 0.6)
                .opacity(appeared ? max(0, 1 - Double(abs(drag.width) + abs(drag.height)) / 240) : 0)
                .offset(drag)
                .rotationEffect(.degrees(Double(drag.width) / 25))
                .gesture(DragGesture()
                    .onChanged { drag = $0.translation }
                    .onEnded { v in
                        if abs(v.translation.width) + abs(v.translation.height) > 80 { dismiss() }
                        else { withAnimation(.spring(duration: 0.3)) { drag = .zero } }
                    })
                .onAppear {
                    drag = .zero
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.62)) { appeared = true }
                }
                .task(id: f.id) {
                    // Long enough to watch the figure roll, then fade.
                    try? await Task.sleep(for: .seconds(f.amount == nil ? 2.0 : 2.6))
                    if store.flashing?.id == f.id { dismiss() }
                }
                .transition(.opacity)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isStaticText)
            }
        }
        .animation(.easeOut(duration: 0.25), value: store.flashing?.id)
    }

    private func dismiss() {
        withAnimation(.easeIn(duration: 0.3)) {
            appeared = false
            store.flashing = nil
        }
    }
}
