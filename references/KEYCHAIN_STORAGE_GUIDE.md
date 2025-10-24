# Keychain Storage - Implementation Guide

## Overview

The LG TV Remote Widget app uses iOS Keychain to securely store TV credentials (IP address, MAC address, and client-key) that are shared between the main app and the widget extension.

## Architecture

### KeychainManager Class

Located in: `LGTVControl/Storage/KeychainManager.swift`

The `KeychainManager` provides a type-safe wrapper around iOS Keychain Services API with support for `Codable` objects.

#### Public API

```swift
public final class KeychainManager {
    public init()
    
    // Save a Codable object to the keychain
    public func save<T: Codable>(_ object: T, service: String, account: String) throws
    
    // Load a Codable object from the keychain
    public func load<T: Codable>(_ type: T.Type, service: String, account: String) throws -> T?
    
    // Delete an item from the keychain
    public func delete(service: String, account: String) throws
}
```

#### Error Handling

```swift
public enum KeychainError: Error, LocalizedError {
    case unexpectedStatus(OSStatus)  // Keychain operation failed
    case encodingFailed               // JSON encoding/decoding failed
}
```

## Data Storage

### TVCredentials Model

```swift
public struct TVCredentials: Codable {
    public var ipAddress: String
    public var macAddress: String
    public var clientKey: String?
    
    // clientKey is optional - set after successful TV pairing
}
```

### Storage Constants

Defined in `LGTVControlManager.Constants`:

```swift
public static let keychainService = "com.DaraConsultingInc.LGTVRemoteWidget.credentials"
public static let keychainAccount = "default"
```

## Keychain Access Group Configuration

### Purpose

The keychain access group allows the main app and widget extension to share the same keychain items. Without this, the widget would not be able to access credentials stored by the main app.

### Entitlements Configuration

**File**: `LG TV Remote Widget.entitlements`

```xml
<key>keychain-access-groups</key>
<array>
    <string>$(AppIdentifierPrefix)com.DaraConsultingInc.LGTVRemoteWidget</string>
</array>
```

**Important Details:**

- `$(AppIdentifierPrefix)` is automatically replaced by Xcode with your Team ID
- The group identifier must match the app's bundle identifier
- The same entitlements file should be used for both main app and widget extension

### App Groups for Additional Sharing

**File**: `LG TV Remote Widget.entitlements`

```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.DaraConsultingInc.LGTVRemoteWidget</string>
</array>
```

This allows sharing UserDefaults data between app and widget (used for connection status).

## Usage Examples

### In Main App - Save Credentials After Pairing

```swift
let manager = LGTVControlManager.shared

// After successful pairing
let credentials = TVCredentials(
    ipAddress: "10.0.0.14",
    macAddress: "34:E6:E6:F9:05:50",
    clientKey: "9ba71d29c353cf0bdcc00c4b0a8cc189"
)

manager.saveCredentials(credentials)
```

### In Widget Extension - Load Credentials

```swift
let manager = LGTVControlManager.shared

if let credentials = manager.loadCredentials() {
    // Use credentials to connect to TV
    try await manager.connect(
        ip: credentials.ipAddress,
        mac: credentials.macAddress
    )
} else {
    // No credentials - show "Setup Required" message
}
```

### Clear Credentials (Re-pairing)

```swift
manager.clearCredentials()
```

## Internal Implementation Details

### How Save Works

1. Encode the object to JSON using `JSONEncoder`
2. Delete any existing item with same service/account (to replace)
3. Create keychain query with:
   - `kSecClass`: `kSecClassGenericPassword`
   - `kSecAttrService`: Service identifier
   - `kSecAttrAccount`: Account identifier
   - `kSecValueData`: JSON data
4. Call `SecItemAdd` to store
5. Throw error if status != `errSecSuccess`

### How Load Works

1. Create keychain query with:
   - `kSecClass`: `kSecClassGenericPassword`
   - `kSecAttrService`: Service identifier
   - `kSecAttrAccount`: Account identifier
   - `kSecReturnData`: `true` (return the data)
   - `kSecMatchLimit`: `kSecMatchLimitOne` (only one result)
2. Call `SecItemCopyMatching` to retrieve
3. Return `nil` if status == `errSecItemNotFound`
4. Decode JSON data using `JSONDecoder`
5. Return decoded object or throw error

### How Delete Works

1. Create keychain query with service/account
2. Call `SecItemDelete`
3. Treat both `errSecSuccess` and `errSecItemNotFound` as success
   (deleting a non-existent item is not an error)

## Security Considerations

### Why Keychain vs UserDefaults?

| Aspect | Keychain | UserDefaults |
|--------|----------|--------------|
| Encryption | ✅ Always encrypted | ❌ Plain text |
| Protection | ✅ Protected by device passcode | ❌ No protection |
| iCloud Sync | ⚠️ Optional (not enabled here) | ❌ Not secure for secrets |
| Widget Access | ✅ With access group | ✅ With app group |

**Decision**: Use Keychain for client-key (sensitive credential that grants TV control)

### Best Practices Implemented

1. ✅ **No Hardcoded Credentials**: All credentials stored securely in Keychain
2. ✅ **Type Safety**: Generic `Codable` support prevents type errors
3. ✅ **Error Handling**: All operations throw detailed errors
4. ✅ **Cleanup**: Delete before save to prevent duplicates
5. ✅ **Optional clientKey**: Supports unpaired state (no key yet)

## Testing

### Unit Tests

Located in: `LGTVControlTests/KeychainManagerTests.swift`

**Test Coverage:**
- ✅ Save credentials
- ✅ Load credentials
- ✅ Delete credentials
- ✅ Overwrite existing data
- ✅ Load non-existent returns nil
- ✅ Multiple accounts (independent)
- ✅ Empty strings handling
- ✅ Very long data (10,000 char client key)
- ✅ Error handling (invalid type decoding)
- ✅ Performance benchmarks

### Running Tests

1. Open Xcode
2. Select `LGTVControlTests` scheme
3. Press `Cmd+U` to run all tests
4. Or right-click `KeychainManagerTests.swift` → Run Tests

### Test Keychain Service

Tests use a separate service identifier to avoid interfering with real data:

```swift
let testService = "com.DaraConsultingInc.LGTVRemoteWidget.test"
```

All test data is cleaned up in `tearDown()`.

## Migration & Troubleshooting

### Migrating from UserDefaults

If you previously stored credentials in UserDefaults:

```swift
// OLD (insecure)
UserDefaults.standard.set(clientKey, forKey: "clientKey")

// NEW (secure)
let credentials = TVCredentials(
    ipAddress: ip,
    macAddress: mac,
    clientKey: clientKey
)
manager.saveCredentials(credentials)

// Delete old insecure data
UserDefaults.standard.removeObject(forKey: "clientKey")
```

### Common Issues

#### Widget Cannot Access Credentials

**Symptom**: Main app saves credentials, but widget returns nil when loading

**Solutions**:
1. Verify entitlements file is the same for both targets
2. Check keychain-access-groups array contains correct group
3. Ensure widget target has the entitlements file linked in Build Settings
4. Clean build folder (Cmd+Shift+K) and rebuild

#### "Keychain Error: -34018"

**Symptom**: `errSecMissingEntitlement` error

**Solution**: Add keychain-access-groups to entitlements file

#### "Keychain Error: -25300"

**Symptom**: `errSecItemNotFound` when loading

**Solution**: This is normal - item doesn't exist (not yet paired). Handle nil return value.

### Re-pairing a TV

If client-key becomes invalid (user unpaired from TV settings):

1. Call `manager.clearCredentials()` to delete keychain data
2. Call `manager.connect(ip: ip, mac: mac)` to re-pair
3. User will see pairing prompt on TV again
4. New client-key will be stored

## Implementation Checklist

- [x] KeychainManager class implemented
- [x] Save/Load/Delete methods with error handling
- [x] TVCredentials model (Codable)
- [x] Keychain access group in entitlements
- [x] App Group in entitlements (for UserDefaults sharing)
- [x] Integration with LGTVControlManager
- [x] Unit tests with >80% coverage
- [x] Documentation

## References

- Apple Documentation: [Keychain Services](https://developer.apple.com/documentation/security/keychain_services)
- Apple Sample Code: [GenericKeychain](https://developer.apple.com/library/archive/samplecode/GenericKeychain/)
- WWDC: [What's New in App Privacy](https://developer.apple.com/videos/play/wwdc2021/10085/)

---

**Last Updated**: October 24, 2025  
**Status**: ✅ Complete - Step 6 (Keychain Storage) Fully Implemented
