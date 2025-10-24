# Navigation Debugging Guide

## Enhanced Logging Applied

I've added extensive logging to diagnose the navigation issue. Here's what will now be logged:

### When You Connect to TV:
```
[LGTVControlManager] 🎮 Starting pointer input setup...
[LGTVControlManager] 🎮 Setting up pointer input socket...
[LGTVControlManager] 📍 Got pointer socket path: wss://...
[PointerInput] 🔌 Connecting to pointer socket: wss://...
[PointerInput] 🚀 Starting WebSocket task...
[PointerInput] 🔓 Pointer socket opened
[PointerInput] ✅ Pointer socket connected and ready
[LGTVControlManager] ✅ Pointer input ready
[LGTVControlManager] ✅ Pointer input setup complete
```

### When You Press an Arrow Key/OK:
```
[LGTVControlManager] 🎮 sendButton(UP) called
[LGTVControlManager] 🔍 Current status: connected
[LGTVControlManager] 🔍 Pointer input exists: true
[LGTVControlManager] 📤 Delegating to PointerInputClient...
[PointerInput] 🔍 sendButton called - isConnected: true, task: exists
[PointerInput] 📤 Sending button: UP
[PointerInput] 📝 Message bytes: 74 79 70 65 3A 62 75 74 74 6F 6E 0A 6E 61 6D 65 3A 55 50 0A 0A
[PointerInput] 📝 Message length: 21 bytes
[PointerInput] ✅ Button sent successfully: UP
[LGTVControlManager] ✅ Button sent successfully via manager
```

### If It Fails:
```
[LGTVControlManager] 🎮 sendButton(UP) called
[LGTVControlManager] 🔍 Current status: connected
[LGTVControlManager] 🔍 Pointer input exists: false  ← Problem here!
[LGTVControlManager] ⚠️ Pointer input not set up, attempting to connect...
```

OR:

```
[PointerInput] 🔍 sendButton called - isConnected: false, task: nil  ← Socket disconnected!
[PointerInput] ❌ Cannot send button - not connected! isConnected: false, task: false
```

---

## Test Instructions

### 1. Clean Build
```bash
# In Xcode:
Cmd + Shift + K  (Clean)
Cmd + B          (Build)
Cmd + R          (Run with console open!)
```

### 2. Connect to TV
Watch the console output. You should see:
1. Main WebSocket connection
2. Pointer input setup starting
3. Pointer socket path received
4. Pointer socket connecting
5. Pointer socket opened
6. Setup complete

**If you DON'T see all these messages, there's a problem with the initial setup.**

### 3. Press an Arrow Key
Watch for the detailed logs. You should see:
- `sendButton(UP)` called
- Pointer input exists: `true`
- isConnected: `true`, task: `exists`
- Message bytes (hex dump)
- Button sent successfully

**If you see `isConnected: false` or `task: nil`, the socket disconnected.**

### 4. Check for Error Messages
Look for:
- ❌ "Cannot send button - not connected"
- ❌ "Failed to send button"
- ❌ "Receive error"
- 🔒 "Pointer socket closed"

---

## Common Issues and What to Look For

### Issue 1: Pointer Socket Never Sets Up
**Logs:**
```
[LGTVControlManager] 🎮 Starting pointer input setup...
[LGTVControlManager] ❌ Failed to setup pointer input
```

**Cause:** TV didn't provide socket path, or request failed

**Check:**
- Is main WebSocket connected? (`status: connected`)
- Did TV respond to `getPointerInputSocket` request?

### Issue 2: Pointer Socket Disconnects After Setup
**Logs:**
```
[PointerInput] ✅ Pointer socket connected and ready
... later ...
[PointerInput] 🔒 Pointer socket closed: 1000
[PointerInput] 🔍 sendButton called - isConnected: false, task: nil
```

**Cause:** TV closed the socket (timeout, error, or TV behavior)

**Solution:** Socket needs to be kept alive with periodic receives (now implemented)

### Issue 3: Socket Connected but Button Not Sent
**Logs:**
```
[PointerInput] 🔍 sendButton called - isConnected: true, task: exists
[PointerInput] ❌ Failed to send button: <error message>
```

**Cause:** Message format wrong, or socket in bad state

**Check:** Message bytes in hex (should be: `type:button\nname:UP\n\n`)

### Issue 4: Manager Says "Not Connected" Despite Being Connected
**Logs:**
```
[LGTVControlManager] 🔍 Pointer input exists: false
[LGTVControlManager] ⚠️ Pointer input not set up, attempting to connect...
```

**Cause:** `pointerInput` variable is nil (setup failed or was cleared)

**Check:** Did initial setup succeed? Was disconnect() called?

---

## What I Changed

### 1. Added Keep-Alive Message Receiving
The pointer socket might close if we don't actively receive messages. I added `receiveMessage()` that continuously listens for messages from the TV, keeping the connection alive.

### 2. Increased Connection Wait Time
Changed from 500ms to 1000ms (1 second) to give the socket more time to establish.

### 3. Added Extensive Logging
Every step now logs:
- Connection state
- isConnected flag
- Task existence
- Message format (hex dump)
- Success/failure at each step

### 4. Better Error Handling
Now catches and logs specific send failures with detailed error messages.

---

## Expected Results

### Working Scenario:
1. Connect to TV → see setup complete ✅
2. Press UP arrow → see button sent successfully ✅
3. TV responds to button press ✅

### Problem Scenario A (Setup Fails):
1. Connect to TV → don't see "Pointer input setup complete" ❌
2. Press UP arrow → see "Pointer input not set up" ❌
3. Logs show: setup attempted but failed

**Action:** Check if TV supports pointer input socket (webOS 22+)

### Problem Scenario B (Socket Disconnects):
1. Connect to TV → setup complete ✅
2. Wait a few seconds
3. Press UP arrow → see "isConnected: false" ❌
4. Logs show: socket closed between setup and button press

**Action:** Keep-alive now implemented, should fix this

### Problem Scenario C (Button Format Wrong):
1. Connect to TV → setup complete ✅
2. Press UP arrow → see "Button sent successfully" but TV doesn't respond ❌

**Action:** Check hex dump of message format

---

## Testing Checklist

After rebuilding, test in this order:

- [ ] Connect to TV
- [ ] Verify logs show: "Pointer input setup complete"
- [ ] Wait 5 seconds (test socket stays alive)
- [ ] Press UP arrow
- [ ] Check logs for "Button sent successfully"
- [ ] Verify TV responds to button
- [ ] Try all navigation buttons (UP, DOWN, LEFT, RIGHT)
- [ ] Try OK button (ENTER)
- [ ] Try BACK button
- [ ] Try HOME button

---

## Share These Logs

When testing, please share:
1. **Connection logs** - from connect button to "setup complete"
2. **Button press logs** - full output when you press an arrow key
3. **Any error messages** - especially RED ❌ messages

This will tell us exactly where it's failing!

---

**Date:** October 24, 2025 1:00 AM
**Status:** Enhanced logging ready for diagnosis 🔍
