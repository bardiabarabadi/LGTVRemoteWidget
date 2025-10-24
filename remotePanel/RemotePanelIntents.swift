import AppIntents
import WidgetKit

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
