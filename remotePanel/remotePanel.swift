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

    private var panelBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.133, green: 0.145, blue: 0.173),
                Color(red: 0.071, green: 0.078, blue: 0.102)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var cardBackground: Color { Color.white.opacity(0.08) }
    private var cardStroke: Color { Color.white.opacity(0.14) }
    private var softText: Color { Color.white.opacity(0.92) }
    private var accentBlue: Color { Color(red: 0.471, green: 0.584, blue: 1.0) }
    private var accentPurple: Color { Color(red: 0.635, green: 0.518, blue: 1.0) }
    private var accentGreen: Color { Color(red: 0.427, green: 0.769, blue: 0.608) }
    private var accentRed: Color { Color(red: 0.875, green: 0.373, blue: 0.427) }
    private var neutralFill: Color { Color.white.opacity(0.12) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(panelBackground)
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)

            content
                .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemLarge:
            largeLayout
        case .systemMedium:
            mediumLayout
        default:
            mediumLayout
        }
    }

    private var mediumLayout: some View {
        card {
            HStack(spacing: 16) {
                VStack(spacing: 12) {
                    powerOnControl
                    powerOffControl
                }

                Divider()
                    .frame(width: 1)
                    .background(cardStroke.opacity(0.4))

                VStack(spacing: 10) {
                    volumeUpControl
                    volumeDownControl
                }

                Divider()
                    .frame(width: 1)
                    .background(cardStroke.opacity(0.4))

                VStack(spacing: 12) {
                    playControl
                    pauseControl
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var largeLayout: some View {
        VStack(spacing: 16) {
            card {
                HStack(spacing: 12) {
                    quickActionButton(title: "Plex", accent: Color.orange, intent: LaunchPlexIntent())
                    quickActionButton(title: "YouTube", accent: Color.red, intent: LaunchYouTubeIntent())
                    quickActionButton(title: "HDMI 1", accent: accentPurple, intent: SwitchHDMI1Intent())
                }
            }

            HStack(spacing: 16) {
                card {
                    VStack(spacing: 14) {
                        HStack(spacing: 12) {
                            powerOnControl
                            powerOffControl
                        }
                        HStack(spacing: 12) {
                            playControl
                            pauseControl
                        }
                    }
                }

                navigationCluster

                card {
                    VStack(spacing: 12) {
                        volumeUpControl
                        volumeDownControl
                    }
                }
            }

            quickBackButton
        }
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14, content: content)
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(cardBackground)
                    .shadow(color: Color.black.opacity(0.4), radius: 18, x: 0, y: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(cardStroke, lineWidth: 1)
            )
    }

    private var navigationCluster: some View {
        card {
            VStack(spacing: 14) {
                Spacer(minLength: 0)
                navButton(symbol: "chevron.up", intent: NavUpIntent(), accessibilityLabel: "Navigate up")
                HStack(spacing: 14) {
                    navButton(symbol: "chevron.left", intent: NavLeftIntent(), accessibilityLabel: "Navigate left")
                    okButton
                    navButton(symbol: "chevron.right", intent: NavRightIntent(), accessibilityLabel: "Navigate right")
                }
                navButton(symbol: "chevron.down", intent: NavDownIntent(), accessibilityLabel: "Navigate down")
                Spacer(minLength: 0)
            }
        }
    }

    private var quickBackButton: some View {
        Button(intent: NavBackIntent()) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.uturn.left")
                    .font(.subheadline.weight(.semibold))
                Text("Back")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(softText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .background(cardBackground, in: Capsule())
        .overlay(
            Capsule().stroke(cardStroke, lineWidth: 1)
        )
        .accessibilityLabel("Go back")
    }

    private func circularControl<Content: View>(intent: some AppIntent, background: Color, foreground: Color = .white, accessibilityLabel: String, @ViewBuilder content: () -> Content) -> some View {
        Button(intent: intent) {
            content()
                .font(.title3.weight(.semibold))
                .frame(width: 56, height: 56)
        }
        .buttonStyle(.plain)
        .foregroundStyle(foreground)
        .background(
            Circle()
                .fill(background)
        )
        .overlay(
            Circle()
                .stroke(cardStroke.opacity(0.6), lineWidth: 1)
        )
        .accessibilityLabel(accessibilityLabel)
    }

    private func navButton(symbol: String, intent: some AppIntent, accessibilityLabel: String) -> some View {
        Button(intent: intent) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .frame(width: 56, height: 56)
        }
        .buttonStyle(.plain)
        .foregroundStyle(softText)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(neutralFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(cardStroke.opacity(0.6), lineWidth: 1)
        )
        .accessibilityLabel(accessibilityLabel)
    }

    private var okButton: some View {
        Button(intent: NavOkIntent()) {
            Text("OK")
                .font(.headline.weight(.semibold))
                .frame(width: 56, height: 56)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.black.opacity(0.85))
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(accentBlue)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(cardStroke.opacity(0.3), lineWidth: 1)
        )
        .accessibilityLabel("Confirm selection")
    }

    private func quickActionButton(title: String, accent: Color, intent: some AppIntent) -> some View {
        Button(intent: intent) {
            HStack(spacing: 8) {
                Circle()
                    .fill(accent)
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(softText)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .background(cardBackground, in: Capsule())
        .overlay(
            Capsule().stroke(cardStroke, lineWidth: 1)
        )
        .accessibilityLabel(title)
    }

    private var powerOnControl: some View {
        circularControl(intent: PowerOnIntent(), background: accentGreen.opacity(0.85), accessibilityLabel: "Power on") {
            Image(systemName: "power")
        }
    }

    private var powerOffControl: some View {
        circularControl(intent: PowerOffIntent(), background: accentRed.opacity(0.85), accessibilityLabel: "Power off") {
            Image(systemName: "power")
        }
    }

    private var playControl: some View {
        circularControl(intent: PlayIntent(), background: accentBlue.opacity(0.9), accessibilityLabel: "Play") {
            Image(systemName: "play.fill")
        }
    }

    private var pauseControl: some View {
        circularControl(intent: PauseIntent(), background: accentPurple.opacity(0.9), accessibilityLabel: "Pause") {
            Image(systemName: "pause.fill")
        }
    }

    private var volumeUpControl: some View {
        circularControl(intent: VolumeUpIntent(), background: neutralFill, accessibilityLabel: "Volume up") {
            Text("+")
        }
    }

    private var volumeDownControl: some View {
        circularControl(intent: VolumeDownIntent(), background: neutralFill, accessibilityLabel: "Volume down") {
            Text("-")
        }
    }
}

struct RemotePanelWidget: Widget {
    static let kind = "remotePanel"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: RemotePanelProvider()) { entry in
            RemotePanelEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(red: 0.05, green: 0.06, blue: 0.08)
                }
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
