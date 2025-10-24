import AppIntents
import WidgetKit
import LGTVControl

struct VolumeUpIntent: AppIntent {
    static var title: LocalizedStringResource = "Volume Up"
    static var description = IntentDescription("Increase the TV volume.")

    func perform() async throws -> some IntentResult {
        try await RemotePanelActionHandler.shared.sendVolumeUp()
        await MainActor.run {
            WidgetCenter.shared.reloadTimelines(ofKind: RemotePanelWidget.kind)
        }
        return .result()
    }
}

struct VolumeDownIntent: AppIntent {
    static var title: LocalizedStringResource = "Volume Down"
    static var description = IntentDescription("Decrease the TV volume.")

    func perform() async throws -> some IntentResult {
        try await RemotePanelActionHandler.shared.sendVolumeDown()
        await MainActor.run {
            WidgetCenter.shared.reloadTimelines(ofKind: RemotePanelWidget.kind)
        }
        return .result()
    }
}

struct PowerOnIntent: AppIntent {
    static var title: LocalizedStringResource = "Power On"
    static var description = IntentDescription("Turn the TV on using Wake-on-LAN.")

    func perform() async throws -> some IntentResult {
        try await RemotePanelActionHandler.shared.sendPowerOn()
        await MainActor.run {
            WidgetCenter.shared.reloadTimelines(ofKind: RemotePanelWidget.kind)
        }
        return .result()
    }
}

struct PowerOffIntent: AppIntent {
    static var title: LocalizedStringResource = "Power Off"
    static var description = IntentDescription("Turn the TV off via SSAP.")

    func perform() async throws -> some IntentResult {
        try await RemotePanelActionHandler.shared.sendPowerOff()
        await MainActor.run {
            WidgetCenter.shared.reloadTimelines(ofKind: RemotePanelWidget.kind)
        }
        return .result()
    }
}

struct PowerToggleIntent: AppIntent {
    static var title: LocalizedStringResource = "Power Toggle"
    static var description = IntentDescription("Toggle TV power: try Wake-on-LAN first, then send power off command.")

    func perform() async throws -> some IntentResult {
        // Try to turn on first (Wake-on-LAN is safe to send even if TV is already on)
        try await RemotePanelActionHandler.shared.sendPowerOn()
        
        // Small delay to allow WoL packet to be sent
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Then send power off command (will only work if TV is connected)
        try await RemotePanelActionHandler.shared.sendPowerOff()
        
        await MainActor.run {
            WidgetCenter.shared.reloadTimelines(ofKind: RemotePanelWidget.kind)
        }
        return .result()
    }
}

struct PlayIntent: AppIntent {
    static var title: LocalizedStringResource = "Play"
    static var description = IntentDescription("Resume media playback.")

    func perform() async throws -> some IntentResult {
        try await RemotePanelActionHandler.shared.sendPlay()
        await MainActor.run {
            WidgetCenter.shared.reloadTimelines(ofKind: RemotePanelWidget.kind)
        }
        return .result()
    }
}

struct PauseIntent: AppIntent {
    static var title: LocalizedStringResource = "Pause"
    static var description = IntentDescription("Pause media playback.")

    func perform() async throws -> some IntentResult {
        try await RemotePanelActionHandler.shared.sendPause()
        await MainActor.run {
            WidgetCenter.shared.reloadTimelines(ofKind: RemotePanelWidget.kind)
        }
        return .result()
    }
}

struct NavUpIntent: AppIntent {
    static var title: LocalizedStringResource = "Navigate Up"

    func perform() async throws -> some IntentResult {
        try await RemotePanelActionHandler.shared.sendNavigation(.up)
        return .result()
    }
}

struct NavDownIntent: AppIntent {
    static var title: LocalizedStringResource = "Navigate Down"

    func perform() async throws -> some IntentResult {
        try await RemotePanelActionHandler.shared.sendNavigation(.down)
        return .result()
    }
}

struct NavLeftIntent: AppIntent {
    static var title: LocalizedStringResource = "Navigate Left"

    func perform() async throws -> some IntentResult {
        try await RemotePanelActionHandler.shared.sendNavigation(.left)
        return .result()
    }
}

struct NavRightIntent: AppIntent {
    static var title: LocalizedStringResource = "Navigate Right"

    func perform() async throws -> some IntentResult {
        try await RemotePanelActionHandler.shared.sendNavigation(.right)
        return .result()
    }
}

struct NavBackIntent: AppIntent {
    static var title: LocalizedStringResource = "Navigate Back"

    func perform() async throws -> some IntentResult {
        try await RemotePanelActionHandler.shared.sendNavigation(.back)
        return .result()
    }
}

struct NavOkIntent: AppIntent {
    static var title: LocalizedStringResource = "Confirm Selection"

    func perform() async throws -> some IntentResult {
        try await RemotePanelActionHandler.shared.sendOk()
        return .result()
    }
}

struct LaunchPlexIntent: AppIntent {
    static var title: LocalizedStringResource = "Launch Plex"

    func perform() async throws -> some IntentResult {
        try await RemotePanelActionHandler.shared.launchApp(id: "cdp-30")
        return .result()
    }
}

struct LaunchYouTubeIntent: AppIntent {
    static var title: LocalizedStringResource = "Launch YouTube"

    func perform() async throws -> some IntentResult {
        try await RemotePanelActionHandler.shared.launchApp(id: "youtube.leanback.v4")
        return .result()
    }
}

struct SwitchHDMI1Intent: AppIntent {
    static var title: LocalizedStringResource = "Switch to HDMI 1"

    func perform() async throws -> some IntentResult {
        try await RemotePanelActionHandler.shared.switchInput(id: "HDMI_1")
        return .result()
    }
}

struct NavHomeIntent: AppIntent {
    static var title: LocalizedStringResource = "Home"

    func perform() async throws -> some IntentResult {
        try await RemotePanelActionHandler.shared.sendNavigation(.home)
        return .result()
    }
}
