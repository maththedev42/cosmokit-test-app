//
//  Receipts.swift
//  CosmoKitTestApp
//
//  E2E-03a: a tiny receipt store a macOS UI test can read from outside.
//  Every kind the app receives (deep link, push, location, permission
//  change, activation) is written to UserDefaults.standard under a single
//  `receipt.` prefix — one JSON string per key, {ts, payload} — and logged
//  through the unified logger under category "receipts", so both
//  `simctl spawn defaults read` (via the data container) and
//  `log show --predicate 'subsystem == <bundle>'` show what arrived.
//
//  `--reset-receipts` as a launch argument clears every receipt key before
//  the UI appears, so `simctl launch <udid> <bundle> --reset-receipts`
//  starts a scenario clean.
//

import Foundation
import OSLog

enum Receipts {
    static let prefix = "receipt."

    static let log = Logger(subsystem: TestLog.subsystem, category: "receipts")

    /// Clear every `receipt.*` key. Called at launch when the
    /// `--reset-receipts` argument is present.
    static func resetIfNeeded() {
        guard ProcessInfo.processInfo.arguments.contains("--reset-receipts") else { return }
        reset()
    }

    static func reset() {
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
            defaults.removeObject(forKey: key)
        }
        log.notice("receipts reset")
    }

    /// Record one receipt: `receipt.<kind>` = {"ts": ISO8601, "payload": …}.
    /// The payload is anything JSON-serializable (string, number,
    /// dictionary).
    static func record(kind: String, payload: Any) {
        let entry: [String: Any] = [
            "ts": ISO8601DateFormatter().string(from: Date()),
            "payload": payload,
        ]
        guard JSONSerialization.isValidJSONObject(entry),
              let data = try? JSONSerialization.data(withJSONObject: entry),
              let json = String(data: data, encoding: .utf8) else {
            log.error("receipt \(kind, privacy: .public): payload not JSON-serializable")
            return
        }
        UserDefaults.standard.set(json, forKey: prefix + kind)
        log.notice("receipt \(kind, privacy: .public): \(json, privacy: .public)")
    }

    // MARK: - Kinds

    static func deepLink(_ url: String) {
        record(kind: "deepLink", payload: url)
    }

    static func push(aps: [String: Any]) {
        record(kind: "push", payload: aps)
    }

    static func location(latitude: Double, longitude: Double) {
        record(kind: "location", payload: ["lat": latitude, "lon": longitude])
    }

    static func permission(service: String, status: String) {
        record(kind: "permission.\(service)", payload: status)
    }

    /// Incremented on every activation; the count lets a test tell a first
    /// launch from a relaunch.
    static func activation() {
        let defaults = UserDefaults.standard
        let count = defaults.integer(forKey: prefix + "launch") + 1
        record(kind: "launch", payload: ["count": count])
    }
}
