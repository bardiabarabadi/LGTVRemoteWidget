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
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemMedium:
            mediumLayout
        case .systemLarge:
            largeLayout
        default:
            mediumLayout
        }
    }

    @ViewBuilder
    private func volumeButton(symbol: String, intent: some AppIntent, accessibilityLabel: String) -> some View {
        Button(intent: intent) {
            Text(symbol)
                .font(.title2.bold())
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.primary.opacity(0.9))
        .foregroundStyle(.background)
        .clipShape(Circle())
        .accessibilityLabel(accessibilityLabel)
    }

    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: 16) {
            statusHeader

            HStack(alignment: .center, spacing: 20) {
                VStack(spacing: 12) {
                    controlButton(systemName: "power.circle.fill", tint: .green, intent: PowerOnIntent(), accessibilityLabel: "Power on")
                    controlButton(systemName: "power.circle.fill", tint: .red, intent: PowerOffIntent(), accessibilityLabel: "Power off")
                }

                Spacer()

                VStack(spacing: 12) {
                    volumeButton(symbol: "+", intent: VolumeUpIntent(), accessibilityLabel: "Volume up")
                    volumeButton(symbol: "-", intent: VolumeDownIntent(), accessibilityLabel: "Volume down")
                }

                Spacer()

                VStack(spacing: 12) {
                    controlButton(systemName: "play.circle.fill", tint: .blue, intent: PlayIntent(), accessibilityLabel: "Play")
                    controlButton(systemName: "pause.circle.fill", tint: .indigo, intent: PauseIntent(), accessibilityLabel: "Pause")
                }
            }
        }
        .padding()
    }

    private var largeLayout: some View {
        VStack(spacing: 18) {
            largeStatusHeader

            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 12) {
                    controlButton(systemName: "power.circle.fill", tint: .green, intent: PowerOnIntent(), accessibilityLabel: "Power on")
                    controlButton(systemName: "power.circle.fill", tint: .red, intent: PowerOffIntent(), accessibilityLabel: "Power off")
                    HStack(spacing: 12) {
                        controlButton(systemName: "play.circle.fill", tint: .blue, intent: PlayIntent(), accessibilityLabel: "Play")
                        controlButton(systemName: "pause.circle.fill", tint: .indigo, intent: PauseIntent(), accessibilityLabel: "Pause")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)

                VStack(spacing: 12) {
                    navigationButton(symbol: "chevron.up", intent: NavUpIntent(), accessibilityLabel: "Navigate up")
                    HStack(spacing: 12) {
                        navigationButton(symbol: "chevron.left", intent: NavLeftIntent(), accessibilityLabel: "Navigate left")
                        okButton
                        navigationButton(symbol: "chevron.right", intent: NavRightIntent(), accessibilityLabel: "Navigate right")
                    }
                    navigationButton(symbol: "chevron.down", intent: NavDownIntent(), accessibilityLabel: "Navigate down")
                    backButton
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 12) {
                    volumeButton(symbol: "+", intent: VolumeUpIntent(), accessibilityLabel: "Volume up")
                    volumeButton(symbol: "-", intent: VolumeDownIntent(), accessibilityLabel: "Volume down")
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }

            quickLaunchRow
        }
        .padding()
    }

    private var statusHeader: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(entry.statusColor)
                .frame(width: 10, height: 10)
            Text(entry.statusLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var largeStatusHeader: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(entry.statusColor)
                .frame(width: 12, height: 12)
            Text(entry.statusLabel)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    @ViewBuilder
    private func controlButton(systemName: String, tint: Color, intent: some AppIntent, accessibilityLabel: String) -> some View {
        Button(intent: intent) {
            Image(systemName: systemName)
                .font(.title2)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
        .foregroundStyle(.white)
        .clipShape(Circle())
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private func navigationButton(symbol: String, intent: some AppIntent, accessibilityLabel: String) -> some View {
        Button(intent: intent) {
            Image(systemName: symbol)
                .font(.title2.bold())
                .frame(width: 48, height: 48)
                .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 12))
        .tint(Color.accentColor)
        .foregroundStyle(.white)
        .accessibilityLabel(accessibilityLabel)
    }

    private var okButton: some View {
        Button(intent: NavOkIntent()) {
            Text("OK")
                .font(.headline.bold())
                .frame(width: 48, height: 48)
                .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 12))
        .tint(Color.accentColor)
        .foregroundStyle(.white)
        .accessibilityLabel("Confirm selection")
    }

    private var backButton: some View {
        Button(intent: NavBackIntent()) {
            Label("Back", systemImage: "arrow.uturn.left")
                .labelStyle(.titleAndIcon)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 12))
        .tint(Color.gray.opacity(0.4))
        .foregroundStyle(.primary)
        .accessibilityLabel("Go back")
    }

    private var quickLaunchRow: some View {
        HStack(spacing: 12) {
            quickActionButton(title: "Plex", tint: .orange, intent: LaunchPlexIntent())
            quickActionButton(title: "YouTube", tint: .red, intent: LaunchYouTubeIntent())
            quickActionButton(title: "HDMI 1", tint: .purple, intent: SwitchHDMI1Intent())
        }
    }

    @ViewBuilder
    private func quickActionButton(title: String, tint: Color, intent: some AppIntent) -> some View {
        Button(intent: intent) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 14))
        .tint(tint)
        .foregroundStyle(.white)
        .accessibilityLabel(title)
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
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

#Preview(as: .systemMedium) {
    RemotePanelWidget()
} timeline: {
    RemotePanelEntry(date: .now, statusText: "connected")
    RemotePanelEntry(date: .now.addingTimeInterval(60), statusText: "error: offline")
}
