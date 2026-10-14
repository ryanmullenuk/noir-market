import SwiftUI

/// Redhead Games logo, then the rainy NOIR MARKET title.
struct TitleView: View {
    var hasSave: Bool
    var onContinue: () -> Void
    var onNewGame: () -> Void
    var onHowTo: () -> Void
    var onSettings: () -> Void
    var onRecords: () -> Void

    @State private var phase = 0 // 0 logo, 1 title
    @State private var titleIn = false

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

    private var title: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(colors: [Color(white: 0.16), Color(white: 0.05), Noir.ink],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                // A moon behind the haze.
                Circle()
                    .fill(RadialGradient(colors: [Color(white: 0.75), Color(white: 0.35).opacity(0)],
                                         center: .center, startRadius: 4, endRadius: 90))
                    .frame(width: 180, height: 180)
                    .position(x: geo.size.width * 0.74, y: geo.size.height * 0.16)
                    .opacity(0.55)
                Lightning()
                // City-glow haze on the horizon so the black skyline reads against it.
                LinearGradient(colors: [.clear, Color(white: 0.16), Color(red: 0.2, green: 0.12, blue: 0.1).opacity(0.9)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: geo.size.height * 0.32)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .offset(y: -geo.size.height * 0.12)
                    .ignoresSafeArea()
                Skyline(seed: 1947, tint: Color(white: 0.02))
                    .frame(height: geo.size.height * 0.5)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .ignoresSafeArea()
                // Wet street reflection.
                LinearGradient(colors: [.clear, Noir.ink.opacity(0.9), Noir.ink],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: geo.size.height * 0.2)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .ignoresSafeArea()
                Rain()

                VStack(spacing: 0) {
                    Spacer().frame(height: geo.size.height * 0.2)
                    VStack(spacing: 6) {
                        Text("NOIR")
                            .font(Noir.display(92, weight: .bold))
                            .foregroundStyle(Noir.paper)
                            .shadow(color: .black, radius: 12)
                        NeonText(text: "MARKET", size: 22)
                    }
                    .opacity(titleIn ? 1 : 0)
                    .offset(y: titleIn ? 0 : 14)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Noir Market")
                    .accessibilityAddTraits(.isHeader)

                    Text("Thirty days. One city. Nobody's clean.")
                        .font(Noir.type(14))
                        .foregroundStyle(Noir.silver)
                        .padding(.top, 18)
                        .opacity(titleIn ? 1 : 0)

                    Spacer()

                    VStack(spacing: 10) {
                        if hasSave {
                            Button("Continue", action: onContinue).buttonStyle(.noirPrimary)
                            Button("New Game", action: onNewGame).buttonStyle(.noir)
                        } else {
                            Button("New Game", action: onNewGame).buttonStyle(.noirPrimary)
                        }
                        HStack(spacing: 10) {
                            Button("How to Play", action: onHowTo).buttonStyle(.noirQuiet)
                            Button("Records", action: onRecords).buttonStyle(.noirQuiet)
                            Button {
                                onSettings()
                            } label: {
                                Image(systemName: "gearshape")
                            }
                            .buttonStyle(.noirQuiet)
                            .frame(width: 56)
                            .accessibilityLabel("Settings")
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 18)
                    .opacity(titleIn ? 1 : 0)

                    Text("A Redhead Games production · 17+ · Fiction. For entertainment only.")
                        .font(.system(size: 10))
                        .foregroundStyle(Noir.dim)
                        .padding(.bottom, 8)
                }
                FilmGrain()
            }
        }
    }
}
