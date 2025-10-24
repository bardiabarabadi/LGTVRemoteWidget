# Alternative Navigation Commands to Try

Based on various LG webOS libraries and documentation, here are alternative SSAP URIs to try:

## Option 1: com.webos.service.networkinput
```
ssap://com.webos.service.networkinput/getPointerInputSocket
```

## Option 2: Button Press Commands
```swift
// Try these URIs for navigation:

// Arrow Keys - Method 1
"ssap://com.webos.service.networkinput/sendKeyCommand" with {"key": "UP"}
"ssap://com.webos.service.networkinput/sendKeyCommand" with {"key": "DOWN"}
"ssap://com.webos.service.networkinput/sendKeyCommand" with {"key": "LEFT"}
"ssap://com.webos.service.networkinput/sendKeyCommand" with {"key": "RIGHT"}

// Arrow Keys - Method 2 (different key names)
"ssap://com.webos.service.networkinput/sendKeyCommand" with {"key": "ARROW_UP"}
"ssap://com.webos.service.networkinput/sendKeyCommand" with {"key": "ARROW_DOWN"}
"ssap://com.webos.service.networkinput/sendKeyCommand" with {"key": "ARROW_LEFT"}
"ssap://com.webos.service.networkinput/sendKeyCommand" with {"key": "ARROW_RIGHT"}

// OK/Enter - Various attempts
"ssap://com.webos.service.networkinput/sendKeyCommand" with {"key": "ENTER"}
"ssap://com.webos.service.networkinput/sendKeyCommand" with {"key": "OK"}
"ssap://com.webos.service.networkinput/sendKeyCommand" with {"key": "SELECT"}

// Back button
"ssap://com.webos.service.networkinput/sendKeyCommand" with {"key": "BACK"}
"ssap://com.webos.service.networkinput/sendKeyCommand" with {"key": "EXIT"}

// Home button
"ssap://system.launcher/open" with {"target": "home"}
```

## Option 3: Mouse/Pointer Input
Some libraries use mouse click simulation:
```
ssap://com.webos.service.networkinput/click
```

## Option 4: Direct System Launcher
```
// Home
"ssap://system.launcher/open" with {"target": "home"}

// Close/Back
"ssap://system.launcher/close"
```

## Testing Script for ContentView

Add a test section to try all these:

```swift
Section("Navigation Test") {
    Button("Test Nav Option 1") {
        viewModel.sendCommand("ssap://com.webos.service.networkinput/sendKeyCommand", ["key": "UP"])
    }
    Button("Test Nav Option 2") {
        viewModel.sendCommand("ssap://com.webos.service.networkinput/getPointerInputSocket")
    }
    Button("Test Home") {
        viewModel.sendCommand("ssap://system.launcher/open", ["target": "home"])
    }
    Button("Test Close") {
        viewModel.sendCommand("ssap://system.launcher/close")
    }
}
```

## What to Check in Logs

When you test each command, check for:
1. 404 errors = wrong URI
2. Success but no action = right URI, wrong parameters
3. Works = correct!

Note which ones return what, then we can narrow down the correct approach.
