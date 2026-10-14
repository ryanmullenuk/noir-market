import SwiftUI

struct SettingsView: View {
    var inGame: Bool
    var onAbandon: () -> Void
    @Environment(GameStore.self) private var store
    @Environment(Unlock.self) private var unlock
    @Environment(\.dismiss) private var dismiss
    @State private var music = Audio.shared.musicOn
    @State private var haptics = Audio.shared.hapticsOn
    @State private var sounds = Audio.shared.soundsOn
    @State private var name = ""
    @State private var confirmAbandon = false
    @State private var showHowTo = false

    var body: some View {
        NavigationStack {
            List {
                Section("Player") {
                    TextField("Name", text: $name)
                        .onSubmit { store.playerName = name }
                        .onDisappear { store.playerName = name }
                }
                Section("Sound") {
                    Toggle("Music", isOn: $music).onChange(of: music) { Audio.shared.musicOn = music }
                    Toggle("Sound effects", isOn: $sounds).onChange(of: sounds) { Audio.shared.soundsOn = sounds }
                    Toggle("Haptics", isOn: $haptics).onChange(of: haptics) { Audio.shared.hapticsOn = haptics }
                }
                Section {
                    if unlock.unlocked {
                        Label("All 14 cities unlocked", systemImage: "checkmark.seal.fill").foregroundStyle(Noir.brass)
                    } else {
                        Button(unlock.product.map { "Unlock all cities · \($0.displayPrice)" } ?? "Unlock all cities") {
                            Task { await unlock.purchase() }
                        }
                    }
                    Button("Restore purchases") { Task { await unlock.restore() } }
                    if let m = unlock.message { Text(m).font(.footnote).foregroundStyle(.secondary) }
                } header: { Text("Full game") }
                Section("Help") {
                    Button("How to play") { showHowTo = true }
                    Link("Support", destination: URL(string: "https://redhead.games/noir-market/support.html")!)
                    Link("Privacy policy", destination: URL(string: "https://redhead.games/noir-market/privacy.html")!)
                }
                if inGame {
                    Section {
                        Button("Walk away from this game", role: .destructive) { confirmAbandon = true }
                    } footer: {
                        Text("Noir Market is fiction, made for entertainment. It doesn’t endorse anything it depicts. Saves stay on this device. No ads, no tracking, no accounts.")
                    }
                } else {
                    Section {} footer: {
                        Text("Noir Market is fiction, made for entertainment. It doesn’t endorse anything it depicts. Saves stay on this device. No ads, no tracking, no accounts.")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Noir.ink)
            .navigationTitle("Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .noirDialog(isPresented: $confirmAbandon, title: "Walk away?", message: "This game will be lost and won’t count towards your records.",
                        icon: "figure.walk", tint: Noir.red,
                        actions: [DialogAction(title: "Abandon this game", kind: .danger) { onAbandon() },
                                  DialogAction(title: "Keep playing", kind: .quiet)])
            .sheet(isPresented: $showHowTo) { HowToPlayView() }
        }
        .tint(Noir.neon)
        .onAppear { name = store.playerName }
    }
}

struct HowToPlayView: View {
    @Environment(\.dismiss) private var dismiss

    private let pages: [(String, String, String)] = [
        ("chart.line.uptrend.xyaxis", "Buy low. Sell high.", "Prices move every night in every city. Tap anything in the market to trade. Each city has goods it sells cheap and goods it pays dear for. Learn them."),
        ("moon.zzz.fill", "Every move costs a night.", "Travelling or staying put ends the day. You have thirty. Whatever you’re worth on the last night is your score: cash, bank, stock and stash, minus what you owe."),
        ("terminal.fill", "Check NOIRNET.", "Every morning the underground wire comes through. [WIRE] price shocks are real. [INTEL] is true half the time. The next morning NOIRNET tells you whether yesterday’s intel and any informant tips actually paid off."),
        ("light.beacon.max.fill", "Mind the heat.", "Carrying stock and weapons draws attention. Lie low (stay without trading) to cool off. Flights mean customs. When the police stop you, you choose: bribe, run, sacrifice half, or go quietly."),
        ("shippingbox.fill", "Stash it.", "Each city has a lock-up nobody can touch. Ship between lock-ups overnight for a fee, if customs doesn’t get lucky."),
        ("sterlingsign", "Borrow carefully.", "Five lenders, one loan each. Pay early and the interest is lower. Pay late and the debt jumps 20%, and then they visit."),
        ("phone.fill", "Know people.", "Informants sell tips about tomorrow, as reliable as they are expensive. Burner phones get you one off-the-books deal a day."),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
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
            .background(Noir.ink)
            .navigationTitle("How to Play")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Got it") { dismiss() } } }
        }
        .tint(Noir.neon)
    }
}

struct RecordsView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if store.records.isEmpty {
                        Text("No closed cases yet. Finish a game and it’ll be filed here.")
                            .font(Noir.type(15)).foregroundStyle(Noir.silver)
                            .padding(.vertical, 40)
                    }
                    ForEach(Array(store.records.enumerated()), id: \.element.id) { i, r in
                        HStack(alignment: .firstTextBaseline, spacing: 14) {
                            Text("\(i + 1)").font(Noir.display(24)).foregroundStyle(i == 0 ? Noir.brass : Noir.dim).frame(width: 30, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.name).font(Noir.typeBold(16)).foregroundStyle(Noir.paper)
                                Text("\(Catalog.ranks[r.rank].name)\(r.died ? " · died" : "") · \(r.date.formatted(date: .abbreviated, time: .omitted))")
                                    .font(Noir.ui(11)).foregroundStyle(Noir.dim)
                            }
                            Spacer()
                            Text(Money.short(r.worth)).font(Noir.mono(16)).foregroundStyle(r.worth >= 0 ? Noir.paper : Noir.neon)
                        }
                        .padding(.vertical, 12)
                        Rectangle().fill(Noir.rule).frame(height: 1)
                    }
                }
                .padding(22)
            }
            .background(Noir.ink)
            .navigationTitle("Records")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .tint(Noir.neon)
    }
}
