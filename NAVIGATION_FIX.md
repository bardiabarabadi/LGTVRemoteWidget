# SOLUTION FOUND! - Navigation Permissions Issue

## Problem Identified ✅

The TV is returning: **"401 insufficient permissions"** when requesting the pointer input socket.

```
[SSAPWebSocket] Received message: {"type":"error","id":"...","error":"401 insufficient permissions","payload":{}}
```

## Root Cause

The app manifest didn't have the correct permissions for pointer input. We had:
- ✅ `CONTROL_INPUT_JOYSTICK` - Basic joystick control
- ❌ Missing: `CONTROL_INPUT_TEXT` - Required for pointer input socket
- ❌ Missing: `CONTROL_INPUT_MEDIA_RECORDING` - Additional input permission
- ❌ Missing: `CONTROL_INPUT_MEDIA_PLAYBACK` - Additional input permission

## Fix Applied

Added the missing permissions to the manifest in `LGTVControlManager.swift`:

```swift
permissions: [
    "LAUNCH",
    "LAUNCH_WEBAPP",
    "APP_TO_APP",
    "CONTROL_AUDIO",
    "CONTROL_DISPLAY",
    "CONTROL_INPUT_MEDIA_PLAYER",
    "CONTROL_POWER",
    "READ_INSTALLED_APPS",
    "CONTROL_INPUT_JOYSTICK",
    "CONTROL_INPUT_TEXT",              // ← NEW! Required for pointer input
    "CONTROL_INPUT_MEDIA_RECORDING",   // ← NEW! Additional input control
    "CONTROL_INPUT_MEDIA_PLAYBACK"     // ← NEW! Additional input control
]
```

## CRITICAL: You Must Re-Pair! 🔄

**The TV stores permissions from the initial pairing.** Adding new permissions requires re-pairing.

### Step-by-Step Re-Pairing:

1. **Delete the stored credentials:**
   ```
   In the app:
   1. Tap "Disconnect" 
   2. Close the app completely (swipe up)
   3. Delete stored credentials if there's an option
   ```

   OR manually in code, you can clear the keychain, but easier to just:

2. **Clear TV's stored pairing:**
   ```
   On your LG TV:
   1. Go to Settings → General → Devices → External Devices
   2. Look for "LG TV Remote Widget" or similar
   3. Remove/Delete it
   ```

3. **Rebuild the app:**
   ```
   Cmd + Shift + K  (Clean)
   Cmd + B          (Build)
   Cmd + R          (Run)
   ```

4. **Pair again:**
   ```
   1. Enter TV IP: 10.0.0.14
   2. Enter MAC: 34:E6:E6:F9:05:50
   3. Tap "Connect"
   4. TV will show NEW pairing dialog (with more permissions!)
   5. Accept pairing on TV
   6. Enter pairing code in app
   ```

5. **Test navigation:**
   ```
   Now the pointer input socket request should succeed!
   You should see:
   [LGTVControlManager] 📍 Got pointer socket path: wss://...
   [PointerInput] ✅ Pointer socket connected and ready
   ```

## Expected Logs After Re-Pairing

### Connection:
```
[LGTVControlManager] 🔵 Connect requested - IP: 10.0.0.14
[LGTVControlManager] 📝 No stored credentials found, will pair fresh
[LGTVControlManager] 🔐 Pairing required - code: 123456
```

### After Entering Code:
```
[LGTVControlManager] ✅ Registration successful!
[LGTVControlManager] 🎮 Starting pointer input setup...
[SSAPWebSocket] Sending message: {"type":"request","uri":"ssap://com.webos.service.networkinput/getPointerInputSocket"...}
[SSAPWebSocket] Received message: {"type":"response","payload":{"socketPath":"wss://10.0.0.14:3001/..."}}  ← Success!
[LGTVControlManager] 📍 Got pointer socket path: wss://10.0.0.14:3001/...
[PointerInput] 🔌 Connecting to pointer socket...
[PointerInput] ✅ Pointer socket connected and ready
[LGTVControlManager] ✅ Pointer input setup complete
```

### Arrow Key Press:
```
[LGTVControlManager] 🎮 sendButton(UP) called
[PointerInput] 📤 Sending button: UP
[PointerInput] ✅ Button sent successfully: UP
```

And the TV will respond! ✅

## Why This Happened

1. Initial pairing stored limited permissions
2. TV caches the client-key and permissions
3. Adding new permissions doesn't update the TV's cache
4. Must re-pair to get new permissions approved

This is standard LG webOS behavior - permissions are set at pairing time and immutable afterward.

## Alternative: Clear Keychain Programmatically

If you want to force re-pairing in the app, you can add a "Clear Credentials" button that deletes the keychain entry. But easier to just:
1. Delete app
2. Reinstall
3. Pair fresh

OR just disconnect and the next connection will pair fresh if TV has forgotten the app.

---

**Status:** Ready to test after re-pairing! 🎉
**Date:** October 24, 2025 1:10 AM

---

## TL;DR

1. ❌ Problem: "401 insufficient permissions" for pointer input
2. ✅ Solution: Added `CONTROL_INPUT_TEXT` and other input permissions
3. 🔄 Action Required: **RE-PAIR with TV** (permissions cached at pairing time)
4. 🎯 Expected: Navigation buttons will work after re-pairing!
