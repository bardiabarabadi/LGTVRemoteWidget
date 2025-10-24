# LG webOS TV Commands Reference

## Testing Commands

Now that pairing is successful, you can test these commands:

### Basic Commands

```swift
// Power Off ✅ VERIFIED WORKING
try await manager.sendCommand("ssap://system/turnOff")

// Power On - Use Wake-on-LAN ✅ VERIFIED WORKING
try await manager.wakeTV(mac: "34:E6:E6:F9:05:50")

// Volume Up ✅ VERIFIED WORKING
try await manager.sendCommand("ssap://audio/volumeUp")

// Volume Down ✅ VERIFIED WORKING
try await manager.sendCommand("ssap://audio/volumeDown")

// Mute Toggle ✅ VERIFIED WORKING
try await manager.sendCommand("ssap://audio/setMute", parameters: ["mute": true])
try await manager.sendCommand("ssap://audio/setMute", parameters: ["mute": false])

// Set Volume (0-100)
try await manager.sendCommand("ssap://audio/setVolume", parameters: ["volume": 50])
```

### Input/Channel Commands

```swift
// Change Input ✅ ALL VERIFIED WORKING
try await manager.sendCommand("ssap://tv/switchInput", parameters: ["inputId": "HDMI_1"])
try await manager.sendCommand("ssap://tv/switchInput", parameters: ["inputId": "HDMI_2"])
try await manager.sendCommand("ssap://tv/switchInput", parameters: ["inputId": "HDMI_3"])

// Channel Up/Down
try await manager.sendCommand("ssap://tv/channelUp")
try await manager.sendCommand("ssap://tv/channelDown")
```

### Playback Controls

```swift
// Play
try await manager.sendCommand("ssap://media.controls/play")

// Pause
try await manager.sendCommand("ssap://media.controls/pause")

// Stop
try await manager.sendCommand("ssap://media.controls/stop")

// Rewind
try await manager.sendCommand("ssap://media.controls/rewind")

// Fast Forward
try await manager.sendCommand("ssap://media.controls/fastForward")
```

### Navigation Commands

```swift
// Arrow Keys ✅ ALL VERIFIED WORKING
try await manager.sendCommand("ssap://com.webos.service.ime/sendEnterCommand") // OK/Select
try await manager.sendCommand("ssap://com.webos.service.ime/sendKey", parameters: ["key": "UP"])
try await manager.sendCommand("ssap://com.webos.service.ime/sendKey", parameters: ["key": "DOWN"])
try await manager.sendCommand("ssap://com.webos.service.ime/sendKey", parameters: ["key": "LEFT"])
try await manager.sendCommand("ssap://com.webos.service.ime/sendKey", parameters: ["key": "RIGHT"])

// Home/Back
try await manager.sendCommand("ssap://system.launcher/open", parameters: ["target": "home"])
try await manager.sendCommand("ssap://system.launcher/close")
```

### App Launch Commands

```swift
// Launch Plex ✅ VERIFIED WORKING
try await manager.sendCommand("ssap://system.launcher/launch", parameters: ["id": "cdp-30"])

// Launch YouTube ✅ VERIFIED WORKING
try await manager.sendCommand("ssap://system.launcher/launch", parameters: ["id": "youtube.leanback.v4"])

// Launch Netflix
try await manager.sendCommand("ssap://system.launcher/launch", parameters: ["id": "netflix"])

// Launch Amazon Prime Video
try await manager.sendCommand("ssap://system.launcher/launch", parameters: ["id": "amazon"])
```

### Query Commands (Get Information)

```swift
// Get Current Volume
let response = try await manager.webSocket.sendRequest(
    SSAPRequest(type: .request, uri: "ssap://audio/getVolume")
)

// Get Foreground App Info
let response = try await manager.webSocket.sendRequest(
    SSAPRequest(type: .request, uri: "ssap://com.webos.applicationManager/getForegroundAppInfo")
)

// Get Current Input
let response = try await manager.webSocket.sendRequest(
    SSAPRequest(type: .request, uri: "ssap://tv/getCurrentChannel")
)

// List All Apps
let response = try await manager.webSocket.sendRequest(
    SSAPRequest(type: .request, uri: "ssap://com.webos.applicationManager/listApps")
)

// List Inputs
let response = try await manager.webSocket.sendRequest(
    SSAPRequest(type: .request, uri: "ssap://tv/getExternalInputList")
)
```

## Testing in Your App

### Simple Test Button

Add this to your ContentView to test commands:

```swift
Button("Test Volume Up") {
    Task {
        do {
            try await manager.sendCommand("ssap://audio/volumeUp")
            print("✅ Command sent successfully")
        } catch {
            print("❌ Command failed: \(error)")
        }
    }
}
.disabled(!viewModel.isConnected)
```

### Comprehensive Test View

```swift
struct TestCommandsView: View {
    let manager = LGTVControlManager.shared
    @State private var result = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Command Test")
                .font(.headline)
            
            HStack {
                Button("Vol +") { sendCommand("ssap://audio/volumeUp") }
                Button("Vol -") { sendCommand("ssap://audio/volumeDown") }
                Button("Mute") { sendCommand("ssap://audio/setMute", ["mute": true]) }
            }
            
            HStack {
                Button("HDMI 1") { sendCommand("ssap://tv/switchInput", ["inputId": "HDMI_1"]) }
                Button("HDMI 2") { sendCommand("ssap://tv/switchInput", ["inputId": "HDMI_2"]) }
            }
            
            HStack {
                Button("Netflix") { sendCommand("ssap://system.launcher/launch", ["id": "netflix"]) }
                Button("YouTube") { sendCommand("ssap://system.launcher/launch", ["id": "youtube.leanback.v4"]) }
            }
            
            Button("Power Off") { sendCommand("ssap://system/turnOff") }
                .foregroundColor(.red)
            
            Text(result)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    func sendCommand(_ uri: String, _ params: [String: Any]? = nil) {
        Task {
            do {
                try await manager.sendCommand(uri, parameters: params)
                result = "✅ Sent: \(uri)"
            } catch {
                result = "❌ Error: \(error.localizedDescription)"
            }
        }
    }
}
```

## Common App IDs

| App | App ID |
|-----|--------|
| Netflix | `netflix` |
| YouTube | `youtube.leanback.v4` |
| Amazon Prime Video | `amazon` |
| Plex | `cdp-30` |
| Disney+ | `com.disney.disneyplus-prod` |
| Hulu | `hulu` |
| HBO Max | `hboMax` |
| Apple TV | `com.apple.appletv` |
| Spotify | `spotify-beehive` |

## Notes

1. **Connection Required:** Must be connected and paired before sending commands
2. **Error Handling:** Commands may fail if TV is off or app not installed
3. **Rate Limiting:** Don't send commands too rapidly (wait ~100ms between commands)
4. **Response:** Most commands return `{"returnValue": true}` on success
5. **Power On:** Use Wake-on-LAN for power on (WebSocket won't work when TV is off)

## Next: Widget Integration

Once commands are working, implement App Intents for widget buttons:

```swift
struct VolumeUpIntent: AppIntent {
    static var title: LocalizedStringResource = "Volume Up"
    
    func perform() async throws -> some IntentResult {
        try await LGTVControlManager.shared.sendCommand("ssap://audio/volumeUp")
        return .result()
    }
}
```

---

## ✅ Verified Working Commands (Oct 23, 2025)

**All tested on LG 65UT7000 (webOS 23.23.30)**

| Command | Status | Notes |
|---------|--------|-------|
| Volume Up/Down | ✅ Working | Instant response |
| Mute | ✅ Working | Toggles mute on |
| HDMI 1/2/3 | ✅ Working | All inputs switch correctly |
| Plex Launch | ✅ Working | App launches immediately |
| YouTube Launch | ✅ Working | App launches immediately |
| Arrow Keys | ✅ Working | Up, Down, Left, Right all work |
| OK Button | ✅ Working | Selects menu items |
| Power Off | ✅ Working | TV turns off |
| Power On (WOL) | ✅ Working | Wake-on-LAN wakes TV |

---

**Status:** ✅ All commands tested and verified  
**Updated:** October 23, 2025 11:45 PM  
**TV:** LG 65UT7000 @ 10.0.0.14  
**Client Key:** 9ba71d29c353cf0bdcc00c4b0a8cc189
