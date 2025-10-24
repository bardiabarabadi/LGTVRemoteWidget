//
//  remotePanel.swift
//  remotePanel
//
//  Created by Bardia Barabadi on 2025-10-24.
//

import AppIntents
import LGTVControl
import SwiftUI
import WidgetKit

struct RemotePanelProvider: TimelineProvider {
    func placeholder(in context: Context) -> RemotePanelEntry {
        RemotePanelEntry(date: .now, statusText: "disconnected")
    }

    func getSnapshot(in context: Context, completion: @escaping (RemotePanelEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RemotePanelEntry>) -> Void) {
        let entry = makeEntry()
        let refreshDate = Calendar.current.date(byAdding: .second, value: 30, to: Date()) ?? Date().addingTimeInterval(30)
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }

    private func makeEntry() -> RemotePanelEntry {
        let status = AppGroupManager.shared.getString(forKey: LGTVControlManager.Constants.lastStatusKey) ?? "disconnected"
        return RemotePanelEntry(date: .now, statusText: status)
    }
}

struct RemotePanelEntry: TimelineEntry {
    let date: Date
    let statusText: String

    var statusLabel: String {
        if statusText.lowercased().hasPrefix("error") {
            return "Error"
        }
        return statusText.capitalized
    }

    var statusColor: Color {
        let normalized = statusText.lowercased()
        if normalized.contains("connected") {
            return .green
        }
        if normalized.contains("connecting") || normalized.contains("pairing") {
            return .yellow
        }
        if normalized.contains("error") {
            return .red
        }
        return .gray
    }
}

struct RemotePanelEntryView: View {
    var entry: RemotePanelEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(entry.statusColor)
                    .frame(width: 10, height: 10)
                Text(entry.statusLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Spacer()

            Button(intent: VolumeUpIntent()) {
                Label("Volume +", systemImage: "speaker.wave.2.fill")
                    .font(.headline)
            }
            .foregroundStyle(.primary)
        }
        .padding()
    }
}

struct RemotePanelWidget: Widget {
    static let kind = "remotePanel"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: RemotePanelProvider()) { entry in
            RemotePanelEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("LG TV Remote")
        .description("Quick controls for your LG TV.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    RemotePanelWidget()
} timeline: {
    RemotePanelEntry(date: .now, statusText: "connected")
    RemotePanelEntry(date: .now.addingTimeInterval(60), statusText: "error: offline")
}
