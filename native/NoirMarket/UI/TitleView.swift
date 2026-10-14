import SwiftUI

/// Redhead Games logo, then NOIR MARKET under falling powder that settles on the buttons.
struct TitleView: View {
    var hasSave: Bool
    var onContinue: () -> Void
    var onNewGame: () -> Void
    var onHowTo: () -> Void
    var onSettings: () -> Void
    var onRecords: () -> Void

    @State private var phase = 0 // 0 logo, 1 title
    @State private var titleIn = false
    @State private var buttonsIn = false
    @State private var colliders: [String: CGRect] = [:]
    @State private var sim = PowderSim()

    var body: some View {
        ZStack {
            // Pure black so the Redhead logo (on black) blends with no visible box.
            Color.black.ignoresSafeArea()
            if phase == 0 {
                Image("RedheadLogo")
                    .resizable().scaledToFit()
                    .frame(width: 240)
                    .transition(.opacity)
                    .accessibilityLabel("Redhead Games")
            } else {
                title.transition(.opacity)
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation(.easeInOut(duration: 0.9)) { phase = 1 }
            Audio.shared.play()
            try? await Task.sleep(for: .seconds(0.5))
            withAnimation(.easeOut(duration: 1.4)) { titleIn = true }
            try? await Task.sleep(for: .seconds(1.3))
            withAnimation(.easeOut(duration: 0.9)) { buttonsIn = true }
        }
        .onTapGesture {
            if phase == 0 {
                withAnimation(.easeInOut(duration: 0.4)) { phase = 1 }
                Audio.shared.play()
                withAnimation(.easeOut(duration: 1.0)) { titleIn = true }
                withAnimation(.easeOut(duration: 0.8).delay(0.6)) { buttonsIn = true }
            }
        }
    }

    private func press(_ id: String, _ action: @escaping () -> Void) -> () -> Void {
        {
            sim.disturb(id)
            Audio.shared.buzz(.tap)
            action()
        }
    }

    private var title: some View {
        GeometryReader { geo in
            ZStack {
                // Black, with a faint cold glow behind the title.
                RadialGradient(colors: [Color.white.opacity(0.07), .clear], center: .init(x: 0.5, y: 0.36), startRadius: 10, endRadius: 300)
                    .ignoresSafeArea()
                    .opacity(titleIn ? 1 : 0)

                VStack(spacing: 0) {
                    Spacer().frame(height: geo.size.height * 0.2)
                    VStack(spacing: -6) {
                        Text("NOIR")
                            .font(Noir.title(112))
                            .foregroundStyle(Noir.paper)
                            .shadow(color: .white.opacity(0.18), radius: 20)
                        NeonText(text: "MARKET", size: 60, tracking: 1)
                    }
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .opacity(titleIn ? 1 : 0)
                    .offset(y: titleIn ? 0 : 14)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Noir Market")
                    .accessibilityAddTraits(.isHeader)

                    Text("thirty days. nobody’s clean.")
                        .font(Noir.ui(14))
                        .foregroundStyle(Noir.silver)
                        .padding(.top, 18)
                        .opacity(titleIn ? 1 : 0)

                    Spacer()

                    VStack(spacing: 12) {
                        if hasSave {
                            Button("Continue", action: press("continue", onContinue)).buttonStyle(.noirPrimary)
                                .powderCollider("continue")
                            Button("New Game", action: press("new", onNewGame)).buttonStyle(.noir)
                                .powderCollider("new")
                        } else {
                            Button("New Game", action: press("new", onNewGame)).buttonStyle(.noirPrimary)
                                .powderCollider("new")
                        }
                        HStack(spacing: 10) {
                            Button("How to Play", action: press("how", onHowTo)).buttonStyle(.noir)
                                .powderCollider("how")
                            Button("Records", action: press("records", onRecords)).buttonStyle(.noir)
                                .powderCollider("records")
                            Button(action: press("settings", onSettings)) { Image(systemName: "gearshape.fill") }
                                .buttonStyle(.noir)
                                .frame(width: 58)
                                .powderCollider("settings")
                                .accessibilityLabel("Settings")
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    .opacity(buttonsIn ? 1 : 0)
                    .offset(y: buttonsIn ? 0 : 10)
                    .allowsHitTesting(buttonsIn)

                    Text("a redhead games production · 17+ · fiction")
                        .font(Noir.ui(9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .opacity(buttonsIn ? 1 : 0)
                        .foregroundStyle(Noir.dim)
                        .padding(.bottom, 8)
                }

                PowderFall(colliders: buttonsIn ? colliders : [:], sim: sim)
                    .opacity(titleIn ? 1 : 0)
            }
            .coordinateSpace(name: "powder")
            .onPreferenceChange(PowderColliderKey.self) { colliders = $0 }
        }
    }
}
