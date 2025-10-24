# Research Query for AI with Internet Access

## Question 1: LG webOS 23 Navigation Commands

I'm developing a remote control app for LG webOS 23 TVs (specifically LG 65UT7000 running webOS 23.23.30) using the SSAP protocol over WebSocket.

**What's Working:**
- Connection via `wss://TV_IP:3001/` ✅
- Registration and pairing ✅
- Volume commands: `ssap://audio/volumeUp`, `ssap://audio/volumeDown` ✅
- Input switching: `ssap://tv/switchInput` ✅
- App launching: `ssap://system.launcher/launch` ✅
- Power off: `ssap://system/turnOff` ✅

**What's NOT Working (404 errors):**
- Navigation arrows and OK button
- Back button

**What I've Tried:**

1. `ssap://com.webos.service.ime/sendKey` with `{"key": "UP"}` → **404 error**
2. `ssap://com.webos.service.ime/sendEnterCommand` → **404 error**
3. `ssap://com.webos.service.tv.keymanager/processKeyInput` with `{"key": "UP"}` → **404 error**

**Question:** What are the CORRECT SSAP URIs for navigation commands (arrow keys, OK/Enter, Back) on webOS 23? 

Please search for:
- Recent webOS SSAP protocol documentation
- Working examples from lgtv2, node-red-contrib-lgtv, or other community libraries
- Any webOS 23 specific changes to navigation commands
- Alternative URIs like `com.webos.service.networkinput`, `tv.keymanager`, `system.launcher`, etc.

---

## Question 2: Wake-on-LAN for LG webOS TVs

I'm trying to wake an LG 65UT7000 (webOS 23) from standby using Wake-on-LAN.

**Current Implementation:**
- Sending magic packet (FF:FF:FF:FF:FF:FF + 16x MAC address) 
- Sending to both broadcast (255.255.255.255:9) and specific IP (10.0.0.14:9)
- Using UDP
- Multiple retries
- TV MAC address: 34:E6:E6:F9:05:50

**Result:** Not working - TV doesn't wake up

**Questions:**
1. Does LG webOS 23 support Wake-on-LAN by default?
2. Is there a TV setting that needs to be enabled?
3. Are there alternatives to WOL for powering on LG webOS TVs remotely?
4. Should I use port 9 or a different port?
5. Does the TV need to be in "Quick Start" mode vs "Energy Saving" mode?
6. Are there any webOS-specific magic packet requirements?

---

## Expected Response Format

For navigation commands, please provide:
```
Working SSAP URIs for webOS 23:
- Arrow Up: ssap://...
- Arrow Down: ssap://...
- Arrow Left: ssap://...
- Arrow Right: ssap://...
- OK/Enter: ssap://...
- Back: ssap://...
- Home: ssap://...
```

For Wake-on-LAN:
- Whether it's supported on webOS 23
- Required TV settings
- Alternative methods if WOL doesn't work
- Any troubleshooting steps

---

## Additional Context

**TV Details:**
- Model: LG 65UT7000
- webOS Version: 23.23.30
- IP: 10.0.0.14
- MAC: 34:E6:E6:F9:05:50

**Development Environment:**
- iOS 17+ app using Swift
- URLSessionWebSocketTask for SSAP
- Network framework for WOL
- Successfully paired with client-key stored

**References to Search:**
- lgtv2 (Node.js library)
- PyLGTV (Python library)
- node-red-contrib-lgtv
- OpenHAB LG webOS binding
- LG Developer documentation
- GitHub issues/discussions about webOS 23 changes
