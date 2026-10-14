import SwiftUI

struct NewGameView: View {
    var onStart: (Int) -> Void
    var onBack: () -> Void

    @Environment(GameStore.self) private var store
    @Environment(Unlock.self) private var unlock
    @State private var name = ""
    @State private var city = 0
    @FocusState private var nameFocused: Bool

    var body: some View {
        ZStack {
            Noir.ink.ignoresSafeArea()

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
                        Text("Where it starts").noirLabel()
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
                            ForEach(Catalog.cities) { c in
                                let open = unlock.unlocked || GameStore.isGodName(name) || c.id < Catalog.freeCityCount
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
                        if !unlock.unlocked && !GameStore.isGodName(name) {
                            UnlockCard()
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("The job").noirLabel()
                        Text("Thirty days. Buy low, sell high, keep your head down. Everything you own on the last night is your score. Half the news is true. Nobody will tell you which half.")
                            .font(Noir.type(15))
                            .foregroundStyle(Noir.silver)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button("Begin") {
                        store.playerName = name.trimmingCharacters(in: .whitespaces)
                        Audio.shared.buzz(.success)
                        onStart(city)
                    }
                    .buttonStyle(.noirPrimary)
                    .padding(.top, 4)
                }
                .padding(24)
            }
            .scrollDismissesKeyboard(.interactively)
            FilmGrain()
        }
        .onAppear { name = store.playerName }
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
            Text("Free play covers London, Manchester and Birmingham. One purchase opens all 14 cities across the UK and Ireland, each with its own cheap and dear goods.")
                .font(Noir.type(13)).foregroundStyle(Noir.silver)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Button(unlock.busy ? "…" : "Unlock all cities") { Task { await unlock.purchase() } }
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
