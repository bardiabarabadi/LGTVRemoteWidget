# LG webOS SSAP Protocol Notes

## ✅ SUCCESS - October 23, 2025

**First successful connection to LG webOS 23 TV achieved!**
- Model: LG 65UT7000
- webOS Version: 23.23.30
- Connection: wss://10.0.0.14:3001/
- Client Key: 9ba71d29c353cf0bdcc00c4b0a8cc189

---

## Critical Discoveries (Oct 23, 2025)

### The Problem
The TV was immediately resetting WebSocket connections on port 3000 with "Connection reset by peer" errors.

### Root Cause - webOS 23 Protocol Changes
**LG changed the connection requirements in webOS 22/23:**

**OLD (webOS ≤21):**
1. Client opens `ws://TV_IP:3000/` (insecure)
2. TV sends "hello" message
3. Client sends registration
4. TV responds with pairing

**NEW (webOS 22/23):**
1. Client opens `wss://TV_IP:3001/` (secure, self-signed cert)
2. **TV does NOT send "hello" message** ⬅️ **Protocol changed!**
3. Client sends registration directly (after 2-second grace period)
4. TV responds with pairing (PROMPT mode: no PIN, just Allow/Deny)
5. User clicks "Allow" on TV
6. TV sends "registered" message with client-key

**Key Changes:**
- ❌ Port 3000 (ws://) is **DISABLED** on webOS 23
- ✅ Port 3001 (wss://) is **REQUIRED**
- ❌ "Hello" message **NO LONGER SENT** by TV
- ✅ PROMPT pairing (2 messages: initial response + registered after approval)

## SSAP Protocol Flow

### 1. WebSocket Connection

**CRITICAL: webOS 22/23+ REQUIRES Secure WebSocket!**

```
⚠️ webOS 23 (and 22+): wss://<TV_IP>:3001/ (SECURE - Required!)
   - Uses self-signed certificate (must accept)
   - Port 3000 is DISABLED/BLOCKED on newer firmware
   
❌ OLD (webOS ≤21): ws://<TV_IP>:3000/ (Insecure - Deprecated)
   - No longer works on webOS 22/23
   - TV actively resets connections on port 3000

Required:
- Accept self-signed certificate for wss://
- URLSession authentication challenge handling
```

### 2. TV Hello Message
After connection, TV sends:
```json
{
  "type": "hello",
  "payload": {
    "protocolVersion": 1,
    "deviceType": "tv",
    "deviceOS": "webOS",
    "deviceOSVersion": "6.x.x",
    "deviceUUID": "<uuid>",
    "pairingTypes": ["PROMPT", "PIN"]
  }
}
```

### 3. Client Registration Request
After receiving hello, client sends:
```json
{
  "type": "request",
  "id": "register_0",
  "uri": "ssap://com.webos.service.networkinput/register",
  "payload": {
    "clientKey": "<stored_key_or_null>",
    "manifest": {
      "manifestVersion": "1.0",
      "appVersion": "1.0",
      "signed": true,
      "signatures": [],
      "permissions": []
    },
    "forcePairing": false
  }
}
```

### 4. TV Registration Response
TV responds with either:
- Pairing required (show prompt on TV)
- Success with client key (if previously paired)

## Implementation Changes

### Before (Incorrect)
```swift
connect() -> WebSocket opens
  ↓
register() -> Immediately send registration ❌ TV resets connection
```

### After (Correct)
```swift
connect() -> WebSocket opens
  ↓
receiveLoop() -> Wait for "hello" message
  ↓
handle("hello") -> Process TV info
  ↓
sendRegistration() -> Now send registration ✅ TV accepts
```

## TV Prerequisites

1. **Enable "LG Connect Apps"**
   - Settings → Network → LG Connect Apps → Turn ON
   
2. **Same Network**
   - TV and device must be on same subnet
   
3. **Accept Pairing**
   - First connection shows prompt on TV: "Allow device to control TV?"
   - Must accept and store the clientKey for future use

4. **TV Powered On**
   - TV must be on and network-connected (not in deep standby)

## WebOS Version Differences

- **webOS 2-3** (2014-2016): May use legacy UDAP protocol
- **webOS 4+** (2017+): Standard SSAP over WebSocket
- **webOS 6+** (2021+): Current implementation, may support WSS

## Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| Connection immediately resets | Wait for "hello" before sending data |
| "Invalid Origin" error | Set `Origin: http://<TV_IP>` header |
| Registration timeout | Ensure "LG Connect Apps" is enabled on TV |
| Pairing not working | Accept prompt on TV screen, store clientKey |
| Works once then stops | Connection may time out, implement reconnection |

## Resources

- Community libraries: lgtv2 (Node.js), Connect SDK (Android/iOS)
- LG webOS Developer Forum: forum.webostv.developer.lge.com
- OpenHAB LGWebOS Binding documentation

## Notes for Future

- Consider implementing WebSocket ping/pong for keep-alive
- Handle reconnection on connection loss
- Store clientKey securely in Keychain
- Support both ws:// and wss:// for different TV models
- Add proper error handling for different TV firmware versions
