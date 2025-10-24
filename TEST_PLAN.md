# Test Plan - Multiple Approaches

## What I Just Added:

### 1. ✅ Many More Permissions
Added every permission I could think of, including:
- `CONTROL_MOUSE_AND_KEYBOARD`
- `CONTROL_INPUT_POINTER`
- `CONTROL_TV_SCREEN`
- `CONTROL_TV_STANBY`
- And 10+ others

### 2. ✅ Fallback Alternative API
If pointer socket fails with "401 insufficient permissions", the app will automatically try alternative APIs:
- `ssap://com.webos.service.tv.keymanager/processKeyInput`
- `ssap://com.webos.service.networkinput/sendKeyEvent`

### 3. ✅ Better Error Handling
Now gracefully falls back instead of just failing.

---

## Test These In Order:

### Test 1: Try With All Permissions (Build & Re-Pair)

1. **Clean build:**
   ```
   Cmd + Shift + K
   Cmd + B
   Cmd + R
   ```

2. **Clear credentials and re-pair:**
   - Tap "Clear Credentials (Force Re-Pair)"
   - Tap "Connect"
   - Accept on TV
   - Enter code

3. **Check logs:**
   - Look for: "Got pointer socket path" ✅
   - OR: "Trying alternative button API" 🔄

4. **Test arrow keys:**
   - Press UP arrow
   - Check if it works!

**If this works:** Problem solved! One of the new permissions was needed.

**If still 401:** Move to Test 2.

---

### Test 2: Alternative API Fallback

If you still see "401 insufficient permissions", the app will now automatically try the alternative APIs.

**Watch console for:**
```
[LGTVControlManager] ⚠️ Pointer socket setup failed, trying alternative API...
[LGTVControlManager] 🔄 Trying alternative button API...
[LGTVControlManager] ❌ Alternative URI failed: ssap://com.webos.service.tv.keymanager/processKeyInput - <error>
[LGTVControlManager] ❌ Alternative URI failed: ssap://com.webos.service.networkinput/sendKeyEvent - <error>
```

**Share these error messages** - they'll tell us what's available!

---

### Test 3: Questions for AI Chatbot

Ask the AI these specific questions:

#### Question 1: Permissions
```
For LG webOS TV (specifically webOS 23.23.30 on LG 65UT7000), what exact permissions are required in the SSAP manifest to use the "ssap://com.webos.service.networkinput/getPointerInputSocket" API?

I'm getting "401 insufficient permissions" even with these permissions:
LAUNCH, LAUNCH_WEBAPP, APP_TO_APP, CONTROL_AUDIO, CONTROL_DISPLAY, 
CONTROL_INPUT_MEDIA_PLAYER, CONTROL_POWER, READ_INSTALLED_APPS, 
CONTROL_INPUT_JOYSTICK, CONTROL_INPUT_TEXT, CONTROL_INPUT_MEDIA_RECORDING, 
CONTROL_INPUT_MEDIA_PLAYBACK, CONTROL_MOUSE_AND_KEYBOARD, READ_CURRENT_CHANNEL, 
READ_RUNNING_APPS, READ_TV_CURRENT_TIME, CONTROL_TV_SCREEN, CONTROL_TV_STANBY, 
READ_LGE_SDX, READ_LGE_TV_INPUT_EVENTS, READ_TV_CHANNEL_LIST, WRITE_SETTINGS, 
WRITE_NOTIFICATION_TOAST, CONTROL_INPUT_POINTER

What permission am I missing?
```

#### Question 2: Alternative APIs
```
For LG webOS TV remote control, if "getPointerInputSocket" returns 401 insufficient permissions, what alternative SSAP URIs can be used to send navigation button commands (UP, DOWN, LEFT, RIGHT, ENTER, BACK, HOME)?

Specifically:
- Does "ssap://com.webos.service.tv.keymanager/processKeyInput" work?
- Does "ssap://com.webos.service.networkinput/sendKeyEvent" work?
- Are there other URIs for sending button presses?
- What parameters do these URIs expect?
```

#### Question 3: Complete Permission List
```
What is the complete list of ALL valid SSAP manifest permissions for LG webOS TV apps? Please list every permission string that exists.
```

#### Question 4: TV Model Compatibility
```
Does the LG 65UT7000 TV (webOS 23.23.30) support the pointer input socket API "getPointerInputSocket"? Are there any model-specific or firmware-specific restrictions?
```

#### Question 5: Workarounds
```
How do third-party remote control apps for LG webOS TV (like LG ThinQ, third-party remotes on iOS) send navigation button commands? Do they use:
1. Pointer input socket?
2. Direct SSAP commands?
3. Some other method?

What's the recommended approach for webOS 22 and later?
```

---

## What To Share With Me:

After running Test 1 & 2, share:

1. **Complete console log** from:
   - Tap "Clear Credentials"
   - Tap "Connect"
   - Accept pairing
   - Press an arrow key

2. **AI Chatbot responses** to all 5 questions

3. **Error messages** from alternative API attempts

---

## Possible Outcomes:

### Outcome A: New Permissions Work ✅
One of the 20+ permissions I added was the missing one. Navigation works!

### Outcome B: Alternative API Works ✅
Console shows: "✅ Alternative API worked with URI: ..."
We use that method instead of pointer socket.

### Outcome C: Neither Works ❌
We need AI response to know:
- What's the correct permission?
- OR what's the correct alternative API?
- OR is this TV/firmware not compatible?

### Outcome D: API Doesn't Exist ❓
Pointer input socket might not be available on this TV model/firmware.
We need to find the correct approach for webOS 23.23.30.

---

## Current Code Status:

✅ Added 20+ permissions (every one I could find)
✅ Added automatic fallback to alternative APIs
✅ Better error logging
✅ Graceful degradation

**Ready to test!** 🚀

---

**Next Steps:**
1. Build & Run
2. Clear credentials & re-pair
3. Test navigation
4. Share console logs
5. Ask AI the 5 questions
6. We'll solve this! 💪
