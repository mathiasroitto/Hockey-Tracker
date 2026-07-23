import SwiftUI

/// End-of-game summary + sync trigger. Sync runs off the buffered game so the
/// user can leave immediately; failures stay queued for retry.
struct EndGameView: View {
    @EnvironmentObject private var sync: GameSyncManager

    let ingest: GameIngest
    var onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(ingest.opponent).font(.headline)
                Text(ingest.date).font(.caption).foregroundStyle(.secondary)

                Divider()

                summaryRow("Goals", value: count(.goal))
                summaryRow("Assists", value: count(.assist))
                summaryRow("Shots", value: count(.shot))
                summaryRow("Hits", value: count(.hit))
                summaryRow("Blocks", value: count(.block))
                summaryRow("Penalties", value: count(.penalty))
                summaryRow("Faceoffs", value: "\(count(.faceoffWin))-\(count(.faceoffLoss))")
                summaryRow("Shifts", value: "\(ingest.shifts.count)")
                summaryRow("Ice time", value: formatDuration(ingest.shifts.reduce(0) { $0 + $1.durationSeconds }))

                if let bio = ingest.biometrics {
                    Divider()
                    summaryRow("Avg HR", value: "\(Int(bio.avgHeartRate)) bpm")
                    summaryRow("Max HR", value: "\(Int(bio.maxHeartRate)) bpm")
                    summaryRow("Energy", value: "\(Int(bio.activeEnergyKcal)) kcal")
                }

                Divider()
                syncStatus

                Button {
                    Task { await sync.syncPending() }
                } label: {
                    Label("Sync now", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    onDone()
                } label: {
                    Label("Done", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Game Over")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func count(_ type: EventType) -> Int {
        ingest.events.reduce(0) { $0 + ($1.type == type ? 1 : 0) }
    }

    private func summaryRow(_ label: String, value: Int) -> some View {
        summaryRow(label, value: "\(value)")
    }

    private func summaryRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).bold().monospacedDigit()
        }
        .font(.footnote)
    }

    @ViewBuilder private var syncStatus: some View {
        switch sync.state {
        case .idle:
            Label("Queued (\(sync.pendingCount))", systemImage: "tray.full")
                .font(.footnote).foregroundStyle(.secondary)
        case .syncing:
            Label("Syncing…", systemImage: "arrow.up.circle").font(.footnote)
        case .synced:
            Label("Synced", systemImage: "checkmark.circle.fill")
                .font(.footnote).foregroundStyle(.green)
        case let .failed(message):
            VStack(alignment: .leading, spacing: 2) {
                Label("Saved, will retry", systemImage: "exclamationmark.arrow.circlepath")
                    .font(.footnote).foregroundStyle(.orange)
                Text(message).font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
    }
}
