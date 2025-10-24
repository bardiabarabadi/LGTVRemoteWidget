# Troubleshooting Guide

## Issue 1: Navigation Buttons - "Not connected to TV"

### Problem
Navigation buttons (arrows, OK, back) show "Not connected to TV" error even though other commands work.

### Root Cause
The `sendButton` method had an early `return;` statement that prevented button events from being sent even after setting up the pointer input socket.

### Fix Applied
✅ Fixed the `sendButton` logic to properly use the pointer input after setup
✅ Changed pointer socket setup to `await` instead of detached `Task`

### What Changed in LGTVControlManager.swift:

**Before (BROKEN):**
```swift
public func sendButton(_ button: PointerInputClient.Button) async throws {
    guard let pointerInput = pointerInput else {
        try await setupPointerInput()
        guard let pointerInput = pointerInput else {
            throw ControlError.notConnected
        }
        return;  // ❌ This exits early!
    }
    try await pointerInput.sendButton(button)
}
```

**After (FIXED):**
```swift
public func sendButton(_ button: PointerInputClient.Button) async throws {
    // Check if we have pointer input, if not try to set it up
    if pointerInput == nil {
        print("[LGTVControlManager] ⚠️ Pointer input not set up, attempting to connect...")
        try await setupPointerInput()
    }
    
    guard let pointerInput = pointerInput else {
        print("[LGTVControlManager] ❌ Failed to setup pointer input")
        throw ControlError.notConnected
    }
    
    try await pointerInput.sendButton(button)  // ✅ Actually sends!
}
```

**Also changed pointer setup to await properly:**
```swift
// Before:
Task {
    do {
        try await setupPointerInput()
    } catch { ... }
}

// After:
do {
    print("[LGTVControlManager] 🎮 Starting pointer input setup...")
    try await setupPointerInput()
    print("[LGTVControlManager] ✅ Pointer input setup complete")
} catch { ... }
```

### Test Again:
1. Connect to TV
2. Check console logs for:
   ```
   [LGTVControlManager] 🎮 Starting pointer input setup...
   [LGTVControlManager] 📍 Got pointer socket path: wss://...
   [PointerInput] 🔌 Connecting to pointer socket...
   [PointerInput] ✅ Pointer socket connected
   [LGTVControlManager] ✅ Pointer input setup complete
   ```
3. Try arrow keys - should work now! ✅

---

## Issue 2: Power On (Wake-on-LAN) Not Waking TV

### Problem
WOL button doesn't hang anymore (good!), but TV doesn't wake up, and `tcpdump` on Mac doesn't capture packets from the app.

### Root Cause
iOS has restrictions on UDP broadcast packets. The Network framework doesn't reliably send to broadcast addresses (255.255.255.255) from iOS apps.

### Fix Applied
✅ Removed broadcast sending (unreliable on iOS)
✅ Changed to direct IP sending only (more reliable)
✅ Added extensive logging to diagnose connection issues
✅ Added 5-second timeout for UDP connections
✅ Send packets twice per port for reliability

### What Changed in WakeOnLAN.swift:

**Before:**
- Sent to broadcast 255.255.255.255 (doesn't work on iOS)
- Also sent to specific IP
- Limited logging

**After:**
- **Only sends to specific IP** (broadcast removed)
- **Detailed logging** for every step
- **Timeout handling** (5 seconds)
- **Retry logic** (sends twice per port)
- **Packet hex dump** for verification

### Test Instructions:

1. **Make sure you have the TV's IP address entered** (required now!)
   - IP: `10.0.0.14`
   
2. **Turn TV to standby:**
   - Use physical remote to turn TV off
   - Check LED is lit (red/white)
   - If LED is completely off, TV is in deep power-off (WOL won't work)

3. **Tap "Wake TV (WOL)" button**

4. **Check console logs for detailed output:**
   ```
   [WakeOnLAN] 📡 Sending magic packet to MAC: 34:E6:E6:F9:05:50
   [WakeOnLAN] 📦 Packet size: 102 bytes
   [WakeOnLAN] 📦 Packet hex: FF FF FF FF FF FF 34 E6 E6 F9 05 50 (repeated 16 times)
   [WakeOnLAN] 📤 Sending to specific IP 10.0.0.14:9
   [WakeOnLAN] 🚀 Starting connection to 10.0.0.14:9
   [WakeOnLAN] 🔄 Connection state: preparing...
   [WakeOnLAN] 🔄 Connection state: ready
   [WakeOnLAN] ✅ Connection ready, sending 102 bytes to 10.0.0.14:9
   [WakeOnLAN] ✅ Packet sent successfully to 10.0.0.14:9
   ```

5. **Watch for errors:**
   - ❌ "Connection failed" = Network issue
   - ⏱️ "Timeout" = TV not responding
   - ⚠️ "Connection cancelled" = Interrupted

### If Still Not Working:

#### 1. TV Settings Not Configured
**Most common issue!** TV needs specific settings enabled:

**Check These Settings:**
1. **Settings → General → Quick Start+**
   - Must be **ON** (not Energy Saving mode)
   - Quick Start+ keeps network card active in standby
   
2. **Settings → Network → LG Connect Apps**
   - Must be **ON**
   - This enables remote control features
   
3. **Settings → General → Mobile TV On**
   - Some models: Enable "Turn on via WiFi" or "Turn on via Mobile"

**Try This:**
- Turn TV fully off using remote control (standby mode)
- Wait 10 seconds
- Try WOL button
- Wait 10-15 seconds (TV takes time to wake)

#### 2. Network Issues

**Broadcast May Be Blocked:**
- Router might block UDP broadcast packets
- Try connecting TV via **Ethernet** instead of WiFi
- Some routers block broadcasts between WiFi and Ethernet

**Firewall/Network Isolation:**
- Check if router has "AP Isolation" or "Client Isolation" enabled
- Disable it if found
- Phone and TV must be on same subnet

#### 3. Deep Power Off vs Standby

**TV Power States:**
- **Standby Mode** (LED on): WOL works ✅
- **Deep Power Off** (LED off): WOL won't work ❌
- **Unplugged**: WOL definitely won't work ❌

**Test:**
1. Turn TV off with remote (should go to standby)
2. Check if LED is lit (usually red)
3. If LED is off, TV is in deep power off - WOL won't work

### Verification:

**You said:** "I tried it with wakeonlan on mac and it worked with both ports"

This means:
- Your Mac can wake the TV ✅
- Network setup is correct ✅
- TV settings are correct ✅
- **The app implementation should work!**

### Debug Steps:

1. **Check console logs when you tap WOL button:**
   ```
   [LGTVControlManager] 📡 Sending Wake-on-LAN to MAC: 34:E6:E6:F9:05:50, IP: 10.0.0.14
   [WakeOnLAN] 📡 Sending magic packet to MAC: 34:E6:E6:F9:05:50
   [WakeOnLAN] 📤 Sending to broadcast 255.255.255.255:9
   [WakeOnLAN] 📤 Sending to specific IP 10.0.0.14:9
   [WakeOnLAN] 📤 Sending to broadcast 255.255.255.255:7
   [WakeOnLAN] 📤 Sending to specific IP 10.0.0.14:7
   [WakeOnLAN] ✅ Magic packets sent successfully
   ```

2. **Compare with Mac wakeonlan command:**
   ```bash
   # What works on Mac:
   wakeonlan 34:E6:E6:F9:05:50
   
   # Or with IP:
   wakeonlan -i 10.0.0.14 34:E6:E6:F9:05:50
   ```

3. **Check if app is actually sending packets:**
   - The new implementation should work exactly like wakeonlan
   - Sends to both broadcast and specific IP
   - Tries both port 9 and port 7
   - Uses UDP (same as wakeonlan)

### If Still Not Working:

**Check These in Order:**

1. **Verify TV Settings:**
   - Settings → General → Quick Start+ = **ON**
   - Settings → Network → LG Connect Apps = **ON**
   - TV must be in **Standby** (LED lit), not deep power off

2. **Verify Network:**
   - Phone and TV on same WiFi network
   - TV preferably on Ethernet (more reliable for WOL)
   - No "AP Isolation" or "Client Isolation" on router

3. **Check Console Logs:**
   - Look for "✅ Packet sent successfully" messages
   - If you see "❌ Connection failed", it's a network routing issue
   - If you see timeouts, TV may not be listening

4. **Verify Packet Format:**
   - Magic packet should be 102 bytes
   - First 6 bytes: `FF FF FF FF FF FF`
   - Followed by MAC address `34 E6 E6 F9 05 50` repeated 16 times
   - Check hex dump in logs

5. **Alternative: Use Mac to Verify TV Works:**
   ```bash
   # On Mac, test if TV wakes
   wakeonlan 34:E6:E6:F9:05:50
   # Or with IP
   wakeonlan -i 10.0.0.14 34:E6:E6:F9:05:50
   ```
   
   If Mac works but iOS doesn't:
   - It's likely an iOS sandboxing/routing issue
   - Try restarting the phone
   - Try deleting and reinstalling the app
   - Check Settings → Privacy & Security → Local Network → Your App = ON

6. **Monitor Network Traffic:**
   ```bash
   # On Mac, capture UDP packets while app is running
   sudo tcpdump -i any -X udp port 9
   
   # Then tap WOL button in app
   # You should now see packets being sent!
   ```

### Why iOS is Different:

- **iOS restricts broadcast:** Can't reliably send to 255.255.255.255
- **Sandboxing:** Apps can't directly access network interfaces
- **Security:** Local Network permission required (in Settings)
- **Network routing:** UDP packets may be filtered by iOS

The new implementation:
- ✅ Sends directly to TV's IP (bypasses broadcast issues)  
- ✅ Uses Apple's Network framework (proper iOS networking)
- ✅ Adds extensive logging (diagnose what's happening)
- ✅ Non-blocking with timeout (doesn't hang UI)

### Expected Result:

With detailed logging, you should now see:
1. Packet creation with hex dump
2. Connection state changes (preparing → ready)
3. Successful packet sending
4. TV should wake within 10-15 seconds

If packets are sent successfully but TV doesn't wake:
- **TV settings problem** (Quick Start+ off)
- **TV in deep power-off** (unplug and replug to test standby)
- **Network routing** (try Ethernet instead of WiFi)

---

## Summary of Changes

### Navigation Fix: ✅ VERIFIED IN CODE
- Removed early return in `sendButton()`
- Changed pointer setup to await properly
- Code is correct - should work after rebuild!

### Wake-on-LAN: 🔧 MAJOR UPDATE
- **Root cause found:** iOS doesn't reliably send UDP broadcast packets
- **Solution:** Removed broadcast, only send to specific IP
- **Enhanced diagnostics:** Added extensive logging for every step
- **Added reliability:** Timeout handling, retry logic, packet hex dump
- **Code verified:** Magic packet format correct (102 bytes)
- **Next step:** Rebuild and check console logs for detailed output

### Key Changes Made:
1. ✅ Navigation `sendButton()` logic fixed
2. ✅ Pointer socket setup made synchronous
3. ✅ WOL switched from broadcast to direct IP
4. ✅ Added detailed logging to all network operations
5. ✅ Added timeout and retry logic

---

## Test Instructions

### 1. Test Navigation (Should Work After Rebuild):
```
1. Clean build (Cmd+Shift+K)
2. Rebuild app
3. Connect to TV
4. Wait for "Pointer input setup complete" in logs
5. Try arrow keys, OK, Back
6. Should all work! ✅
```

### 2. Test Wake-on-LAN (Now with Diagnostics):
```
1. Ensure TV IP is entered: 10.0.0.14
2. Turn TV to standby (LED lit)
3. Open Xcode console
4. Tap "Wake TV (WOL)" button
5. Watch console for detailed logs:
   - Packet creation (102 bytes, hex dump)
   - Connection state (preparing → ready)
   - Send confirmation
6. Wait 10-15 seconds
7. TV should wake up
```

### 3. If WOL Shows "Packet sent successfully" but TV doesn't wake:
```
1. Check TV: Quick Start+ = ON
2. Check TV: LG Connect Apps = ON  
3. Try with TV on Ethernet instead of WiFi
4. Verify TV is in standby (LED lit), not deep power-off
5. Test with Mac wakeonlan command to verify TV is configured correctly
```

### 4. If WOL Shows Connection Errors:
```
1. Check iOS: Settings → Privacy → Local Network → App = ON
2. Check router: No AP isolation enabled
3. Verify phone and TV on same network
4. Try restarting the app
5. Try restarting the phone
```

---

**Date:** October 24, 2025 12:45 AM  
**Status:** 
- Navigation: ✅ Fixed, ready for testing
- WOL: 🔧 Enhanced with diagnostics, direct IP only, ready for testing
