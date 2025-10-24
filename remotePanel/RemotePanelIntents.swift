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

struct PlayPauseIntent: AppIntent {
    static var title: LocalizedStringResource = "Play/Pause"
    static var description = IntentDescription("Toggle media playback.")

    func perform() async throws -> some IntentResult {
        try await RemotePanelActionHandler.shared.sendPlayPause()
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
