import SwiftUI
import HockeyContract

/// Signed-in home: profile header + a list of the user's games.
struct HomeView: View {
    @EnvironmentObject private var session: AuthSession
    @Environment(\.apiClient) private var api

    @StateObject private var games: Loadable<[Game]>
    @State private var opponentQuery = ""
    @State private var showingProfileEditor = false

    init() {
        // The real fetch is wired in `reload` because the environment (and thus
        // the APIClient) isn't available at init time.
        _games = StateObject(wrappedValue: Loadable())
    }

    var body: some View {
        NavigationStack {
            AsyncContentView(
                loadable: games,
                isEmpty: { $0.isEmpty },
                emptyMessage: opponentQuery.isEmpty
                    ? "Games you record on your Watch will show up here."
                    : "No games against “\(opponentQuery)”."
            ) { list in
                List {
                    Section {
                        ForEach(list) { game in
                            NavigationLink(value: game.id) {
                                GameRow(game: game)
                            }
                        }
                    } header: {
                        Text("^[\(list.count) game](inflect: true)")
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Games")
            .navigationDestination(for: String.self) { gameId in
                GameDetailView(gameId: gameId)
            }
            .searchable(text: $opponentQuery, prompt: "Filter by opponent")
            .onSubmit(of: .search) { Task { await reload() } }
            .refreshable { await reload() }
            .safeAreaInset(edge: .top) {
                ProfileHeader(
                    displayName: session.currentUser?.displayName,
                    onEdit: { showingProfileEditor = true }
                )
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        CareerStatsView()
                    } label: {
                        Label("Career", systemImage: "chart.bar.xaxis")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("Edit name", systemImage: "pencil") {
                            showingProfileEditor = true
                        }
                        Button("Sign out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                            session.signOut()
                        }
                    } label: {
                        Label("Account", systemImage: "person.crop.circle")
                    }
                }
            }
            .sheet(isPresented: $showingProfileEditor) {
                ProfileEditorView(
                    currentName: session.currentUser?.displayName
                )
                .environmentObject(session)
            }
        }
        .task { await reload() }
    }

    private func reload() async {
        let query = opponentQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let client = api
        await games.load { try await client.games(opponent: query.isEmpty ? nil : query) }
        // Keep the profile header fresh too.
        if session.currentUser == nil {
            await session.refreshCurrentUser()
        }
    }
}

private struct GameRow: View {
    let game: Game

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("vs \(game.opponent)")
                    .font(.headline)
                Spacer()
                Text(Format.gameDate(game.date))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                if let location = game.location, !location.isEmpty {
                    Label(location, systemImage: "mappin.and.ellipse")
                }
                Label("^[\(game.periods) period](inflect: true)", systemImage: "clock")
                if game.biometrics != nil {
                    Label("Biometrics", systemImage: "heart.fill")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

private struct ProfileHeader: View {
    let displayName: String?
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                if let name = displayName, !name.isEmpty {
                    Text(name).font(.headline)
                    Text("Welcome back").font(.caption).foregroundStyle(.secondary)
                } else {
                    Button(action: onEdit) {
                        Label("Add your name", systemImage: "plus.circle")
                            .font(.headline)
                    }
                    Text("Personalize your profile")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }
}
