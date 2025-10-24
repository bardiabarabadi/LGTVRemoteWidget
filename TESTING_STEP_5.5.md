# Step 5.5 - Command Testing Guide

## What Was Implemented

### 1. Command Sending Infrastructure ✅
- `LGTVControlManager.sendCommand()` - Already existed and works perfectly!
- Takes URI and optional parameters
- Returns responses and handles errors
- Uses stored client-key automatically

### 2. Test UI in ContentView ✅
Added a new "Test Commands" section that appears when connected:

**Volume Controls:**
- Volume Up (speaker.wave.3 icon)
- Volume Down (speaker.wave.1 icon)
- Mute (speaker.slash icon)

**HDMI Inputs:**
- HDMI 1 button
- HDMI 2 button
- HDMI 3 button

**App Launchers:**
- Netflix (red, TV icon)
- YouTube (red, play.rectangle icon)

**Power:**
- Power Off (destructive red button)

**Feedback:**
- Success: "✅ Command sent: [command]" in green
- Error: "❌ Error: [message]" in red
- Auto-clears after 3 seconds

## Testing Instructions

### Step 1: Build and Deploy
```bash
# Make sure you're signed in to Xcode
# Select your physical device
# Build and run (Cmd+R)
```

### Step 2: Connect to TV
1. App should show IP: 10.0.0.14 and MAC: 34:E6:E6:F9:05:50 (stored)
2. Tap "Connect"
3. Should connect immediately with stored client-key
4. Status should show "Connected" with green indicator

### Step 3: Test Each Command

#### Volume Controls
- [ ] Tap "Vol +" → TV volume should increase
- [ ] Tap "Vol −" → TV volume should decrease
- [ ] Tap "Mute" → TV should mute

#### HDMI Inputs
- [ ] Tap "HDMI 1" → TV should switch to HDMI 1
- [ ] Tap "HDMI 2" → TV should switch to HDMI 2
- [ ] Tap "HDMI 3" → TV should switch to HDMI 3

#### App Launching
- [ ] Tap "Netflix" → Netflix app should launch
- [ ] Tap "YouTube" → YouTube app should launch

#### Power
- [ ] Tap "Power Off" → TV should turn off

### Step 4: Document Results
For each command, note:
- ✅ Works perfectly
- ⚠️ Works but with issues (describe)
- ❌ Doesn't work (error message)

## Expected Behavior

### Success Case
1. Tap button
2. Brief pause (network request)
3. Green message: "✅ Command sent: volumeUp"
4. TV performs action
5. Message clears after 3 seconds

### Error Case
1. Tap button
2. Red message: "❌ Error: Not connected"
3. Message stays visible

## Common Issues

### "Not connected"
- Reconnect using Connect button
- Check TV is on and on network

### "Command rejected"
- Command URI may be wrong
- TV may not support that command

### No response but no error
- Command sent successfully but TV didn't respond
- Could be valid command but TV is busy

## Commands Under Test

| Command | URI | Parameters | Purpose |
|---------|-----|------------|---------|
| Vol + | `ssap://audio/volumeUp` | None | Increase volume by 1 |
| Vol − | `ssap://audio/volumeDown` | None | Decrease volume by 1 |
| Mute | `ssap://audio/setMute` | `{"mute": true}` | Toggle mute on |
| HDMI 1 | `ssap://tv/switchInput` | `{"inputId": "HDMI_1"}` | Switch to HDMI 1 |
| HDMI 2 | `ssap://tv/switchInput` | `{"inputId": "HDMI_2"}` | Switch to HDMI 2 |
| HDMI 3 | `ssap://tv/switchInput` | `{"inputId": "HDMI_3"}` | Switch to HDMI 3 |
| Netflix | `ssap://system.launcher/launch` | `{"id": "netflix"}` | Launch Netflix app |
| YouTube | `ssap://system.launcher/launch` | `{"id": "youtube.leanback.v4"}` | Launch YouTube app |
| Power Off | `ssap://system/turnOff` | None | Turn TV off |

## Next Steps After Testing

Once commands are verified working:
1. Document which commands work in progress.md
2. Mark Step 5.5 as complete
3. Move on to Step 6: Widget Extension
4. Use these working commands in widget buttons

---

**Status:** Ready for on-device testing  
**Date:** October 23, 2025  
**TV:** LG 65UT7000 @ 10.0.0.14
