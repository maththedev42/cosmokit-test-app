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
