import SwiftUI

/// Global top 10 from Game Center, in the game's style, with a mode picker and the player's own rank.
struct GlobalLeaderboard: View {
    @State private var mode: GameMode = .daily
    @State private var top: [GameCenter.Entry] = []
    @State private var me: GameCenter.Entry?
    @State private var total = 0
    @State private var loading = false
    @State private var failed = false

    private let modes: [GameMode] = [.daily, .standard, .long, .sprint]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(modes) { m in
                        Button {
                            Audio.shared.buzz(.tap)
                            mode = m
                        } label: {
                            Label(m == .daily ? "Today" : m.title, systemImage: m.symbol)
                                .font(Noir.label(11)).tracking(1).textCase(.uppercase)
                                .foregroundStyle(mode == m ? Noir.ink : Noir.paper)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(Capsule().fill(mode == m ? Noir.green : Color.white.opacity(0.06)))
                        }
                    }
                }
            }

            if !GameCenter.signedIn {
                notice("Sign in to Game Center to see the world’s top dealers and post your own scores.",
                       symbol: "person.crop.circle.badge.exclamationmark", action: ("Sign in", { GameCenter.authenticate() }))
            } else if loading && top.isEmpty {
                HStack { Spacer(); ProgressView().tint(Noir.green); Spacer() }.padding(.vertical, 40)
            } else if failed {
                notice("Couldn’t reach Game Center. Check your connection.", symbol: "wifi.exclamationmark",
                       action: ("Try again", { Task { await load() } }))
            } else if top.isEmpty {
                notice(mode == .daily ? "Nobody’s finished today’s Daily Challenge yet. Be the first on the board."
                                      : "No scores yet. Finish a \(mode.title) game to claim the top spot.",
                       symbol: "trophy", action: nil)
            } else {
                VStack(spacing: 0) {
                    ForEach(top) { row($0) }
                    if let me, !top.contains(where: { $0.isMe }) {
                        Text("···").font(Noir.mono(14)).foregroundStyle(Noir.dim).padding(.vertical, 4)
                        row(me)
                    }
                }
                .card(padding: 0)
                .clipShape(RoundedRectangle(cornerRadius: Noir.radius, style: .continuous))

                HStack {
                    Text(mode == .daily ? "Today’s board resets at midnight UK time." : "All-time global board.")
                    Spacer()
                    if total > 0 { Text("\(total) players") }
                }
                .font(Noir.ui(10)).foregroundStyle(Noir.dim)
                .padding(.horizontal, 4)
            }

            if GameCenter.signedIn, let id = mode.leaderboard {
                Button { GameCenter.showLeaderboard(id) } label: {
                    Label("Full Game Center board", systemImage: "gamecontroller.fill")
                }
                .buttonStyle(.noirQuiet)
            }
        }
        .task(id: mode) { await load() }
    }

    private func row(_ e: GameCenter.Entry) -> some View {
        let medal: Color? = e.rank == 1 ? Noir.amber : e.rank == 2 ? Noir.silver : e.rank == 3 ? Color(hex: 0xCD7F32) : nil
        return HStack(spacing: 12) {
            Text("\(e.rank)")
                .font(Noir.display(e.rank <= 3 ? 22 : 17))
                .foregroundStyle(medal ?? Noir.dim)
                .shadow(color: (medal ?? .clear).opacity(0.5), radius: 6)
                .frame(width: 38, alignment: .leading)
            Text(e.isMe ? "\(e.name) (you)" : e.name)
                .font(Noir.ui(14, weight: e.isMe ? .bold : .semibold))
                .foregroundStyle(e.isMe ? Noir.green : Noir.paper)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(Money.short(e.score)).font(Noir.mono(15)).foregroundStyle(Noir.green)
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
        .background(e.isMe ? Noir.green.opacity(0.1) : .clear)
        .overlay(alignment: .bottom) { Rectangle().fill(Noir.rule).frame(height: 1) }
        .accessibilityElement(children: .combine)
    }

    private func notice(_ text: String, symbol: String, action: (String, () -> Void)?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(text, systemImage: symbol)
                .font(Noir.ui(13)).foregroundStyle(Noir.silver)
                .fixedSize(horizontal: false, vertical: true)
            if let action {
                Button(action.0, action: action.1).buttonStyle(.noirOutline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 16)
    }

    private func load() async {
        guard GameCenter.signedIn, let id = mode.leaderboard else { return }
        loading = true
        failed = false
        defer { loading = false }
        do {
            let result = try await GameCenter.top(id)
            top = result.top; me = result.me; total = result.total
        } catch {
            top = []; me = nil; failed = true
        }
    }
}
