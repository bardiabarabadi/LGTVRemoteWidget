# Status Update - Navigation & Power Issues

## Changes Made (Round 2)

### 1. Power On Button - NOW ALWAYS AVAILABLE ✅
**Problem:** Power On button was only shown when connected, but you need it when disconnected!

**Fix:** Moved "Wake TV (WOL)" button to the Connection section, always available (only disabled while connecting).

**Location:** Now in "Connection" section, right after Disconnect button.

---

### 2. Navigation Commands - TRYING NEW URIs

**Problem:** Still getting 404 errors with `tv.keymanager` URIs

**New Attempt:** Changed to `com.webos.service.networkinput/sendKeyCommand`

```swift
// OLD (404s):
"ssap://com.webos.service.tv.keymanager/processKeyInput"

// NEW (try this):
"ssap://com.webos.service.networkinput/sendKeyCommand"
```

**Parameters remain the same:**
- `{"key": "UP"}`
- `{"key": "DOWN"}`
- `{"key": "LEFT"}`
- `{"key": "RIGHT"}`
- `{"key": "ENTER"}`

---

### 3. Home and Back Buttons - USING LAUNCHER ✅
**These should definitely work:**

```swift
// Home button
"ssap://system.launcher/open" with {"target": "home"}

// Back button
"ssap://system.launcher/close"
```

These use the same launcher API that works for launching apps, so they should work!

---

### 4. Enhanced Wake-on-LAN

**Improvements:**
- Now tries BOTH port 9 and port 7
- Added detailed logging to see exactly what's being sent
- Sends to broadcast + direct IP for both ports

**What to check in logs:**
```
[WakeOnLAN] 📡 Sending magic packet to MAC: 34:E6:E6:F9:05:50
[WakeOnLAN] 📤 Sending to broadcast 255.255.255.255:9
[WakeOnLAN] 📤 Sending to specific IP 10.0.0.14:9
[WakeOnLAN] 📤 Sending to broadcast 255.255.255.255:7
[WakeOnLAN] 📤 Sending to specific IP 10.0.0.14:7
[WakeOnLAN] ✅ Magic packets sent successfully
```

---

## Current UI Layout

### Connection Section
```
[Connect]
[Disconnect]
[Wake TV (WOL)] ← ALWAYS AVAILABLE NOW!
```

### Test Commands Section (when connected)
```
Volume: [Vol +] [Vol −] [Mute]
HDMI: [HDMI 1] [HDMI 2] [HDMI 3]
Apps: [Plex] [YouTube]

Navigation:
[Home] [Back] ← These should work!

"Arrow keys may not work on webOS 23"

     [↑]
[←] [OK] [→]  ← Try these with networkinput
     [↓]

[Power Off]
```

---

## Testing Instructions

### 1. Test Power On (IMPORTANT!)
**When TV is OFF and you're DISCONNECTED:**
1. Look at Connection section
2. Tap "Wake TV (WOL)" button
3. Watch console logs for WOL packets
4. Wait 5-10 seconds
5. Check if TV turns on

**If it doesn't work, check:**
- TV setting: Settings → General → Network → LG Connect Apps (should be ON)
- TV setting: Settings → General → Quick Start+ (try enabling this)
- TV may need to be in standby mode, not fully powered off

### 2. Test Home and Back
These should definitely work since they use system.launcher:
- Tap "Home" → Should go to TV home screen
- Tap "Back" → Should close current app/menu

### 3. Test Arrow Keys
- Try the arrow keys and OK button
- Check console for 404 errors vs success
- If still 404, we need to ask AI with internet access for correct URIs

---

## For AI with Internet Access

Use the **RESEARCH_QUERY.md** file to ask an AI with internet access:

**Copy this to AI:**

```
I'm developing a remote control app for LG webOS 23 TVs (specifically LG 65UT7000 running webOS 23.23.30) using the SSAP protocol over WebSocket.

What's Working:
- Volume commands: ssap://audio/volumeUp ✅
- App launching: ssap://system.launcher/launch ✅
- Power off: ssap://system/turnOff ✅
- Home: ssap://system.launcher/open with {"target": "home"} ✅
- Back: ssap://system.launcher/close ✅

What's NOT Working (404 errors):
- Navigation arrows (UP, DOWN, LEFT, RIGHT)
- OK/ENTER button

What I've tried (ALL give 404):
1. ssap://com.webos.service.ime/sendKey with {"key": "UP"}
2. ssap://com.webos.service.tv.keymanager/processKeyInput with {"key": "UP"}
3. ssap://com.webos.service.networkinput/sendKeyCommand with {"key": "UP"}

Question: What are the CORRECT SSAP URIs for arrow key navigation and OK/Enter button on webOS 23?

Please search recent documentation from:
- lgtv2 Node.js library
- PyLGTV Python library  
- node-red-contrib-lgtv
- OpenHAB LG webOS binding
- Any webOS 23 specific documentation

I need the exact SSAP URIs that work on webOS 23.
```

---

## Files Modified

1. **ContentView.swift**
   - Moved "Wake TV" button to Connection section (always available)
   - Changed navigation URIs to `networkinput/sendKeyCommand`
   - Added Home and Back buttons using `system.launcher`
   - Removed duplicate Power On button from test commands

2. **WakeOnLAN.swift**
   - Now tries both port 9 and port 7
   - Added detailed logging
   - Enhanced retry logic

3. **RESEARCH_QUERY.md** (NEW)
   - Complete research query for AI with internet access

4. **NAVIGATION_ALTERNATIVES.md** (NEW)
   - List of alternative URIs to try

---

**Status:** Ready to test - Power On now always available, navigation using new URIs  
**Next:** Test and use RESEARCH_QUERY.md if navigation still has issues  
**Date:** October 23, 2025 12:05 AM
