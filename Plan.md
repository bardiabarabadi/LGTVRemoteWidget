# LG TV Remote Widget Implementation Plan

This plan provides a complete roadmap for building an iOS 17+ app with an interactive home-screen widget that controls LG webOS TVs via the local SSAP (WebSocket) protocol. The app includes pairing, command sending, Wake-on-LAN power management, and a widget with comprehensive controls.

**Division of Labor:**

- **Human:** GUI setup in Xcode, Apple Developer account tasks, provisioning profiles, certificates, and device testing
- **Agent:** Code generation, technical implementation, architecture setup, and debugging

---

## Architecture Overview

The app consists of three main components:

1. **Main App Target** (`LG TV Remote Widget`)

   - SwiftUI setup screen for TV connection configuration
   - Fields for TV IP address and MAC address
   - Connection button with status feedback
   - Handles initial WebSocket pairing flow (displays on-screen pairing code)

2. **Shared Framework** (`LGTVControl`)

   - WebSocket client using URLSessionWebSocketTask
   - LG SSAP protocol implementation (JSON-based command/response)
   - Wake-on-LAN UDP packet sender
   - Keychain wrapper for secure storage of TV credentials and client-key
   - App Group shared data access (UserDefaults suite)
   - Models: TVCredentials, SSAPMessage, ConnectionStatus

3. **Widget Extension** (`LGTVRemoteWidget`)

   - WidgetKit medium/large widget with interactive controls
   - App Intents for button actions (iOS 17+ interactive widgets)
   - Timeline provider with connection status polling
   - UI components: volume buttons, playback controls, navigation arrows, power button, app launchers (Plex, YouTube), HDMI2 input switcher, status indicator dot

**Data Flow:**

- App Group ID: `group.com.DaraConsultingInc.LGTVRemoteWidget`
- Keychain: stores TV IP, MAC address, and client-key (shared with widget via Keychain access group)
- UserDefaults suite: stores last connection status, TV name (optional)
- Widget uses shared framework to send on-demand WebSocket commands (connect → send → disconnect pattern)

---

## Step 1: LG TV Prerequisites Setup

**Objective:** Prepare the LG webOS TV for network control and gather required credentials.

**Human Tasks:**

1. Enable **LG Connect Apps** on your TV:

   - Navigate to Settings → General → Mobile TV On → Turn on "LG Connect Apps" or similar setting (varies by model)
   - Ensure TV is connected to the same Wi-Fi network as your iPhone

2. Find your TV's **IP address**:

   - Settings → Network → Wi-Fi Connection → Advanced Wi-Fi Settings → View IP Address
   - Note: Use static IP or DHCP reservation on your router to prevent IP changes

3. Find your TV's **MAC address**:

   - Settings → Network → Wi-Fi Connection → Advanced Wi-Fi Settings → MAC Address
   - Example format: `AA:BB:CC:DD:EE:FF`

4. (Optional) Register for **LG Developer Account** at webostv.developer.lge.com if you want to explore advanced features later (not required for this proof-of-concept)
5. Test network connectivity:

   - From your Mac, ping the TV IP: `ping <TV_IP_ADDRESS>`
   - Ensure port 3000 is accessible (TV's SSAP WebSocket port)

**Deliverables:**

- TV IP address (e.g., `192.168.1.100`)
- TV MAC address (e.g., `A0:B1:C2:D3:E4:F5`)
- Confirmed same-network connectivity

**Estimated Time:** 10-15 minutes

---

## Step 2: macOS Development Environment Setup

**Objective:** Configure Xcode project with proper deployment target, provisioning, and network permissions.

**Human Tasks:**

1. Open `LG TV Remote Widget.xcodeproj` in Xcode
2. Update deployment target:

   - Select project → Build Settings → iOS Deployment Target → Change from `26.0` to `17.0`

3. Configure signing:

   - Select project → Signing & Capabilities
   - Ensure "Automatically manage signing" is enabled
   - Confirm Development Team is set (`2V6DK23L8X` or your team)

4. Add required capabilities (we'll add these programmatically later, but note them):

   - App Groups
   - Keychain Sharing

5. Prepare for device testing:

   - Connect iPhone (iOS 17+) via USB
   - Trust device on Mac and iPhone
   - Ensure device is registered in Apple Developer portal (automatic with Xcode)

**Agent Tasks:**

1. Update `IPHONEOS_DEPLOYMENT_TARGET` to 17.0 in project.pbxproj
2. Create Info.plist additions for network permissions:

   - `NSLocalNetworkUsageDescription`: "This app connects to your LG TV on the local network to send remote control commands."
   - `NSBonjourServices`: `["_lge-remote._tcp"]` (optional, for future SSDP discovery)

**Deliverables:**

- Updated project configuration with iOS 17.0 deployment target
- Info.plist with network permission strings
- Verified Xcode can build to device

**Estimated Time:** 15-20 minutes

**Complexity:** Low

---

## Step 3: Create Shared Framework

**Objective:** Build a reusable Swift framework containing all LG TV communication logic, accessible by both the main app and widget extension.

**Technical Details:**

- Create new Framework target: `LGTVControl`
- Add to both main app and widget extension
- Implements WebSocket client using `URLSessionWebSocketTask`
- Handles LG SSAP protocol (JSON-based request/response)
- Provides Keychain wrapper using Security framework
- Implements Wake-on-LAN UDP sender using Network framework

**Agent Tasks:**

1. Create `LGTVControl` framework target in Xcode project
2. Implement core files:

   - `Models/TVCredentials.swift`: Codable struct for IP, MAC, clientKey
   - `Models/SSAPMessage.swift`: SSAP request/response structures
   - `Models/ConnectionStatus.swift`: Enum (connected, disconnected, pairing, error)
   - `Network/SSAPWebSocketClient.swift`: WebSocket manager class
   - `Network/WakeOnLAN.swift`: Magic packet sender using NWConnection
   - `Storage/KeychainManager.swift`: Save/load credentials to Keychain
   - `Storage/AppGroupManager.swift`: UserDefaults suite wrapper
   - `LGTVControlManager.swift`: High-level API facade

**Deliverables:**

- `LGTVControl.framework` with all networking and storage logic
- Public API: `LGTVControlManager` with methods:
  - `connect(ip: String, mac: String) async throws -> String?` (returns pairing code if needed)
  - `sendCommand(_ command: String, parameters: [String: Any]?) async throws`
  - `disconnect()`
  - `wakeTV(mac: String) async throws`
  - `getConnectionStatus() -> ConnectionStatus`
  - `saveCredentials(_ credentials: TVCredentials)`
  - `loadCredentials() -> TVCredentials?`

**Estimated Time:** 2-3 hours

**Complexity:** High (WebSocket protocol implementation, SSAP message handling)

---

## Step 4: Implement SSAP Protocol & Pairing Flow

**Objective:** Implement LG's SSAP (Second Screen Application Protocol) JSON-based WebSocket communication with initial pairing.

**Technical Details:**

- SSAP WebSocket URL: `ws://<TV_IP>:3000/`
- Initial message must be `register` payload with client manifest
- If TV hasn't paired before, it displays a 6-digit code on screen
- User enters code → send in `register` response → receive `client-key`
- Store `client-key` in Keychain for future connections
- All subsequent messages use `request` type with unique IDs

**Agent Tasks:**

1. Implement SSAP message structure in `SSAPMessage.swift`:
   ```swift
   struct SSAPRequest {
       let type: String // "register" or "request"
       let id: String // unique identifier
       let uri: String // e.g., "ssap://audio/volumeUp"
       let payload: [String: Any]?
   }
   ```

2. Implement registration flow in `SSAPWebSocketClient.swift`:

   - Send registration with manifest (app name, permissions)
   - Handle pairing response (extract client-key or pairing code requirement)
   - Implement pairing code submission
   - Store received client-key

3. Implement command sending:

   - Generate unique message IDs (UUID)
   - Send commands with proper SSAP URIs
   - Handle responses and errors

4. Implement reconnection with stored client-key

**SSAP Command URIs to support:**

- `ssap://audio/volumeUp`
- `ssap://audio/volumeDown`
- `ssap://media.controls/play`
- `ssap://media.controls/pause`
- `ssap://system.launcher/launch` (with app ID parameter)
- `ssap://tv/switchInput` (with input ID parameter)
- `ssap://system/turnOff`
- `ssap://com.webos.applicationManager/getForegroundAppInfo` (for status)

**Deliverables:**

- Fully functional SSAP protocol implementation
- Pairing flow that returns pairing code when needed
- Command sending with proper message structure
- Error handling for network failures and invalid responses

**Estimated Time:** 2-3 hours

**Complexity:** High (protocol reverse-engineering, async/await error handling)

---

## Step 5: Implement Wake-on-LAN

**Objective:** Create UDP-based Wake-on-LAN sender to power on TV when it's in standby.

**Technical Details:**

- Wake-on-LAN magic packet: 6 bytes of `0xFF` followed by MAC address repeated 16 times
- Send to broadcast address `255.255.255.255` on port 9
- Use Network framework's `NWConnection` for UDP
- Called before attempting WebSocket connection if TV is offline

**Agent Tasks:**

1. Implement `WakeOnLAN.swift`:

   - Parse MAC address string (remove colons/hyphens)
   - Build magic packet byte array
   - Create NWConnection with UDP to broadcast address
   - Send packet with timeout

2. Add retry logic (send 3 packets with 100ms delay)
3. Add wait period after WOL (2-3 seconds for TV to wake)

**Deliverables:**

- `WakeOnLAN` class with `send(macAddress: String) async throws` method
- Integration into `LGTVControlManager.connect()`
- Error handling for network unavailable scenarios

**Estimated Time:** 45 minutes - 1 hour

**Complexity:** Medium (UDP networking, byte manipulation)

---

## Step 6: Implement Keychain Storage

**Objective:** Securely store TV credentials (IP, MAC, client-key) in iOS Keychain with App Group sharing.

**Technical Details:**

- Use Security framework's Keychain Services API
- Store credentials under service name `com.DaraConsultingInc.LGTVRemoteWidget.credentials`
- Enable Keychain access group to share between app and widget
- Encode `TVCredentials` as JSON data before storage

**Agent Tasks:**

1. Implement `KeychainManager.swift`:

   - `save(credentials: TVCredentials, service: String) throws`
   - `load(service: String) throws -> TVCredentials?`
   - `delete(service: String) throws`
   - Use `SecItemAdd`, `SecItemCopyMatching`, `SecItemDelete`

2. Add Keychain access group capability (agent adds entitlements file):

   - Create `LG TV Remote Widget.entitlements`
   - Add `keychain-access-groups`: `["$(AppIdentifierPrefix)com.DaraConsultingInc.LGTVRemoteWidget"]`

3. Integrate into `LGTVControlManager`

**Deliverables:**

- Keychain wrapper with error handling
- Entitlements file with keychain-access-groups
- Unit test for save/load/delete operations

**Estimated Time:** 1 hour

**Complexity:** Medium (Keychain API, entitlements configuration)

---

## Step 7: Build Main App UI (SwiftUI Setup Screen)

**Objective:** Create a user-friendly SwiftUI screen for entering TV credentials and initiating pairing.

**UI Components:**

- TextField for TV IP address
- TextField for MAC address (formatted with colons)
- "Connect" button
- Status indicator (colored dot + text)
- Alert dialog for pairing code entry
- Connection status messages

**Agent Tasks:**

1. Update `ContentView.swift`:

   - Add `@State` properties for IP, MAC, status, pairing code
   - Add form with TextFields (use keyboard type `.decimalPad` for IP)
   - Add MAC address formatter (auto-insert colons)
   - Add Connect button with async action

2. Implement connection flow:

   - Call `LGTVControlManager.connect()`
   - If pairing code returned, show alert with TextField
   - Submit pairing code and complete registration
   - Save credentials to Keychain on success
   - Update status indicator

3. Add visual feedback:

   - Progress indicator during connection
   - Success/error states with colors (green/red dot)
   - Error messages displayed below form

**Deliverables:**

- Polished SwiftUI setup screen in `ContentView.swift`
- Pairing code entry alert
- Status feedback system
- Credential persistence on successful connection

**Estimated Time:** 1.5-2 hours

**Complexity:** Medium (SwiftUI state management, async UI updates)

---

## Step 8: Create Widget Extension

**Objective:** Add WidgetKit extension with interactive controls using App Intents (iOS 17+).

**Technical Details:**

- Create Widget Extension target: `LGTVRemoteWidget`
- Add `LGTVControl` framework dependency
- Use `AppIntent` for each button action
- Use `TimelineProvider` with `.atEnd` reload policy for status updates
- Widget family: `.systemMedium` or `.systemLarge`

**Human Tasks:**

1. In Xcode: File → New → Target → Widget Extension
2. Name: `LGTVRemoteWidget`
3. Uncheck "Include Configuration Intent" (we'll use App Intents instead)
4. Add `LGTVControl.framework` to Link Binary with Libraries
5. Ensure App Group and Keychain entitlements match main app

**Agent Tasks:**

1. Create widget boilerplate in `LGTVRemoteWidget/` folder
2. Implement timeline provider in `LGTVRemoteWidgetProvider.swift`:

   - Load credentials from Keychain
   - Check connection status (quick ping or cached state)
   - Return entry with connection status

3. Create widget view in `LGTVRemoteWidgetView.swift`:

   - Layout with HStack/VStack (depends on family size)
   - Status indicator dot (green/red) in corner
   - Interactive buttons using `.widgetButton` modifier

4. Configure reload policy: `.atEnd` with 30-second refresh

**Deliverables:**

- Widget extension target with proper configuration
- Timeline provider with status checking
- Basic widget view structure (buttons added in next step)
- Entitlements file matching main app (App Group, Keychain)

**Estimated Time:** 1-1.5 hours

**Complexity:** Medium (WidgetKit concepts, extension target setup)

---

## Step 9: Implement App Intents for Widget Buttons

**Objective:** Create interactive App Intents for all widget control buttons (iOS 17+ interactive widgets).

**Control Buttons:**

1. Volume Up / Volume Down
2. Play / Pause (toggle based on state)
3. Navigation arrows (Up, Down, Left, Right)
4. OK (enter/select)
5. Return (back button)
6. Power Off (with WOL if TV is offline)
7. Launch Plex
8. Launch YouTube
9. Switch to HDMI2

**Technical Details:**

- Each button requires an `AppIntent` conforming to `AppIntent` protocol
- Use `@MainActor` for async command execution
- Handle errors gracefully (show in widget status or log)

**Agent Tasks:**

1. Create `Intents/` folder in widget extension
2. Implement App Intents:

   - `VolumeUpIntent.swift`, `VolumeDownIntent.swift`
   - `PlayPauseIntent.swift` (needs to check current state, but for MVP just send play)
   - `NavigationIntent.swift` (parameterized with direction enum)
   - `OKIntent.swift`, `ReturnIntent.swift`
   - `PowerIntent.swift` (includes WOL logic)
   - `LaunchAppIntent.swift` (parameterized with app ID)
   - `SwitchInputIntent.swift` (parameterized with input ID)

3. Each intent implementation:

   - Load credentials from Keychain
   - Initialize WebSocket connection
   - Send SSAP command
   - Disconnect
   - Handle errors with logging

4. Add performance requirements metadata (background execution)

**App/Input IDs for LG webOS:**

- Plex: `cdp-30` (may vary, user can update)
- YouTube: `youtube.leanback.v4`
- HDMI2: `com.webos.app.hdmi2`

**Deliverables:**

- 9+ `AppIntent` implementations
- Error handling and logging
- Command execution with connection lifecycle management

**Estimated Time:** 2-2.5 hours

**Complexity:** Medium-High (many similar intents, parameter handling)

---

## Step 10: Design Widget Layout

**Objective:** Create an intuitive and visually appealing widget layout with all controls.

**Layout Design (systemLarge recommended):**

```
┌─────────────────────────────────┐
│ ● Status      [Plex]  [YouTube] │ ← Row 1: Status dot + App launchers
│                                  │
│      VOL+              ↑         │ ← Row 2: Volume up + Up arrow
│      VOL-      ←  OK  →          │ ← Row 3: Volume down + Nav arrows + OK
│                        ↓         │ ← Row 4: Down arrow
│                                  │
│   [PLAY/PAUSE]    [RETURN]       │ ← Row 5: Playback + Return
│                                  │
│   [POWER OFF]     [HDMI2]        │ ← Row 6: Power + Input switcher
└─────────────────────────────────┘
```

**Agent Tasks:**

1. Update `LGTVRemoteWidgetView.swift`:

   - Use GeometryReader to make layout responsive
   - Create button style modifier for consistent appearance
   - Status dot: Circle with green (connected) or red (disconnected)
   - Volume buttons: "+" and "-" with SF Symbols `speaker.wave.3.fill`
   - Play/Pause: SF Symbol `play.fill` or `pause.fill`
   - Navigation arrows: SF Symbols `arrow.up`, `arrow.down`, etc.
   - OK button: SF Symbol `circle.fill` with "OK" label
   - Return: SF Symbol `arrow.uturn.backward`
   - Power: SF Symbol `power`
   - App launchers: Custom labels or SF Symbols
   - HDMI2: SF Symbol `cable.connector.horizontal`

2. Apply `.widgetButton` modifier with intent parameter
3. Add proper spacing and padding for touch targets
4. Test layout in Widget Gallery previews

**Deliverables:**

- Polished widget layout in `LGTVRemoteWidgetView.swift`
- SF Symbols for visual clarity
- Responsive design for systemMedium (simplified) and systemLarge
- Widget preview provider for Xcode canvas

**Estimated Time:** 2-3 hours

**Complexity:** Medium (SwiftUI layout, design aesthetics)

---

## Step 11: Add App Group Support

**Objective:** Enable data sharing between main app and widget extension using App Groups.

**Technical Details:**

- App Group ID: `group.com.DaraConsultingInc.LGTVRemoteWidget`
- Share connection status, last update timestamp, TV name (optional)
- Use UserDefaults suite: `UserDefaults(suiteName:)`

**Human Tasks:**

1. In Xcode project settings:

   - Select main app target → Signing & Capabilities → "+ Capability" → App Groups
   - Add App Group: `group.com.DaraConsultingInc.LGTVRemoteWidget`
   - Repeat for widget extension target

**Agent Tasks:**

1. Update `AppGroupManager.swift` in `LGTVControl` framework:

   - Initialize with suite name
   - Provide accessors for shared data:
     - `lastConnectionStatus: ConnectionStatus`
     - `lastUpdateTime: Date`
     - `tvName: String?`

2. Update main app to write status after connection
3. Update widget timeline provider to read status

**Deliverables:**

- Entitlements files updated with App Group capability
- `AppGroupManager` with shared data accessors
- Integration in main app and widget

**Estimated Time:** 30-45 minutes

**Complexity:** Low (straightforward capability addition)

---

## Step 12: Testing on Physical Device

**Objective:** Validate all functionality on real iPhone with LG TV on local network.

**Prerequisites:**

- iPhone with iOS 17+ connected via USB
- iPhone and LG TV on same Wi-Fi network
- TV powered on and LG Connect Apps enabled

**Human Tasks:**

1. Select iPhone as build target in Xcode
2. Build and run main app to device
3. Test connection flow:

   - Enter TV IP and MAC address
   - Tap Connect button
   - Enter pairing code displayed on TV screen
   - Verify success status and green dot

4. Close app and add widget to home screen:

   - Long press home screen → "+" button → Search "LG TV Remote"
   - Add systemLarge widget

5. Test each widget button:

   - Volume up/down (listen for TV volume change)
   - Play/Pause (open a streaming app first)
   - Navigation arrows (navigate TV menu)
   - OK button (select menu item)
   - Return button (go back)
   - App launchers (Plex, YouTube should open)
   - HDMI2 button (switch to HDMI 2 input)

6. Test power flow:

   - Press Power Off button on widget (TV should turn off)
   - Wait 10 seconds, press any control button (should send WOL and attempt command)

**Expected Issues:**

- Simulator cannot test: Local network access, WOL (requires physical device)
- First run may require "Allow Local Network Access" permission prompt
- App/Input IDs may differ by TV model (check LG developer docs or sniff traffic)
- Widget may take 30 seconds to update status dot after connection state changes

**Debugging Steps:**

1. Check Console.app logs for WebSocket errors
2. Use Xcode Network debugging to inspect WebSocket traffic
3. Verify TV responds to commands using browser WebSocket test:

   - Open Chrome DevTools → Console
   - Test: `ws = new WebSocket("ws://<TV_IP>:3000/"); ws.onmessage = console.log;`

**Deliverables:**

- Verified end-to-end functionality on physical device
- Documented any TV-model-specific app IDs or quirks
- List of issues encountered and resolutions

**Estimated Time:** 1-2 hours

**Complexity:** Medium (real-world debugging)

---

## Step 13: Handle Edge Cases & Error States

**Objective:** Improve robustness by handling common failure scenarios gracefully.

**Scenarios to Handle:**

1. TV offline (not responding to WebSocket)
2. Invalid IP/MAC address format
3. Network permission denied by user
4. Pairing rejected on TV
5. Command timeout (TV busy or unresponsive)
6. Client-key invalidated (user unpaired from TV settings)
7. Widget button pressed while TV is off
8. Multiple rapid button presses

**Agent Tasks:**

1. Add validation in main app:

   - IP address regex: `^(\d{1,3}\.){3}\d{1,3}$`
   - MAC address regex: `^([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}$`
   - Show inline error messages

2. Add timeout handling in `SSAPWebSocketClient`:

   - Set 5-second timeout for WebSocket connect
   - Set 10-second timeout for command responses
   - Throw specific errors (`.timeout`, `.connectionFailed`, etc.)

3. Handle permission denial:

   - Detect Local Network permission status
   - Show alert with Settings deep link if denied

4. Add retry logic for widget intents:

   - If command fails, try WOL + retry once
   - Log error but don't crash widget

5. Add debouncing for rapid button presses:

   - Track last command timestamp
   - Ignore presses within 500ms of previous

6. Handle client-key invalidation:

   - Detect "registration required" error response
   - Clear stored credentials
   - Show "Re-pairing required" message in widget status

**Deliverables:**

- Input validation in main app UI
- Comprehensive error handling in framework
- User-friendly error messages
- Retry logic for transient failures
- Debouncing for button presses

**Estimated Time:** 2-3 hours

**Complexity:** Medium-High (many edge cases)

---

## Step 14: Polish UI & User Experience

**Objective:** Enhance visual design, animations, and feedback for professional feel.

**Improvements:**

1. Main app:

   - Add app icon (TV remote graphic)
   - Add loading spinner during connection
   - Add success checkmark animation on pairing
   - Improve form layout with sections and labels
   - Add "Forget TV" button to clear credentials
   - Add dark mode support with adaptive colors

2. Widget:

   - Add subtle shadows to buttons for depth
   - Add haptic feedback on button press (via intent)
   - Add animated status dot pulse when connecting
   - Add widget configuration to choose systemMedium vs systemLarge
   - Add accessibilityLabels for VoiceOver support

**Agent Tasks:**

1. Update `ContentView.swift`:

   - Add loading overlay with `ProgressView`
   - Add success animation using `.transition()` and `.animation()`
   - Improve spacing and alignment
   - Add "Forget TV" button with confirmation alert
   - Test in light and dark mode

2. Update widget view:

   - Add `.shadow()` modifiers to buttons
   - Add accessibility labels: `.accessibilityLabel("Volume Up")`
   - Create widget configuration AppIntent (optional)

3. Create app icon asset:

   - Use SF Symbol `tv.remote` as base or custom design
   - Generate all required sizes (AppIcon.appiconset)

**Deliverables:**

- Polished main app UI with animations
- Accessible widget with VoiceOver support
- App icon (placeholder or custom design)
- Dark mode tested and working

**Estimated Time:** 2-3 hours

**Complexity:** Medium (design and polish)

---

## Step 15: App Review Preparation & Entitlements Documentation

**Objective:** Prepare app for potential App Store submission by ensuring compliance with Apple's guidelines.

**Required Entitlements & Permissions:**

1. **Local Network Access:**

   - Info.plist key: `NSLocalNetworkUsageDescription`
   - Value: "This app connects to your LG TV on the local network to send remote control commands."
   - Required for WebSocket connection to TV

2. **Bonjour Services (Optional for SSDP):**

   - Info.plist key: `NSBonjourServices`
   - Value: `["_lge-remote._tcp"]`
   - Not strictly required for this version (manual IP entry), but include for future SSDP discovery

3. **App Groups:**

   - Entitlement: `com.apple.security.application-groups`
   - Value: `["group.com.DaraConsultingInc.LGTVRemoteWidget"]`
   - Required for widget data sharing

4. **Keychain Access Groups:**

   - Entitlement: `keychain-access-groups`
   - Value: `["$(AppIdentifierPrefix)com.DaraConsultingInc.LGTVRemoteWidget"]`
   - Required for shared credential storage

**App Store Review Considerations:**

1. **Privacy:**

   - App does NOT collect user data or send information to remote servers
   - All communication is local (TV on same network)
   - Include privacy policy statement in app description

2. **Functionality:**

   - App must clearly state it requires LG webOS TV (2014+ models)
   - Include screenshots showing setup flow and widget
   - Provide demo credentials or video for reviewers (or note that LG TV is required)

3. **Widgets:**

   - Widget functionality must be clearly documented
   - Widget should handle missing credentials gracefully (show "Setup Required" message)

**Agent Tasks:**

1. Create `PrivacyInfo.xcprivacy` (Apple's Privacy Manifest):

   - Declare no tracking domains
   - Declare no required reason APIs used

2. Update README with:

   - Required permissions and why
   - LG TV compatibility list (webOS 2.0+)
   - Setup instructions

3. Add error state in widget for unconfigured app:

   - If no credentials, show "Open app to connect TV" message

4. Create `App Store Review Notes.md`:

   - Document that reviewers need LG webOS TV on local network
   - Suggest Test Flight testing before App Store submission

**Deliverables:**

- Privacy manifest file
- Complete entitlements documentation
- Widget handles unconfigured state
- App Store review notes document

**Estimated Time:** 1-1.5 hours

**Complexity:** Low (documentation and compliance)

---

## Step 16: Optimization & Performance Tuning

**Objective:** Ensure app and widget are efficient, responsive, and battery-friendly.

**Optimization Areas:**

1. **WebSocket Connection Management:**

   - Use on-demand connections (connect → command → disconnect)
   - Avoid keeping connection open unnecessarily
   - Implement connection pooling if multiple commands needed

2. **Widget Timeline Refresh:**

   - Minimize timeline reloads (use `.atEnd` policy)
   - Only check connection status every 60 seconds
   - Use App Group to share status instead of redundant checks

3. **Wake-on-LAN Efficiency:**

   - Cache last wake attempt timestamp
   - Don't send WOL if sent within last 10 seconds
   - Avoid repeated WOL attempts for offline TV

4. **Memory & CPU:**

   - Profile with Instruments (Allocations, Time Profiler)
   - Ensure no memory leaks in WebSocket lifecycle
   - Optimize JSON encoding/decoding

5. **Battery Impact:**

   - Minimize background networking
   - Widget should not actively poll unless user views it
   - Use low-power mode detection to reduce activity

**Agent Tasks:**

1. Add connection pooling in `LGTVControlManager`:

   - Track connection state
   - Reuse connection if open and recent (< 5 seconds)

2. Add caching in widget timeline provider:

   - Store last status check result
   - Return cached entry if recent (< 30 seconds)

3. Profile app with Xcode Instruments:

   - Check for leaks in WebSocket lifecycle
   - Verify CPU usage during commands

4. Add low-power mode detection:

   - Use `ProcessInfo.processInfo.isLowPowerModeEnabled`
   - Reduce widget refresh rate in low-power mode

**Deliverables:**

- Optimized connection management
- Cached timeline provider
- Profiling results and improvements
- Low-power mode handling

**Estimated Time:** 1.5-2 hours

**Complexity:** Medium (performance profiling)

---

## Step 17: Unit & Integration Testing

**Objective:** Add automated tests for critical functionality to prevent regressions.

**Test Coverage:**

1. **Unit Tests for LGTVControl Framework:**

   - SSAP message encoding/decoding
   - Wake-on-LAN magic packet generation
   - Keychain save/load operations
   - MAC address parsing and validation
   - IP address validation

2. **Integration Tests:**

   - WebSocket connection lifecycle (requires mock server)
   - Pairing flow (with mock responses)
   - Command sending and response handling

3. **UI Tests:**

   - Main app connection flow
   - Input validation error messages
   - Widget appearance in Widget Gallery

**Agent Tasks:**

1. Create test targets:

   - `LGTVControlTests` for framework unit tests
   - `LG TV Remote WidgetTests` for app tests
   - `LG TV Remote WidgetUITests` for UI automation

2. Implement unit tests:

   - `SSAPMessageTests.swift`: Test JSON encoding/decoding
   - `WakeOnLANTests.swift`: Test magic packet generation
   - `KeychainManagerTests.swift`: Test save/load/delete (use test keychain)
   - `ValidationTests.swift`: Test IP/MAC validation regexes

3. Implement mock WebSocket server:

   - Use NWListener to create local test server
   - Return mock SSAP responses
   - Test pairing flow with mock server

4. Add UI test:

   - Test connection flow with invalid IP (expect error)
   - Test pairing code alert appearance

**Deliverables:**

- Unit tests with >70% code coverage for framework
- Integration tests for WebSocket flow
- UI tests for main app
- CI-ready test suite (can run in Xcode Cloud)

**Estimated Time:** 3-4 hours

**Complexity:** High (mock server, async testing)

---

## Step 18: Create Comprehensive README

**Objective:** Document project for future developers and users.

**README Sections:**

1. **Project Overview:**

   - What is this app?
   - Key features
   - System requirements (iOS 17+, LG webOS TV)

2. **Architecture:**

   - Diagram showing app, framework, widget
   - Data flow (Keychain, App Group)
   - Technology stack (SwiftUI, WidgetKit, Network framework)

3. **Setup Instructions:**

   - Clone repository
   - Open in Xcode
   - Configure Development Team
   - Update Bundle Identifier (if needed)
   - Build and run on device

4. **LG TV Configuration:**

   - How to enable LG Connect Apps
   - How to find IP and MAC address
   - Pairing process explanation

5. **Usage:**

   - Initial app setup
   - Adding widget to home screen
   - Widget controls explanation

6. **Development:**

   - Project structure
   - Adding new commands
   - Debugging tips

7. **Known Issues:**

   - Simulator limitations
   - TV-model-specific quirks
   - Future improvements (SSDP discovery, HomeKit)

8. **License & Credits:**

   - MIT License (or your choice)
   - LG SSAP protocol references

**Agent Tasks:**

1. Create `README.md` with all sections above
2. Add code examples for common tasks:

   - Adding a new SSAP command
   - Adding a new widget button

3. Add architecture diagram (ASCII art or reference to diagram file)
4. Add screenshots placeholders (human will add actual images)
5. Add troubleshooting section with common errors

**Deliverables:**

- Comprehensive `README.md`
- Code examples and diagrams
- Clear setup and usage instructions

**Estimated Time:** 1.5-2 hours

**Complexity:** Low (documentation)

---

## Live README System

### Purpose

This system ensures the `README.md` stays synchronized with project progress throughout development. As each step is completed, the README's status table is updated to reflect current state, providing a living document that shows exactly what's been done and what remains.

### Structure

The `README.md` will contain a **Progress Tracking** section near the top with this format:

#### Progress Tracking

| Step | Description | Status | Notes |

|------|-------------|--------|-------|

| 1 | LG TV Prerequisites Setup | ✅ Done | TV IP: 192.168.1.100, MAC: A0:B1:C2:D3:E4:F5 |

| 2 | macOS Development Environment Setup | ✅ Done | Deployment target set to iOS 17.0 |

| 3 | Create Shared Framework | 🚧 In Progress | Core models implemented |

| 4 | Implement SSAP Protocol & Pairing Flow | ⏳ Pending | |

| 5 | Implement Wake-on-LAN | ⏳ Pending | |

| 6 | Implement Keychain Storage | ⏳ Pending | |

| 7 | Build Main App UI | ⏳ Pending | |

| 8 | Create Widget Extension | ⏳ Pending | |

| 9 | Implement App Intents | ⏳ Pending | |

| 10 | Design Widget Layout | ⏳ Pending | |

| 11 | Add App Group Support | ⏳ Pending | |

| 12 | Testing on Physical Device | ⏳ Pending | |

| 13 | Handle Edge Cases & Error States | ⏳ Pending | |

| 14 | Polish UI & UX | ⏳ Pending | |

| 15 | App Review Preparation | ⏳ Pending | |

| 16 | Optimization & Performance | ⏳ Pending | |

| 17 | Unit & Integration Testing | ⏳ Pending | |

| 18 | Create Comprehensive README | ⏳ Pending | |

### Status Indicators

- ⏳ **Pending**: Not yet started
- 🚧 **In Progress**: Currently working on this step
- ✅ **Done**: Completed and verified
- ⚠️ **Blocked**: Cannot proceed due to dependency or issue
- ❌ **Skipped**: Intentionally not implemented

### Update Protocol

1. **Before starting a step:**

   - Update status to 🚧 In Progress
   - Add start timestamp in Notes column (optional)

2. **During the step:**

   - Add brief notes about key decisions or blockers
   - Update notes with relevant identifiers (e.g., "Bundle ID updated to X")

3. **After completing a step:**

   - Change status to ✅ Done
   - Add completion summary in Notes (e.g., "All 9 intents implemented, tested on device")
   - Update related sections of README if architecture changes

4. **If blocked:**

   - Change status to ⚠️ Blocked
   - Document blocker in Notes with clear description
   - Notify human if human action required

### Automated Updates

The agent will:

- Update the progress table automatically after completing each implementation step
- Add new sections to README as features are implemented (e.g., add API documentation when framework is complete)
- Keep the table synchronized with actual codebase state
- Flag any discrepancies between plan and implementation

### Human Responsibilities

The human will:

- Mark steps requiring manual action (Xcode GUI, provisioning) as Done after completion
- Add screenshots to README after UI is implemented
- Update Notes column with environment-specific details (IP addresses, team IDs, etc.)
- Verify that agent's completion claims match actual functionality

### Example Workflow

```
Step 3 begins:
→ Agent updates table: "3 | Create Shared Framework | 🚧 In Progress | Starting implementation"
→ Agent implements all files
→ Agent updates table: "3 | Create Shared Framework | ✅ Done | Framework created with 8 files, public API tested"
→ Agent adds "Framework API" section to README with usage examples
```

### Sync Verification

At the end of each work session, the agent will:

1. Review all steps marked ✅ Done
2. Verify corresponding code exists in repository
3. Run sanity checks (build succeeds, tests pass)
4. Update README timestamp: "Last updated: 2025-10-23 14:30"

This ensures the plan and README remain the single source of truth throughout the project lifecycle.

---

## Summary

This plan provides a complete roadmap from zero to a functional LG TV Remote Widget app with 18 detailed steps covering setup, architecture, implementation, testing, and polish. Each step includes technical details, deliverables, and estimated time/complexity. The Live README System ensures documentation stays synchronized with progress throughout development.

**Total Estimated Time:** 25-35 hours of active development

**Key Technologies:**

- SwiftUI (main app UI)
- WidgetKit + App Intents (interactive widget)
- URLSessionWebSocketTask (LG SSAP protocol)
- Network framework (Wake-on-LAN UDP)
- Security framework (Keychain storage)
- App Groups (data sharing)

**Prerequisites:**

- Xcode 15+ with iOS 17+ SDK
- iPhone with iOS 17+ for testing
- LG webOS TV (2014+ model) on same Wi-Fi network
- Apple Developer account (free tier sufficient for testing)

The plan is designed to be executed step-by-step, with clear handoff points between human (Xcode GUI tasks) and agent (code generation) responsibilities.