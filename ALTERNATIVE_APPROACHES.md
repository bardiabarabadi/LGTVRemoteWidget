# Alternative Approaches to Try

While waiting for AI response, here are alternative approaches we can try:

## Approach 1: Try More Permissions (DONE)

Added these additional permissions:
- `CONTROL_MOUSE_AND_KEYBOARD` - Might be needed for pointer socket
- `CONTROL_INPUT_POINTER` - Direct pointer control
- `CONTROL_TV_SCREEN` - TV screen control
- `CONTROL_TV_STANBY` - Standby control
- `READ_CURRENT_CHANNEL` - Channel info
- `READ_RUNNING_APPS` - Running apps
- `READ_TV_CURRENT_TIME` - Time info
- `READ_LGE_SDX` - LG specific
- `READ_LGE_TV_INPUT_EVENTS` - Input events
- `READ_TV_CHANNEL_LIST` - Channel list
- `WRITE_SETTINGS` - Settings write
- `WRITE_NOTIFICATION_TOAST` - Notifications

**Test this first!** Clear credentials and re-pair.

---

## Approach 2: Use Input Commands Instead of Pointer Socket

Instead of using `getPointerInputSocket`, we might be able to send button commands via standard SSAP URIs:

```swift
// Try these URIs:
ssap://com.webos.service.tv.keymanager/processKeyInput
ssap://com.webos.service.networkinput/sendKeyEvent
ssap://system.notifications/createToast  // For testing
```

---

## Approach 3: Use Mouse/Pointer Commands

Try using mouse movement API instead:

```swift
// Request mouse socket instead
ssap://com.webos.service.networkinput/getMouseInputSocket
```

---

## Questions for AI:

1. **Main Question:** What exact permissions are needed for `getPointerInputSocket` on webOS 22/23?

2. **Alternative APIs:** What other APIs exist for sending navigation buttons?
   - `processKeyInput`?
   - `sendKeyEvent`?
   - Direct SSAP commands for UP/DOWN/LEFT/RIGHT/ENTER/BACK?

3. **Complete Permission List:** What are ALL valid webOS SSAP permissions?

4. **TV Model Specific:** Does LG 65UT7000 (webOS 23.23.30) support pointer input socket at all?

5. **Workarounds:** How do other remote control apps handle navigation on webOS 22+?

---

## If AI Says Permission Doesn't Exist:

We might need to use a different approach entirely:

### Option A: Legacy Button Commands
Try sending individual SSAP commands for each button:
```swift
ssap://tv/channelUp
ssap://tv/channelDown  
// etc.
```

### Option B: Virtual Keyboard
Use text input socket and send special key codes

### Option C: External Input
Use HDMI-CEC or other external control methods

---

## Current Status:

✅ WOL working
✅ Volume working
✅ HDMI working
✅ Apps working
✅ Power Off working
❌ Navigation - 401 insufficient permissions

**Next:** Get AI answer, then try one of these approaches!
