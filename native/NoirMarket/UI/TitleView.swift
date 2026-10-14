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
    @State private var colliders: [String: CGRect] = [:]
    @State private var sim = PowderSim()

    var body: some View {
        ZStack {
            Noir.ink.ignoresSafeArea()
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
            withAnimation(.easeInOut(duration: 0.8)) { phase = 1 }
            Audio.shared.play()
            try? await Task.sleep(for: .seconds(0.3))
            withAnimation(.easeOut(duration: 1.6)) { titleIn = true }
        }
        .onTapGesture {
            if phase == 0 {
                withAnimation(.easeInOut(duration: 0.4)) { phase = 1 }
                Audio.shared.play()
                withAnimation(.easeOut(duration: 1.2)) { titleIn = true }
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
                // Night sky with a cold glow behind the title.
                LinearGradient(colors: [Color(white: 0.13), Color(white: 0.04), Noir.ink], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                RadialGradient(colors: [Color.white.opacity(0.10), .clear], center: .init(x: 0.5, y: 0.32), startRadius: 10, endRadius: 320)
                    .ignoresSafeArea()
                Skyline(seed: 1947, tint: Color(white: 0.025))
                    .frame(height: geo.size.height * 0.42)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .opacity(0.9)
                    .ignoresSafeArea()
                LinearGradient(colors: [.clear, Noir.ink.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                    .frame(height: geo.size.height * 0.3)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer().frame(height: geo.size.height * 0.2)
                    VStack(spacing: 4) {
                        HStack(spacing: 0) {
                            ForEach(Array("NOIR".enumerated()), id: \.offset) { i, letter in
                                Text(String(letter))
                                    .font(Noir.display(96, weight: .bold))
                                    .foregroundStyle(Noir.paper)
                                    .shadow(color: .white.opacity(0.25), radius: 18)
                                    .powderCollider("letter\(i)", topInset: 27, sideInset: 2)
                            }
                        }
                        NeonText(text: "MARKET", size: 22)
                    }
                    .opacity(titleIn ? 1 : 0)
                    .offset(y: titleIn ? 0 : 14)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Noir Market")
                    .accessibilityAddTraits(.isHeader)

                    Text("Thirty days. Nobody’s clean.")
                        .font(Noir.type(15))
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
                    .opacity(titleIn ? 1 : 0)

                    Text("A Redhead Games production · 17+ · Fiction. For entertainment only.")
                        .font(.system(size: 10))
                        .foregroundStyle(Noir.dim)
                        .padding(.bottom, 8)
                }

                PowderFall(colliders: titleIn ? colliders : [:], sim: sim)
                    .opacity(titleIn ? 1 : 0)
            }
            .coordinateSpace(name: "powder")
            .onPreferenceChange(PowderColliderKey.self) { colliders = $0 }
        }
    }
}
