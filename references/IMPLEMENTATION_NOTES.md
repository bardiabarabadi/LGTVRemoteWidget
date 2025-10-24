# LG TV Remote Widget - Implementation Notes

## Overview

This document contains important implementation notes, fixes, and solutions discovered during development of the LG TV Remote Widget iOS app.

---

## WebSocket Connection (SSAP Protocol)

### Secure WebSocket Required (webOS 23)
- **URL**: `wss://[TV_IP]:3001/`
- **Port**: 3001 (secure WebSocket)
- Modern LG TVs (webOS 22+) require secure WebSocket connections
- Must accept self-signed certificates

### Pairing Process
1. Connect to WebSocket
2. Send registration request with manifest
3. TV shows pairing code on screen
4. User enters code in app
5. TV returns client-key
6. Store client-key in Keychain for future connections

### Important: Permissions
Permissions are set at pairing time and cannot be updated without re-pairing. To add new permissions:
1. Clear stored credentials
2. Re-pair with TV
3. TV will show new permission dialog

### Required Permissions for Full Functionality
```swift
permissions: [
    "LAUNCH",                        // Launch apps
    "LAUNCH_WEBAPP",                 // Launch web apps
    "APP_TO_APP",                    // App-to-app communication
    "CONTROL_AUDIO",                 // Volume control
    "CONTROL_DISPLAY",               // Display settings
    "CONTROL_INPUT_MEDIA_PLAYER",    // Media player control
    "CONTROL_POWER",                 // Power on/off
    "READ_INSTALLED_APPS",           // Read app list
    "CONTROL_INPUT_JOYSTICK",        // Joystick input
    "CONTROL_INPUT_TEXT",            // Text input (REQUIRED for pointer socket)
    "CONTROL_INPUT_MEDIA_RECORDING", // Media recording
    "CONTROL_INPUT_MEDIA_PLAYBACK",  // Media playback
    "CONTROL_MOUSE_AND_KEYBOARD",    // Mouse/keyboard
    // ... additional permissions for full control
]
```

**Critical**: `CONTROL_INPUT_TEXT` is required for accessing the pointer input socket on webOS 22/23.

---

## Navigation Controls (webOS 22/23)

### Two WebSocket Architecture
webOS 22+ requires **two separate WebSocket connections**:

1. **Main SSAP Socket** (`wss://IP:3001/`)
   - Used for: Volume, HDMI, apps, power off, etc.
   - Standard SSAP commands

2. **Pointer Input Socket** (obtained from main socket)
   - Used for: Arrow keys, OK, Back, Home buttons
   - Special format, not SSAP JSON

### How to Get Pointer Socket

**Step 1**: Request socket path via main WebSocket
```swift
let request = SSAPRequest(
    type: .request, 
    uri: "ssap://com.webos.service.networkinput/getPointerInputSocket"
)
// Response contains: {"socketPath": "wss://IP:3001/...token..."}
```

**Step 2**: Connect to pointer socket
```swift
let pointerSocket = URLSessionWebSocketTask(with: socketPathURL)
pointerSocket.resume()
```

**Step 3**: Send button commands
```
Format: "type:button\nname:BUTTONNAME\n\n"
Example: "type:button\nname:UP\n\n"
```

**Important**: 
- Double newline `\n\n` at the end is required
- Plain text format, not JSON
- Must keep receiving messages to keep connection alive

### Button Names
```
UP, DOWN, LEFT, RIGHT
ENTER (OK button)
BACK
HOME
EXIT
MENU
INFO
PLAY, PAUSE, STOP, REWIND, FASTFORWARD
```

---

## Wake-on-LAN Implementation

### iOS Limitations
- iOS does not reliably support UDP broadcast (255.255.255.255)
- Must send directly to TV's IP address
- Use Network framework, not legacy BSD sockets

### Implementation
```swift
// Send to specific IP on ports 9 and 7
for port in [9, 7] {
    try await sendPacket(magicPacket, to: tvIP, port: port)
    // Send twice for reliability
    try await sendPacket(magicPacket, to: tvIP, port: port)
}
```

### Magic Packet Format
```
6 bytes: FF FF FF FF FF FF
Followed by: MAC address repeated 16 times
Total: 102 bytes
```

### TV Requirements
Must enable these settings on TV:
- **Settings → General → Quick Start+** = ON
- **Settings → Network → LG Connect Apps** = ON
- TV must be in standby (LED lit), not deep power-off

---

## Working Commands Reference

### Volume Control
```swift
ssap://audio/volumeUp
ssap://audio/volumeDown
ssap://audio/setMute  // payload: {"mute": true/false}
```

### Input/HDMI
```swift
ssap://tv/switchInput  // payload: {"inputId": "HDMI_1"}
// Valid inputs: HDMI_1, HDMI_2, HDMI_3, HDMI_4
```

### App Launching
```swift
ssap://system.launcher/launch  
// payload: {"id": "com.webos.app.hdmi1"} or {"id": "youtube.leanback.v4"}

// Common app IDs:
// - Plex: "cdp-30"
// - YouTube: "youtube.leanback.v4"
// - Netflix: "netflix"
// - Amazon Prime: "amazon"
// - HDMI inputs: "com.webos.app.hdmi1" through "com.webos.app.hdmi4"
```

### Power Control
```swift
// Power Off
ssap://system/turnOff

// Power On - Use Wake-on-LAN (UDP magic packet)
```

### System
```swift
ssap://system.launcher/open  // Home screen
ssap://system.launcher/close
```

---

## Architecture Decisions

### Why Two WebSockets?
LG changed the protocol in webOS 22. Navigation buttons now require:
1. Permission: `CONTROL_INPUT_TEXT`
2. Separate pointer input socket
3. Non-JSON text protocol

This replaced the older SSAP URI approach that worked in webOS 21 and earlier.

### Why Direct IP for WOL?
iOS sandboxing restricts UDP broadcast. Network framework's `NWConnection` to specific IP addresses works reliably, broadcast does not.

### Why Keychain for Credentials?
- Client-key is sensitive (grants TV control)
- Must persist across app launches
- Keychain provides secure storage
- App Groups would work for widget sharing

---

## Common Issues & Solutions

### Issue: "401 insufficient permissions" for pointer socket
**Solution**: Missing `CONTROL_INPUT_TEXT` permission. Must re-pair with TV after adding this permission.

### Issue: Navigation buttons don't work
**Solutions**:
1. Check pointer socket is connected
2. Verify `CONTROL_INPUT_TEXT` permission exists
3. Ensure message format has double newline: `\n\n`
4. Keep receiving messages on pointer socket to maintain connection

### Issue: WOL doesn't wake TV
**Solutions**:
1. Verify TV settings: Quick Start+ and LG Connect Apps enabled
2. Ensure TV is in standby (LED lit), not deep power-off
3. Check IP address is correct
4. Try Ethernet instead of WiFi (more reliable)

### Issue: Connection slow
**Solution**: Removed network diagnostics from connection flow. Connection now takes 2-3 seconds instead of 15+ seconds.

### Issue: App hangs when sending WOL
**Solution**: Changed from blocking `DispatchGroup.wait()` to async `withCheckedThrowingContinuation` with timeout.

---

## File Structure

```
LGTVControl/
├── LGTVControlManager.swift          # Main manager class
├── Models/
│   ├── ConnectionStatus.swift        # Connection states
│   ├── SSAPMessage.swift             # SSAP protocol models
│   └── TVCredentials.swift           # IP, MAC, client-key
├── Network/
│   ├── SSAPWebSocketClient.swift     # Main SSAP WebSocket
│   ├── PointerInputClient.swift      # Navigation WebSocket
│   └── WakeOnLAN.swift                # Wake-on-LAN UDP
└── Storage/
    ├── KeychainManager.swift         # Secure credential storage
    └── AppGroupManager.swift         # Shared defaults
```

---

## Testing Notes

### Test TV Configuration
- **Model**: LG 65UT7000
- **webOS Version**: 23.23.30
- **IP**: 10.0.0.14
- **MAC**: 34:E6:E6:F9:05:50

### Verified Working Features
✅ WebSocket connection (wss://)
✅ Pairing with client-key
✅ Volume up/down/mute
✅ HDMI 1/2/3 switching
✅ App launching (Plex, YouTube)
✅ Power off
✅ Power on (Wake-on-LAN)
✅ Navigation (arrows, OK, back, home) via pointer socket

---

## Next Steps (Step 6)

1. Create widget extension
2. Implement App Intents for widget buttons
3. Use LGTVControlManager from widget
4. Share credentials via App Groups
5. Background refresh for connection state

---

## References

- LG webOS SSAP Protocol: Uses JSON over WebSocket
- Pointer Input: Plain text protocol for navigation
- Network Framework: Apple's modern networking API
- App Intents: iOS 16+ widget interaction system

---

**Last Updated**: October 24, 2025  
**Status**: Step 5.5 Complete - All core functionality working
