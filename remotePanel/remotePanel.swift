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
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemLarge:
            largeLayout
        case .systemMedium:
            mediumLayout
        case .systemSmall:
            smallLayout
        default:
            mediumLayout
        }
    }
    
    private var smallLayout: some View {
        ZStack {
            // Dark background matching other widgets
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(white: 0.15))
                .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 4)
            
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    smallButton(icon: "power", color: Color(red: 1.0, green: 0.27, blue: 0.23), intent: PowerToggleIntent(), label: "Power Toggle")
                    smallButton(icon: "plus", color: Color(red: 0.0, green: 0.48, blue: 1.0), intent: VolumeUpIntent(), label: "Volume Up")
                }
                
                HStack(spacing: 8) {
                    smallButton(icon: "pause.fill", color: Color(red: 0.55, green: 0.55, blue: 0.58), intent: PauseIntent(), label: "Pause")
                    smallButton(icon: "minus", color: Color(red: 0.0, green: 0.48, blue: 1.0), intent: VolumeDownIntent(), label: "Volume Down")
                }
            }
            .padding(8)
        }
    }
    
    // Small button component
    private func smallButton(icon: String, color: Color, intent: some AppIntent, label: String) -> some View {
        Button(intent: intent) {
            ZStack {
                Circle()
                    .fill(color)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var mediumLayout: some View {
        ZStack {
            // Dark background matching large widget
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(white: 0.15))
                .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 4)
            
            HStack(spacing: 0) {
                VStack(spacing: 12) {
                    mediumButton(icon: "power", color: Color(red: 1.0, green: 0.27, blue: 0.23), intent: PowerToggleIntent(), label: "Power Toggle")
                    mediumButton(icon: "house.fill", color: Color(white: 0.45), intent: NavHomeIntent(), label: "Home")
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    mediumButton(icon: "play.fill", color: Color(red: 0.55, green: 0.55, blue: 0.58), intent: PlayIntent(), label: "Play")
                    mediumButton(icon: "pause.fill", color: Color(red: 0.55, green: 0.55, blue: 0.58), intent: PauseIntent(), label: "Pause")
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    mediumButton(icon: "plus", color: Color(red: 0.0, green: 0.48, blue: 1.0), intent: VolumeUpIntent(), label: "Volume Up")
                    mediumButton(icon: "minus", color: Color(red: 0.0, green: 0.48, blue: 1.0), intent: VolumeDownIntent(), label: "Volume Down")
                }
            }
            .padding(12)
        }
    }
    
    // Medium button component matching large widget style
    private func mediumButton(icon: String, color: Color, intent: some AppIntent, label: String) -> some View {
        Button(intent: intent) {
            ZStack {
                Circle()
                    .fill(color)
                
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.white)
            }
            .frame(width: 56, height: 56)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var largeLayout: some View {
        GeometryReader { geometry in
            ZStack {
                // Dark background with rounded corners
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(white: 0.15))
                    .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 4)
                
                VStack(spacing: 0) {
                    // Calculate button size dynamically
                    let totalPadding: CGFloat = 1 // outer padding
                    let spacing: CGFloat = 10
                    let availableWidth = geometry.size.width - (totalPadding * 2) - (spacing * 3)
                    let buttonSize = availableWidth / 4
                    
                    // Fixed 4×4 Grid layout
                    Grid(horizontalSpacing: spacing, verticalSpacing: spacing) {
                        // Row 1: Power Toggle, Plex, YouTube, HDMI 1 (Gaming)
                        GridRow {
                            gridButton(icon: "power", color: Color(red: 1.0, green: 0.27, blue: 0.23), intent: PowerToggleIntent(), label: "Power Toggle")
                                .frame(width: buttonSize, height: buttonSize)
                            gridButton(icon: "film", color: Color(red: 0.9, green: 0.5, blue: 0.2), intent: LaunchPlexIntent(), label: "Plex")
                                .frame(width: buttonSize, height: buttonSize)
                            gridButton(icon: "play.rectangle.fill", color: Color(red: 1.0, green: 0.18, blue: 0.18), intent: LaunchYouTubeIntent(), label: "YouTube")
                                .frame(width: buttonSize, height: buttonSize)
                            gridButton(icon: "gamecontroller.fill", color: Color(red: 0.3, green: 0.78, blue: 0.4), intent: SwitchHDMI1Intent(), label: "HDMI 1 Gaming")
                                .frame(width: buttonSize, height: buttonSize)
                        }
                        
                        // Row 2: Play | ↑ | Home | Empty
                        GridRow {
                            gridButton(icon: "play.fill", color: Color(red: 0.55, green: 0.55, blue: 0.58), intent: PlayIntent(), label: "Play")
                                .frame(width: buttonSize, height: buttonSize)
                            gridButton(icon: "chevron.up", color: Color(white: 0.35), intent: NavUpIntent(), label: "Up")
                                .frame(width: buttonSize, height: buttonSize)
                            gridButton(icon: "house.fill", color: Color(white: 0.45), intent: NavHomeIntent(), label: "Home")
                                .frame(width: buttonSize, height: buttonSize)
                            Color.clear
                                .frame(width: buttonSize, height: buttonSize)
                        }
                        
                        // Row 3: ← | OK | → | Vol+
                        GridRow {
                            gridButton(icon: "chevron.left", color: Color(white: 0.35), intent: NavLeftIntent(), label: "Left")
                                .frame(width: buttonSize, height: buttonSize)
                            gridButton(text: "OK", color: Color(red: 0.0, green: 0.48, blue: 1.0), intent: NavOkIntent(), label: "OK", highlight: true)
                                .frame(width: buttonSize, height: buttonSize)
                            gridButton(icon: "chevron.right", color: Color(white: 0.35), intent: NavRightIntent(), label: "Right")
                                .frame(width: buttonSize, height: buttonSize)
                            gridButton(icon: "plus", color: Color(red: 0.0, green: 0.48, blue: 1.0), intent: VolumeUpIntent(), label: "Vol+")
                                .frame(width: buttonSize, height: buttonSize)
                        }
                        
                        // Row 4: Pause | ↓ | Back | Vol-
                        GridRow {
                            gridButton(icon: "pause.fill", color: Color(red: 0.55, green: 0.55, blue: 0.58), intent: PauseIntent(), label: "Pause")
                                .frame(width: buttonSize, height: buttonSize)
                            gridButton(icon: "chevron.down", color: Color(white: 0.35), intent: NavDownIntent(), label: "Down")
                                .frame(width: buttonSize, height: buttonSize)
                            gridButton(icon: "arrow.uturn.left", color: Color(white: 0.45), intent: NavBackIntent(), label: "Back")
                                .frame(width: buttonSize, height: buttonSize)
                            gridButton(icon: "minus", color: Color(red: 0.0, green: 0.48, blue: 1.0), intent: VolumeDownIntent(), label: "Vol-")
                                .frame(width: buttonSize, height: buttonSize)
                        }
                    }
                    .padding(totalPadding)
                }
            }
        }
    }
    
    // Grid button component for large widget
    private func gridButton(icon: String? = nil, text: String? = nil, color: Color, intent: some AppIntent, label: String, highlight: Bool = false) -> some View {
        Button(intent: intent) {
            ZStack {
                // Circular shape with thinner border
                Circle()
                    .fill(color)
                
                // Icon or text
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                } else if let text = text {
                    Text(text)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
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
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview(as: .systemMedium) {
    RemotePanelWidget()
} timeline: {
    RemotePanelEntry(date: .now, statusText: "connected")
    RemotePanelEntry(date: .now.addingTimeInterval(60), statusText: "error: offline")
}
