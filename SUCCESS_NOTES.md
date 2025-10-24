# LG webOS 23 Connection - SUCCESS SUMMARY

## 🎉 Achievement
Successfully connected iOS app to LG webOS 23 TV (model 65UT7000, version 23.23.30) using secure WebSocket protocol.

## Key Requirements for webOS 23

### 1. Connection Details
- **URL:** `wss://TV_IP:3001/` (secure WebSocket)
- **NOT:** `ws://TV_IP:3000/` (disabled on webOS 23)
- **Certificate:** Self-signed, must be accepted programmatically
- **Timeout:** Allow 2-3 seconds before sending registration

### 2. Implementation Highlights

#### URLSession Configuration
```swift
// Accept self-signed certificates
func urlSession(_ session: URLSession, 
                didReceive challenge: URLAuthenticationChallenge, 
                completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
    if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
       let serverTrust = challenge.protectionSpace.serverTrust {
        let credential = URLCredential(trust: serverTrust)
        completionHandler(.useCredential, credential)
    }
}
```

#### WebSocket Connection
```swift
let url = URL(string: "wss://\(ipAddress):3001/")!
var request = URLRequest(url: url)
request.timeoutInterval = 30
let task = session.webSocketTask(with: request)
task.resume()
```

#### Protocol Differences

| Aspect | webOS ≤21 | webOS 22/23 |
|--------|-----------|-------------|
| Protocol | `ws://` | `wss://` |
| Port | 3000 | 3001 |
| Certificate | None | Self-signed (accept) |
| Hello Message | Yes, sent first | No, not sent |
| Pairing Mode | PIN or PROMPT | PROMPT (most common) |
| Messages | 1 response | 2 responses (initial + registered) |

### 3. Pairing Flow (webOS 23)

1. **Open Connection**
   - Connect to `wss://TV_IP:3001/`
   - Accept authentication challenge
   - Connection confirmed via delegate

2. **Send Registration** (after 2-second delay)
   ```json
   {
     "type": "register",
     "id": "UUID",
     "payload": {
       "pairingType": "PROMPT",
       "forcePairing": false,
       "manifest": { ... }
     }
   }
   ```

3. **TV First Response** (PROMPT mode)
   ```json
   {
     "type": "response",
     "id": "UUID",
     "payload": {
       "pairingType": "PROMPT",
       "returnValue": true
     }
   }
   ```
   - TV shows: "Allow this device to control TV?"
   - **Don't close connection** - wait for user action

4. **TV Second Response** (after user clicks Allow)
   ```json
   {
     "type": "registered",
     "id": "UUID",
     "payload": {
       "client-key": "9ba71d29c353cf0bdcc00c4b0a8cc189"
     }
   }
   ```
   - Store this `client-key` in Keychain
   - Use for future connections

### 4. Info.plist Requirements

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
    <key>NSAllowsLocalNetworking</key>
    <true/>
</dict>
<key>NSLocalNetworkUsageDescription</key>
<string>This app connects to your LG TV on the local network</string>
<key>NSBonjourServices</key>
<array>
    <string>_lge-remote._tcp</string>
</array>
```

### 5. Common Issues & Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| Connection reset on port 3000 | Port disabled on webOS 23 | Use port 3001 with wss:// |
| Certificate error | Self-signed cert rejected | Implement auth challenge handler |
| No response after connection | Waiting for "hello" | Send registration after 2-second delay |
| Timeout after first response | Closed connection too early | Wait for "registered" message in PROMPT mode |
| Connection works once then fails | Client key not stored | Save client-key to Keychain |

### 6. Verified Working Configuration

**Test Date:** October 23, 2025  
**TV Model:** LG 65UT7000  
**webOS Version:** 23.23.30  
**iOS Version:** 17.0+  
**Connection:** ✅ Success  
**Pairing:** ✅ Success  
**Client Key:** ✅ Received and stored  

**Logs Confirmed:**
- Secure WebSocket connection established
- Self-signed certificate accepted
- Registration sent successfully
- PROMPT pairing completed
- Client key received: `9ba71d29c353cf0bdcc00c4b0a8cc189`

### 7. Next Steps

Now that pairing is working, the next phase is:
1. ✅ Connection & Pairing - **COMPLETE**
2. 🔄 Send commands (volume, power, input)
3. 🔄 Widget implementation with App Intents
4. 🔄 Command testing and reliability
5. 🔄 UI polish and error handling
6. 🔄 App Store preparation

---

## Resources

- **Community Reports:** Port 3001 requirement confirmed by Home Assistant, Hubitat, and OpenHAB communities
- **Certificate:** LG uses self-signed cert chain: `LGE TV SSG → LGE SSG Intermediate CA → LG webOS TV Root CA`
- **Protocol:** SSAP (Simple Service Access Protocol) over WebSocket
- **Documentation:** Limited official docs; community-driven implementation

## Credits

Implementation based on community research and testing:
- Home Assistant LGWebOS integration
- lgtv2 Node.js library
- Connect SDK documentation
- Community forum troubleshooting threads

---

**Status:** ✅ Core functionality proven working on webOS 23  
**Updated:** October 23, 2025 11:00 PM
