# CosmoKitTestApp

The target app for every CosmoKit tool: deep links, push notifications,
location simulation, permissions, Face ID, User Defaults, app data, log
stream, and a network card. Bundle id `apps.mjkweber.CosmoKitTestApp`, URL
scheme `cosmokittestapp`.

## Receipts (E2E-03a)

The app records what it receives to `UserDefaults.standard` under one
prefix. Each key holds a JSON string `{"ts": "<ISO8601>", "payload": …}`:

| key | written when | payload |
|---|---|---|
| `receipt.deepLink` | `.onOpenURL` | the full URL string |
| `receipt.push` | `willPresent`, the tap response, and `didReceiveRemoteNotification` (the last one fires for `content-available: 1` without user-notification permission — the only path a macOS test can rely on) | the `aps` dictionary |
| `receipt.location` | a `CLLocationManager` fix (the location card already asks) | `{"lat": …, "lon": …}` |
| `receipt.permission.<service>` | authorization status changes (camera, microphone, photos, contacts, notifications) | the status name |
| `receipt.launch` | app becomes active | `{"count": <n>}` incremented |

Every receipt is also logged through `Logger(subsystem: <bundle id>,
category: "receipts")`, so `log show` sees the same lines.

### Reading receipts from outside

```
xcrun simctl get_app_container <udid> apps.mjkweber.CosmoKitTestApp data
xcrun simctl spawn <udid> defaults read <container>/Library/Preferences/apps.mjkweber.CosmoKitTestApp
```

The CosmoKit CLI's `defaults` command reads the same path.

### Resetting between scenarios

Launch with `--reset-receipts` to clear every `receipt.*` key before the UI
appears:

```
xcrun simctl launch <udid> apps.mjkweber.CosmoKitTestApp --reset-receipts
```

## Project generation

The Xcode project is generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```
xcodegen generate
```

## Diagnostics playground (TA-01)

A dedicated card demonstrating each of CosmoKit's 11 diagnostic switches. Buttons commit the specific violation caught or configured by that switch.

| Diagnostic Switch | Button Accessibility ID | Action / Expected Signal |
|---|---|---|
| `zombies` | `diag.zombies` | Sends a message to a deallocated instance. Aborts with `message sent to deallocated instance`. |
| `mallocStackLogging` | `diag.mallocStackLogging` | Allocates 256KB block with tagged byte signature. Visible in malloc stack logs / CosmoKit log stream. |
| `mallocScribble` | `diag.mallocScribble` | Inspects freed memory. Displays `0x55555555` pattern in UI when scribble is enabled, or writes past buffer to trigger guard page abort. |
| `mainThreadChecker` | `diag.mainThreadChecker` | Calls UIKit `text` setter from a background thread. Triggers Main Thread Checker violation in logs. |
| `coreDataSQL` | `diag.coreDataSQL` | Inserts and fetches records via Core Data. Emits verbose `CoreData: sql` statements to log stream. |
| `coreDataConcurrency` | `diag.coreDataConcurrency` | Mutates a NSManagedObjectContext from the wrong background thread. Aborts with `Multithreading_Violation`. |
| `layoutFeedback` | `diag.layoutFeedback` | Toggles subview layout inside `layoutSubviews()`. Aborts with `LayoutFeedbackLoop` exception. |
| `nonLocalizedStrings` | `diag.nonLocalizedStrings` | Renders unlocalized string. Rendered in UPPERCASE in UI when switch is enabled. |
| `doubleLocalizedStrings` | `diag.doubleLocalizedStrings` | Renders localized string. Rendered doubled (e.g. `[Sample text Sample text]`) when switch is enabled. |
| `quietLog` | `diag.quietLog` | Emits info/debug os_log messages. Suppressed or redirected when quiet logging is active. |
| `cfNetwork` | `diag.cfNetwork` | Issues an HTTP GET request to `httpbin.org/get`. Emits verbose CFNetwork diagnostic logging. |

### Confirmation for Crashing Switches

Buttons that cause purposeful application crashes (`zombies`, `mallocScribble`, `coreDataConcurrency`, and `layoutFeedback`) require a double-tap confirmation within 2 seconds. The first tap prompts "Tap again to crash", and a second tap within 2 seconds executes the crashing code.

### Launch Arguments

- `--hide-diagnostics-playground`: Completely hides the Diagnostics playground card from the view hierarchy.
- `--reset-receipts`: Clears all `receipt.*` keys from User Defaults before the UI initializes.

