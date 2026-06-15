import SwiftUI

/// First screen on the watch: name the opponent (optional) and drop the puck.
struct StartGameView: View {
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var workoutManager: WorkoutManager

    @State private var opponent: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    Image(systemName: "hockey.puck.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(.blue)

                    TextField("Opponent", text: $opponent)
                        .textInputAutocapitalization(.words)

                    Button {
                        workoutManager.startGame(opponent: opponent)
                    } label: {
                        Label("Start Game", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)

                    if !store.games.isEmpty {
                        NavigationLink {
                            WatchHistoryView()
                        } label: {
                            Label("Past Games (\(store.games.count))", systemImage: "list.bullet")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            .navigationTitle("Hockey")
        }
        .task {
            await workoutManager.requestAuthorization()
        }
    }
}
