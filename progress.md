# LG TV Remote Widget - Progress Tracker

## 📋 Quick Checklist

### Step 1: TV Setup
- [x] Enable "LG Connect Apps" on TV
- [x] Get TV IP address: 10.0.0.14
- [x] Get TV MAC address: 34:E6:E6:F9:05:50
- [x] Test network connectivity (ping TV)

### Step 2: Xcode Setup
- [x] Set deployment target to iOS 17.0 
- [x] Configure signing & team
- [x] Add network permissions to Info.plist
- [x] Connect test device

### Step 3: Shared Framework
- [x] Create `LGTVControl` framework target
- [x] Implement WebSocket client
- [x] Add SSAP protocol handler (message types; full pairing/flow in Step 4)
- [x] Add Keychain wrapper
- [x] Add Wake-on-LAN sender
- [x] Setup App Group sharing (entitlements + UserDefaults suite)

### Step 4: SSAP Pairing Flow
- [x] Expand SSAP request/response models for registration
- [x] Implement WebSocket register & pairing handling
- [x] Update control manager connect/pair APIs
- [ ] Run on-device pairing test (awaiting user)

### Step 5: Main App
- [x] Build SwiftUI setup screen
- [x] Add IP/MAC input fields
- [x] Wire up pairing prompts in UI
- [ ] Test WebSocket connection from UI
- [ ] Persist credentials via Keychain from UI

### Step 6: Widget Extension
- [ ] Create Widget Extension target
- [ ] Setup App Intents (iOS 17+)
- [ ] Design widget layout (medium/large)
- [ ] Add interactive controls:
  - [ ] Power button
  - [ ] Volume +/-
  - [ ] Playback controls
  - [ ] Navigation arrows
  - [ ] App launchers (Plex, YouTube)
  - [ ] HDMI2 input switcher
- [ ] Add status indicator

### Step 7: Testing & Polish
- [ ] Test on physical device
- [ ] Test all widget buttons
- [ ] Test Wake-on-LAN
- [ ] Verify App Group data sharing
- [ ] Test pairing flow
- [ ] Polish UI/UX

### Step 8: Deployment
- [ ] App Store assets
- [ ] Privacy policy
- [ ] Submit for review

---

**Current Status:** 🚧 In Progress
- Oct 23: Updated WebSocket client to send register JSON as text frames to prevent the TV from closing the socket; awaiting on-device validation.

**Last Updated:** Oct 23, 2025
