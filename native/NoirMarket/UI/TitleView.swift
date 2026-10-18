import SwiftUI

/// Redhead Games logo, then NOIR MARKET under falling powder that settles on the buttons.
struct TitleView: View {
    var hasSave: Bool
    var onContinue: () -> Void
    var onNewGame: () -> Void
    var onHowTo: () -> Void
    var onSettings: () -> Void
    var onRecords: () -> Void

    /// 0 logo, 1 black, 2 disclaimer, 3 black, 4 title.
    @State private var phase = 0
    @State private var titleIn = false
    @State private var buttonsIn = false
    @State private var sequence: Task<Void, Never>?

    var body: some View {
        ZStack {
            // Pure black so the Redhead logo (on black) blends with no visible box.
            Color.black.ignoresSafeArea()
            switch phase {
            case 0:
                Image("RedheadLogo")
                    .resizable().scaledToFit()
                    .frame(width: 240)
                    .transition(.opacity)
                    .accessibilityLabel("Redhead Games")
            case 2:
                Disclaimer().transition(.opacity)
            case 4:
                ZStack {
                    Noir.ink.ignoresSafeArea()
                    title
                }
                .transition(.opacity)
            default:
                EmptyView()
            }
        }
        .onAppear { run(from: 0) }
        .onTapGesture {
            // Tapping skips to the next card: logo → disclaimer → title.
            if phase < 2 { run(from: 1) } else if phase < 4 { run(from: 3) }
        }
    }

    /// Plays the intro from a given phase: logo, fade to black, disclaimer, fade to black, title.
    private func run(from start: Int) {
        sequence?.cancel()
        sequence = Task { @MainActor in
            if start <= 0 {
                try? await Task.sleep(for: .seconds(1.8))
                guard !Task.isCancelled else { return }
            }
            if start <= 1 {
                withAnimation(.easeInOut(duration: 0.7)) { phase = 1 }
                try? await Task.sleep(for: .seconds(0.8))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.9)) { phase = 2 }
                try? await Task.sleep(for: .seconds(5.5))
                guard !Task.isCancelled else { return }
            }
            withAnimation(.easeInOut(duration: 0.7)) { phase = 3 }
            try? await Task.sleep(for: .seconds(0.8))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.9)) { phase = 4 }
            Audio.shared.play()
            try? await Task.sleep(for: .seconds(0.5))
            withAnimation(.easeOut(duration: 1.4)) { titleIn = true }
            try? await Task.sleep(for: .seconds(1.3))
            withAnimation(.easeOut(duration: 0.9)) { buttonsIn = true }
        }
    }

    private func press(_ id: String, _ action: @escaping () -> Void) -> () -> Void {
        {
            Audio.shared.buzz(.tap)
            action()
        }
    }

    private var title: some View {
        GeometryReader { outer in
        let insets = outer.safeAreaInsets
        GeometryReader { geo in
            ZStack {
                // Behind the powder: black with a faint cold glow and a vignette.
                RadialGradient(colors: [Color.white.opacity(0.06), .clear], center: .init(x: 0.5, y: 0.38), startRadius: 10, endRadius: 320)
                    .opacity(titleIn ? 1 : 0)
                PowderField()
                    .opacity(titleIn ? 1 : 0)
                RadialGradient(colors: [.clear, .black.opacity(0.6)], center: .center, startRadius: 220, endRadius: 640)
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    Spacer().frame(height: insets.top + geo.size.height * 0.15)
                    VStack(spacing: -10) {
                        Text("NOIR")
                            .font(Noir.title(112))
                            .foregroundStyle(Noir.paper)
                            .shadow(color: .black.opacity(0.8), radius: 10)
                        NeonText(text: "MARKET", size: 82, tracking: 0, font: Noir.title(82), glow: 0.35)
                    }
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .padding(.horizontal, 30)
                    .opacity(titleIn ? 1 : 0)
                    .offset(y: titleIn ? 0 : 14)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Noir Market")
                    .accessibilityAddTraits(.isHeader)

                    Text("thirty days. nobody’s clean.")
                        .font(Noir.ui(15))
                        .foregroundStyle(Noir.silver)
                        .padding(.top, 16)
                        .opacity(titleIn ? 1 : 0)

                    Spacer(minLength: 40)

                    VStack(spacing: 14) {
                        Button(action: press("main", hasSave ? onContinue : onNewGame)) {
                            HStack {
                                Spacer()
                                Text(hasSave ? "Continue" : "New Game")
                                Spacer()
                                Image(systemName: "arrow.right").font(.system(size: 18, weight: .semibold))
                            }
                            .padding(.horizontal, 22)
                        }
                        .buttonStyle(NeonRedButton())
                        if hasSave {
                            Button("New Game", action: press("new", onNewGame)).buttonStyle(TitleOutlineButton())
                        }
                        HStack(spacing: 12) {
                            Button("How to Play", action: press("how", onHowTo)).buttonStyle(TitleOutlineButton())
                            Button("Records", action: press("records", onRecords)).buttonStyle(TitleOutlineButton())
                        }
                        Button(action: press("settings", onSettings)) {
                            HStack(spacing: 12) {
                                Image(systemName: "gearshape.fill").font(.system(size: 17))
                                Text("Settings").font(Noir.label(13)).tracking(2.2).textCase(.uppercase)
                            }
                            .foregroundStyle(Noir.silver)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 30)
                    .opacity(buttonsIn ? 1 : 0)
                    .offset(y: buttonsIn ? 0 : 10)
                    .allowsHitTesting(buttonsIn)

                    Text("a redhead games production · fiction · 18+ · entertainment only")
                        .font(Noir.ui(10))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 16)
                        .foregroundStyle(Noir.silver.opacity(0.7))
                        .opacity(buttonsIn ? 1 : 0)
                        .padding(.top, 36)
                        .padding(.bottom, insets.bottom + 62)
                }
            }
        }
        .ignoresSafeArea()
        }
    }
}

/// Red neon-outlined call to action, like a motel sign tube.
struct NeonRedButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        configuration.label
            .font(Noir.label(17)).tracking(3).textCase(.uppercase)
            .foregroundStyle(Noir.neon)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(shape.fill(Color.black.opacity(0.55)))
            .background(shape.fill(Noir.neon.opacity(configuration.isPressed ? 0.16 : 0.03)))
            .overlay(shape.strokeBorder(Noir.neon, lineWidth: 1.6))
            .shadow(color: Noir.neon.opacity(configuration.isPressed ? 0.7 : 0.45), radius: configuration.isPressed ? 8 : 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.18), value: configuration.isPressed)
    }
}

/// Quiet outlined title button.
struct TitleOutlineButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        configuration.label
            .font(Noir.label(13)).tracking(2.2).textCase(.uppercase)
            .foregroundStyle(Noir.paper)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(shape.fill(Color.black.opacity(configuration.isPressed ? 0.3 : 0.55)))
            .overlay(shape.strokeBorder(Color.white.opacity(configuration.isPressed ? 0.7 : 0.35), lineWidth: 1.2))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.18), value: configuration.isPressed)
    }
}

/// Shown between the Redhead logo and the title.
private struct Disclaimer: View {
    var body: some View {
        VStack(spacing: 22) {
            Text("DISCLAIMER")
                .font(Noir.title(30)).tracking(1)
                .foregroundStyle(Color(hex: 0xFF3B3B))
                .shadow(color: Color(hex: 0xFF3B3B).opacity(0.45), radius: 10)
            VStack(spacing: 18) {
                Text("THIS GAME IS FOR ENTERTAINMENT PURPOSES ONLY.")
                Text("REAL CITY NAMES ARE USED AS FICTIONAL SETTINGS. THEIR DEPICTION DOES NOT REPRESENT REAL CONDITIONS, COMMUNITIES OR ACTIVITIES.")
                Text("ALL CHARACTERS AND EVENTS ARE FICTIONAL. ANY RESEMBLANCE TO REAL PEOPLE OR EVENTS IS PURELY COINCIDENTAL.")
            }
            .font(Noir.ui(13, weight: .semibold)).tracking(0.6)
            .lineSpacing(4)
            .foregroundStyle(Color.white)
            .fixedSize(horizontal: false, vertical: true)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 34)
        .accessibilityElement(children: .combine)
    }
}
