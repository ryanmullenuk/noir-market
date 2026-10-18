import SwiftUI

struct NewGameView: View {
    var onStart: (Int, GameMode, Perk?) -> Void
    var onBack: () -> Void

    @Environment(GameStore.self) private var store
    @Environment(Unlock.self) private var unlock
    @State private var name = ""
    @State private var city = 0
    @State private var mode: GameMode = .standard
    @State private var perk: Perk? = nil
    @FocusState private var nameFocused: Bool

    private var full: Bool { unlock.full }

    var body: some View {
        ZStack {
            Noir.ink.ignoresSafeArea()

            ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Button { onBack() } label: { Image(systemName: "chevron.left").font(.system(size: 17, weight: .bold)) }
                            .buttonStyle(AmberTile(size: 46))
                            .accessibilityLabel("Back")
                        Spacer()
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Case File").noirLabel(12, color: Noir.green.opacity(0.8))
                        Text("Who are you?").font(Noir.display(40)).foregroundStyle(Noir.green)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name").noirLabel()
                        TextField("", text: $name, prompt: Text("Anonymous").foregroundStyle(Noir.dim))
                            .font(Noir.type(20))
                            .foregroundStyle(Noir.paper)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .focused($nameFocused)
                            .submitLabel(.done)
                            .padding(.vertical, 10)
                            .overlay(alignment: .bottom) { Rectangle().fill(Noir.rule).frame(height: 1) }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("The job").noirLabel()
                        ForEach(GameMode.allCases) { m in
                            let locked = m.premium && !full
                            choiceRow(symbol: m.symbol, title: m.title + (m == .daily ? " · " + Date.now.formatted(.dateTime.day().month()) : ""),
                                      detail: m.blurb, selected: mode == m, tint: m == .daily ? Noir.amber : Noir.green, locked: locked) {
                                if locked { Task { await unlock.purchase() } } else { mode = m }
                            }
                        }
                    }

                    if mode != .daily && mode != .tutorial {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Your background").noirLabel().id("background")
                            choiceRow(symbol: "person.fill", title: "Nobody special", detail: "No perks, no baggage. Average respect.", selected: perk == nil, tint: Noir.green) { perk = nil }
                            ForEach(Perk.allCases) { p in
                                choiceRow(symbol: p.symbol, title: p.title, detail: p.pro, con: p.con, selected: perk == p, tint: Noir.green, locked: !full) {
                                    if full { perk = p } else { Task { await unlock.purchase() } }
                                }
                            }
                            Text("Every edge has a cost. Respect affects prices, how many jobs come your way, who looks after you, and who comes looking for you.")
                                .font(Noir.ui(11)).foregroundStyle(Noir.dim).fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if mode != .daily && mode != .tutorial {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Where it starts").noirLabel()
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
                            ForEach(Catalog.cities) { c in
                                let open = full || c.id < Catalog.freeCityCount
                                Button {
                                    if open {
                                        city = c.id
                                        Audio.shared.buzz(.tap)
                                    } else {
                                        Task { await unlock.purchase() }
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        if !open { Image(systemName: "lock.fill").font(.system(size: 10)) }
                                        Text(c.name.uppercased()).font(Noir.ui(12, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 42)
                                    .foregroundStyle(city == c.id ? Noir.green : open ? Noir.paper : Noir.amber.opacity(0.8))
                                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(city == c.id ? Noir.green.opacity(0.18) : Color.white.opacity(0.05)))
                                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(city == c.id ? Noir.green : open ? Color.white.opacity(0.12) : Noir.amber.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: open ? [] : [4, 3])))
                                    .shadow(color: city == c.id ? Noir.green.opacity(0.45) : .clear, radius: 8)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(open ? c.name : "\(c.name), locked")
                            }
                        }
                        if !full {
                            UnlockCard()
                        }
                    }

                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("The rules").noirLabel()
                        Text("Thirty days. Buy low, sell high, keep your head down. Everything you own on the last night is your score. Half the news is true. Nobody will tell you which half.")
                            .font(Noir.type(15))
                            .foregroundStyle(Noir.silver)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !full && (mode == .daily || mode == .tutorial) {
                        UnlockCard()
                    }

                    Button("Begin") {
                        store.playerName = name.trimmingCharacters(in: .whitespaces)
                        Audio.shared.buzz(.success)
                        // Never start paid content without the full game (e.g. the name was changed after picking).
                        let m = mode.premium && !full ? .standard : mode
                        onStart(full || city < Catalog.freeCityCount ? city : 0, m, full ? perk : nil)
                    }
                    .buttonStyle(.noirPrimary)
                    .padding(.top, 4)
                }
                .padding(24)
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("-perks") { proxy.scrollTo("background", anchor: .top) }
                #endif
            }
            }
            FilmGrain()
        }
        .onAppear { name = store.playerName }
    }
}

extension NewGameView {
    func choiceRow(symbol: String, title: String, detail: String, con: String? = nil, selected: Bool, tint: Color, locked: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring(duration: 0.25)) { action() }
            Audio.shared.buzz(.tap)
        } label: {
            HStack(spacing: 12) {
                GlowIcon(symbol: symbol, color: tint, size: 34, lit: selected)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(title.uppercased()).font(Noir.label(12)).tracking(1).foregroundStyle(selected ? tint : Noir.paper)
                        if locked { FullGameTag() }
                    }
                    if let con {
                        Label { Text(detail) } icon: { Image(systemName: "plus.circle.fill").foregroundStyle(Noir.green) }
                            .font(Noir.ui(12)).foregroundStyle(Noir.paper.opacity(0.9)).fixedSize(horizontal: false, vertical: true)
                        Label { Text(con) } icon: { Image(systemName: "minus.circle.fill").foregroundStyle(Noir.red) }
                            .font(Noir.ui(12)).foregroundStyle(Noir.silver).fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(detail).font(Noir.ui(12)).foregroundStyle(Noir.silver).fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
                if locked {
                    Image(systemName: "lock.fill").font(.system(size: 13, weight: .bold)).foregroundStyle(Noir.amber)
                } else if selected {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(tint)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(locked ? 0.75 : 1)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(selected ? tint.opacity(0.12) : Color.white.opacity(0.04)))
            .overlay {
                if selected {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(tint.opacity(0.8))
                } else if locked {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Noir.amber.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
            }
            .shadow(color: selected ? tint.opacity(0.3) : .clear, radius: 8)
        }
        .buttonStyle(.plain)
        .accessibilityHint(locked ? "Part of the Full Game" : "")
    }
}

/// Small amber badge for paid content.
struct FullGameTag: View {
    var body: some View {
        Text("FULL GAME")
            .font(Noir.label(8)).tracking(1)
            .foregroundStyle(Noir.amber)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Capsule().fill(Noir.amber.opacity(0.12)))
            .overlay(Capsule().strokeBorder(Noir.amber.opacity(0.6)))
    }
}

/// Upsell card for the one purchase. Kept quiet and honest.
struct UnlockCard: View {
    @Environment(Unlock.self) private var unlock

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Full Game").noirLabel(11, color: Noir.brass)
                Spacer()
                if let price = unlock.product?.displayPrice {
                    Text(price).font(Noir.mono(13)).foregroundStyle(Noir.brass)
                }
            }
            Text("Free play covers London, Manchester and Birmingham, Standard games, the Daily Challenge and every feature on the street. One purchase adds:")
                .font(Noir.type(13)).foregroundStyle(Noir.silver)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 5) {
                ForEach(["11 more cities across the UK and Ireland", "Long Game (60 days) and Sprint (7 days)", "Ex-Copper, Student and Dock Worker backgrounds", "Four extra colour palettes"], id: \.self) { item in
                    Label { Text(item) } icon: { Image(systemName: "plus.circle.fill").foregroundStyle(Noir.brass) }
                        .font(Noir.ui(12)).foregroundStyle(Noir.paper)
                }
            }
            HStack(spacing: 8) {
                Button(unlock.busy ? "…" : "Unlock full game") { Task { await unlock.purchase() } }
                    .buttonStyle(.noirAmber)
                    .disabled(unlock.busy)
                Button("Restore") { Task { await unlock.restore() } }
                    .buttonStyle(.noirQuiet)
                    .frame(width: 110)
                    .disabled(unlock.busy)
            }
            if let message = unlock.message {
                Text(message).font(Noir.type(12)).foregroundStyle(Noir.silver)
            }
        }
        .card()
        
    }
}
