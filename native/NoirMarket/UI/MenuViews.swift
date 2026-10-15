import SwiftUI

/// Header for full-height sheets: kicker, big title and a close tile.
struct MenuHeader: View {
    let kicker: String
    let title: String
    var close: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            SheetTitle(kicker: kicker, title: title)
            Spacer()
            Button(action: close) { Image(systemName: "xmark").font(.system(size: 16, weight: .bold)) }
                .buttonStyle(AmberTile(size: 42))
                .accessibilityLabel("Close")
                .padding(.top, 8)
        }
    }
}

/// Glowing green switch.
struct NoirToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(.spring(duration: 0.25)) { configuration.isOn.toggle() }
            Audio.shared.buzz(.tap)
        } label: {
            HStack {
                configuration.label.font(Noir.ui(15)).foregroundStyle(Noir.paper)
                Spacer()
                ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(configuration.isOn ? Noir.green.opacity(0.22) : Color.white.opacity(0.06))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(configuration.isOn ? Noir.green : Color.white.opacity(0.3), lineWidth: 1.2))
                        .frame(width: 54, height: 30)
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(configuration.isOn ? Noir.green : Noir.silver)
                        .frame(width: 22, height: 22)
                        .padding(4)
                        .shadow(color: configuration.isOn ? Noir.green.opacity(0.8) : .clear, radius: 6)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
    }
}

/// A full-width menu row button with an icon and chevron.
struct MenuRow: View {
    let title: String
    let symbol: String
    var tint: Color = Noir.paper
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol).font(.system(size: 16, weight: .semibold)).foregroundStyle(tint).frame(width: 22)
                Text(title).font(Noir.ui(15)).foregroundStyle(tint)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(Noir.dim)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.white.opacity(0.22), lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct SettingsView: View {
    var inGame: Bool
    var onAbandon: () -> Void
    @Environment(GameStore.self) private var store
    @Environment(Unlock.self) private var unlock
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var music = Audio.shared.musicOn
    @State private var haptics = Audio.shared.hapticsOn
    @State private var sounds = Audio.shared.soundsOn
    @State private var name = ""
    @State private var confirmAbandon = false
    @State private var showHowTo = false
    @FocusState private var nameFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                MenuHeader(kicker: "Settings", title: "Menu") { store.playerName = name; dismiss() }

                group("Player") {
                    TextField("", text: $name, prompt: Text("Anonymous").foregroundStyle(Noir.dim))
                        .font(Noir.ui(17, weight: .semibold))
                        .foregroundStyle(GameStore.unlocksAll(name) ? Noir.amber : Noir.paper)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .focused($nameFocused)
                        .submitLabel(.done)
                        .onSubmit { store.playerName = name }
                        .padding(.horizontal, 14)
                        .frame(minHeight: 50)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.04)))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.white.opacity(nameFocused ? 0.8 : 0.3), lineWidth: 1.1))
                    Text("Used in your records. Takes effect from your next game.").font(Noir.ui(11)).foregroundStyle(Noir.dim)
                }

                group("Sound") {
                    VStack(spacing: 14) {
                        Toggle("Music", isOn: $music).onChange(of: music) { Audio.shared.musicOn = music }
                        Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
                        Toggle("Sound effects", isOn: $sounds).onChange(of: sounds) { Audio.shared.soundsOn = sounds }
                        Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
                        Toggle("Haptics", isOn: $haptics).onChange(of: haptics) { Audio.shared.hapticsOn = haptics }
                    }
                    .toggleStyle(NoirToggleStyle())
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.04)))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.22), lineWidth: 1))
                }

                group("Full game") {
                    if unlock.unlocked {
                        Label("All 14 cities unlocked", systemImage: "checkmark.seal.fill")
                            .font(Noir.ui(15, weight: .semibold)).foregroundStyle(Noir.amber)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .card(padding: 16, tint: Noir.amber)
                    } else {
                        Button(unlock.product.map { "Unlock all cities · \($0.displayPrice)" } ?? "Unlock all cities") {
                            Task { await unlock.purchase() }
                        }
                        .buttonStyle(.noirAmber)
                    }
                    MenuRow(title: "Restore purchases", symbol: "arrow.clockwise") { Task { await unlock.restore() } }
                    if let m = unlock.message { Text(m).font(Noir.ui(12)).foregroundStyle(Noir.silver) }
                }

                group("Help") {
                    MenuRow(title: "How to play", symbol: "questionmark.circle.fill") { showHowTo = true }
                    MenuRow(title: "Support", symbol: "envelope.fill") { openURL(URL(string: "https://redhead.games/noir-market/support.html")!) }
                    MenuRow(title: "Privacy policy", symbol: "hand.raised.fill") { openURL(URL(string: "https://redhead.games/noir-market/privacy.html")!) }
                }

                if inGame {
                    Button("Walk away from this game") { confirmAbandon = true }
                        .buttonStyle(.noirDanger)
                }

                Text("Noir Market is fiction, made for entertainment. It doesn’t endorse anything it depicts. Saves stay on this device. No ads, no tracking, no accounts.")
                    .font(Noir.ui(11)).foregroundStyle(Noir.dim)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 30)
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Noir.ink.ignoresSafeArea())
        .buttonStyle(.plain)
        .noirDialog(isPresented: $confirmAbandon, title: "Walk away?", message: "This game will be lost and won’t count towards your records.",
                    icon: "figure.walk", tint: Noir.red,
                    actions: [DialogAction(title: "Abandon this game", kind: .danger) { onAbandon() },
                              DialogAction(title: "Keep playing", kind: .quiet)])
        .sheet(isPresented: $showHowTo) { HowToPlayView().presentationBackground(Noir.ink) }
        .onAppear { name = store.playerName }
        .onDisappear { store.playerName = name }
    }

    private func group<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).noirLabel(11, color: Noir.silver).padding(.leading, 4)
            content()
        }
    }
}

struct HowToPlayView: View {
    @Environment(\.dismiss) private var dismiss

    private let pages: [(String, String, String)] = [
        ("chart.line.uptrend.xyaxis", "Buy low. Sell high.", "Prices move every night in every city. Tap anything in the market to trade. Each city has goods it sells cheap and goods it pays dear for. Learn them."),
        ("moon.zzz.fill", "Every move costs a night.", "Travelling or staying put ends the day. You have thirty. Whatever you’re worth on the last night is your score: cash, bank, stock and stash, minus what you owe."),
        ("terminal.fill", "Check NOIRNET.", "Every morning the underground wire comes through. [WIRE] price shocks are real. [INTEL] is true half the time. The next morning NOIRNET tells you whether yesterday’s intel and any informant tips actually paid off."),
        ("star.fill", "Earn respect.", "Respect rises when you trade big, win fights and pay your debts, and falls when you’re robbed, nicked or late. High respect means better prices, more jobs and old friends turning up with goods or money they owe you. Low respect brings more muggers and bigger gangs."),
        ("light.beacon.max.fill", "Mind the heat.", "Carrying stock and weapons draws attention. Lie low (stay without trading) to cool off. Flights mean customs. When the police stop you, you choose: bribe, run, sacrifice half, or go quietly."),
        ("shippingbox.fill", "Stash it.", "Each city has a lock-up nobody can touch. Ship between lock-ups overnight for a fee, if customs doesn’t get lucky."),
        ("sterlingsign", "Borrow carefully.", "Five lenders, one loan each. Pay early and the interest is lower. Pay late and the debt jumps 20%, and then they visit."),
        ("phone.fill", "Know people.", "Informants sell tips about tomorrow, as reliable as they are expensive. Burner phones get you one off-the-books deal a day."),
    ]

    var body: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    MenuHeader(kicker: "The basics", title: "How to Play") { dismiss() }
                    ForEach(pages, id: \.1) { icon, title, text in
                        HStack(alignment: .top, spacing: 16) {
                            Image(systemName: icon)
                                .font(.system(size: 18))
                                .foregroundStyle(Noir.ink)
                                .frame(width: 40, height: 40)
                                .background(Noir.paper, in: Circle())
                            VStack(alignment: .leading, spacing: 6) {
                                Text(title).font(Noir.display(24)).foregroundStyle(Noir.paper)
                                Text(text).font(Noir.type(15)).foregroundStyle(Noir.silver).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    Text("Ranks: Wannabe → Street Dealer (£10k) → Hustler (£50k) → Kingpin (£500k) → Legend (£1M) → Drug Lord (£10M). Hold a new rank’s worth for three nights to earn it.")
                        .font(Noir.type(13)).foregroundStyle(Noir.dim)
                }
                .padding(22)
            }
            .background(Noir.ink.ignoresSafeArea())
            .buttonStyle(.plain)
    }
}

struct RecordsView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var tab = 0

    var body: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    MenuHeader(kicker: "Closed cases", title: "Records") { dismiss() }
                    HStack(spacing: 6) {
                        tabButton("Records", 0)
                        tabButton("Achievements", 1)
                    }
                    .padding(4)
                    .background(Capsule().fill(Color.white.opacity(0.05)))

                    if tab == 1 {
                        AchievementsList()
                    } else {
                        if store.records.isEmpty {
                            Text("No closed cases yet. Finish a game and it’ll be filed here.")
                                .font(Noir.ui(14)).foregroundStyle(Noir.silver)
                                .padding(.vertical, 30)
                        }
                        ForEach(Array(store.records.enumerated()), id: \.element.id) { i, r in
                            HStack(alignment: .firstTextBaseline, spacing: 14) {
                                Text("\(i + 1)").font(Noir.display(22)).foregroundStyle(i == 0 ? Noir.amber : Noir.dim).frame(width: 30, alignment: .leading)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(r.name).font(Noir.ui(15, weight: .semibold)).foregroundStyle(Noir.paper)
                                    Text("\((GameMode(rawValue: r.mode ?? "") ?? .standard).title) · \(Catalog.ranks[r.rank].name)\(r.died ? " · died" : "") · \(r.date.formatted(date: .abbreviated, time: .omitted))")
                                        .font(Noir.ui(10)).foregroundStyle(Noir.dim)
                                }
                                Spacer()
                                Text(Money.short(r.worth)).font(Noir.mono(15)).foregroundStyle(r.worth >= 0 ? Noir.green : Noir.red)
                            }
                            .padding(.vertical, 8)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Game Center leaderboards").noirLabel(11, color: Noir.silver)
                            ForEach([GameMode.daily, .standard, .long, .sprint]) { m in
                                Button {
                                    if let id = m.leaderboard { GameCenter.showLeaderboard(id) }
                                } label: {
                                    HStack {
                                        Image(systemName: m.symbol)
                                        Text(m.title)
                                        Spacer()
                                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold))
                                    }
                                    .padding(.horizontal, 16)
                                }
                                .buttonStyle(m == .daily ? NoirButtonStyle(kind: .amber) : NoirButtonStyle(kind: .outline))
                            }
                            if !GameCenter.signedIn {
                                Text("Sign in to Game Center in Settings to post scores.").font(Noir.ui(11)).foregroundStyle(Noir.dim)
                            }
                        }
                        .padding(.top, 10)
                    }
                }
                .padding(22)
            }
            .background(Noir.ink.ignoresSafeArea())
            .buttonStyle(.plain)
    }

    private func tabButton(_ title: String, _ i: Int) -> some View {
        Button {
            withAnimation(.spring(duration: 0.25)) { tab = i }
            Audio.shared.buzz(.tap)
        } label: {
            Text(title)
                .font(Noir.label(12)).tracking(1.2).textCase(.uppercase)
                .foregroundStyle(tab == i ? Noir.amber : Noir.silver)
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(Capsule().fill(tab == i ? Noir.amber.opacity(0.15) : .clear))
                .overlay { if tab == i { Capsule().strokeBorder(Color.white.opacity(0.8)) } }
        }
        .buttonStyle(.plain)
    }
}
