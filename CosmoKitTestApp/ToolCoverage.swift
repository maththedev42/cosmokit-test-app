//
//  ToolCoverage.swift
//  CosmoKitTestApp
//
//  The panels for the CosmoKit tools the app did not exercise yet: Log Stream,
//  Permissions, User Defaults, App Data and the simulator environment controls.
//  Each one exists so a tool that works visibly changes something here.
//

import Contacts
import LocalAuthentication
import OSLog
import Photos
import SwiftUI
import AVFoundation
import UserNotifications

// MARK: - Logs

/// CosmoKit streams with the predicate
/// `process contains "<bundle id>" OR subsystem contains "<bundle id>"`.
/// A process is named after its executable, not its bundle identifier, so the
/// `process` half never matches this app - the subsystem below is what makes the
/// stream work at all, which is why it is the bundle identifier verbatim.
enum TestLog {
    static let subsystem = Bundle.main.bundleIdentifier ?? "apps.mjkweber.CosmoKitTestApp"

    static let general = Logger(subsystem: subsystem, category: "general")
    static let network = Logger(subsystem: subsystem, category: "network")
    static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")
}

@MainActor
final class LogEmitter: ObservableObject {
    @Published private(set) var emitted = 0
    @Published private(set) var isStreaming = false

    private var task: Task<Void, Never>?

    func emitOneOfEach() {
        TestLog.general.debug("debug: the quietest level, filtered out by default")
        TestLog.general.info("info: routine detail, \(self.emitted + 1, privacy: .public) emitted so far")
        TestLog.general.notice("notice: the default level")
        TestLog.network.warning("warning: something looks off")
        TestLog.general.error("error: something failed")
        TestLog.lifecycle.critical("critical: the loudest level")
        // Not os.Logger. Worth having next to the others: print goes to stdout
        // and is tagged with the process, so it shows up only if the stream is
        // matching on process name rather than subsystem.
        print("print(): stdout, not the unified log")
        NSLog("NSLog(): tagged with the process name")
        emitted += 6
    }

    /// A steady trickle, so the stream can be watched scrolling rather than
    /// judged from a single burst.
    func toggleStream() {
        if isStreaming {
            task?.cancel()
            task = nil
            isStreaming = false
            TestLog.lifecycle.notice("log stream demo stopped")
            return
        }
        isStreaming = true
        TestLog.lifecycle.notice("log stream demo started")
        task = Task { [weak self] in
            var tick = 0
            while !Task.isCancelled {
                tick += 1
                TestLog.general.info("tick \(tick, privacy: .public): still streaming")
                if tick % 4 == 0 {
                    TestLog.network.error("tick \(tick, privacy: .public): simulated failure")
                }
                await MainActor.run { self?.emitted += 1 }
                try? await Task.sleep(nanoseconds: 900_000_000)
            }
            await MainActor.run { self?.isStreaming = false }
        }
    }
}

// MARK: - Permissions

@MainActor
final class PermissionProbe: ObservableObject {
    @Published var camera = "unknown"
    @Published var microphone = "unknown"
    @Published var photos = "unknown"
    @Published var contacts = "unknown"
    @Published var notifications = "unknown"
    @Published var biometrics = "not attempted"

    func refresh() {
        update(&camera, service: "camera", status: Self.describe(AVCaptureDevice.authorizationStatus(for: .video)))
        update(&microphone, service: "microphone", status: Self.describe(AVCaptureDevice.authorizationStatus(for: .audio)))

        let photosStatus: String
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized: photosStatus = "authorized"
        case .limited: photosStatus = "limited"
        case .denied: photosStatus = "denied"
        case .restricted: photosStatus = "restricted"
        case .notDetermined: photosStatus = "not determined"
        @unknown default: photosStatus = "unknown"
        }
        update(&photos, service: "photos", status: photosStatus)

        let contactsStatus: String
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized: contactsStatus = "authorized"
        case .limited: contactsStatus = "limited"
        case .denied: contactsStatus = "denied"
        case .restricted: contactsStatus = "restricted"
        case .notDetermined: contactsStatus = "not determined"
        @unknown default: contactsStatus = "unknown"
        }
        update(&contacts, service: "contacts", status: contactsStatus)

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let text: String
            switch settings.authorizationStatus {
            case .authorized: text = "authorized"
            case .denied: text = "denied"
            case .notDetermined: text = "not determined"
            case .provisional: text = "provisional"
            case .ephemeral: text = "ephemeral"
            @unknown default: text = "unknown"
            }
            Task { @MainActor in
                self.update(&self.notifications, service: "notifications", status: text)
            }
        }
    }

    /// E2E-03a: write a receipt whenever a status actually changes, so the
    /// permission tool's effect is readable from outside the simulator.
    private func update(_ slot: inout String, service: String, status: String) {
        let changed = slot != status
        slot = status
        if changed {
            Receipts.permission(service: service, status: status)
        }
    }

    func requestCamera() {
        AVCaptureDevice.requestAccess(for: .video) { _ in Task { @MainActor in self.refresh() } }
    }

    func requestMicrophone() {
        AVCaptureDevice.requestAccess(for: .audio) { _ in Task { @MainActor in self.refresh() } }
    }

    func requestPhotos() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in Task { @MainActor in self.refresh() } }
    }

    func requestContacts() {
        CNContactStore().requestAccess(for: .contacts) { _, _ in Task { @MainActor in self.refresh() } }
    }

    func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
            Task { @MainActor in self.refresh() }
        }
    }

    /// Drives CosmoKit's Face ID tool: enrolment, match and no-match all land here.
    func authenticate() {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            biometrics = "unavailable: \(error?.localizedDescription ?? "not enrolled")"
            return
        }
        biometrics = "waiting for biometry…"
        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Testing CosmoKit's Face ID simulation"
        ) { success, error in
            Task { @MainActor in
                self.biometrics = success ? "matched" : "failed: \(error?.localizedDescription ?? "cancelled")"
            }
        }
    }

    private static func describe(_ status: AVAuthorizationStatus) -> String {
        switch status {
        case .authorized: return "authorized"
        case .denied: return "denied"
        case .restricted: return "restricted"
        case .notDetermined: return "not determined"
        @unknown default: return "unknown"
        }
    }
}

// MARK: - User Defaults

@MainActor
final class DefaultsPlayground: ObservableObject {
    @Published var counter: Int {
        didSet { UserDefaults.standard.set(counter, forKey: "testCounter") }
    }
    @Published var featureEnabled: Bool {
        didSet { UserDefaults.standard.set(featureEnabled, forKey: "testFeatureEnabled") }
    }

    /// What UserDefaults reports right now, refreshed by `reload()`. The point of
    /// showing it is the gap it exposes: CosmoKit's editor writes the plist in
    /// the app's data container, and this app read those values into memory at
    /// launch. Until it launches again, an external edit is on disk and invisible
    /// here - reloading proves that rather than leaving it as a suspicion.
    @Published private(set) var liveReadout = ""

    init() {
        counter = UserDefaults.standard.integer(forKey: "testCounter")
        featureEnabled = UserDefaults.standard.bool(forKey: "testFeatureEnabled")
        seedIfNeeded()
        refreshReadout()
        TestLog.lifecycle.notice("defaults at launch: \(self.liveReadout, privacy: .public)")
    }

    /// Re-asks UserDefaults for the same keys, without relaunching.
    func reload() {
        counter = UserDefaults.standard.integer(forKey: "testCounter")
        featureEnabled = UserDefaults.standard.bool(forKey: "testFeatureEnabled")
        refreshReadout()
        TestLog.general.notice("defaults reloaded: \(self.liveReadout, privacy: .public)")
    }

    private func refreshReadout() {
        let defaults = UserDefaults.standard
        let string = defaults.string(forKey: "testString") ?? "-"
        liveReadout = "testCounter=\(defaults.integer(forKey: "testCounter")) testString=\(string)"
    }

    /// One value of each type. `testIntThatLooksLikeBool` is the interesting one:
    /// NSNumber bridging makes an Int 1 answer `as? Bool` with true, so an editor
    /// that trusts the cast renders it as a switch.
    func seedIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: "testSeeded") == nil else { return }
        defaults.set(true, forKey: "testSeeded")
        defaults.set("hello from the test app", forKey: "testString")
        defaults.set(1, forKey: "testIntThatLooksLikeBool")
        defaults.set(0, forKey: "testZeroThatLooksLikeFalse")
        defaults.set(true, forKey: "testActualBool")
        defaults.set(3.14159, forKey: "testDouble")
        defaults.set(["alpha", "beta"], forKey: "testArray")
        defaults.set(["environment": "staging"], forKey: "testDictionary")
        defaults.set(Date(), forKey: "testDate")
    }

    func reseed() {
        UserDefaults.standard.removeObject(forKey: "testSeeded")
        seedIfNeeded()
    }
}

// MARK: - App Data

@MainActor
final class AppDataPlayground: ObservableObject {
    @Published private(set) var summary = "not counted yet"

    private var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Writes into Documents, Library and Caches - the three trees Clear App Data
    /// removes - so the tool's effect is countable rather than taken on faith.
    func writeSamples() {
        let fm = FileManager.default
        let targets: [URL] = [
            documents,
            fm.urls(for: .libraryDirectory, in: .userDomainMask)[0],
            fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        ]
        var written = 0
        for directory in targets {
            for index in 1...3 {
                let file = directory.appendingPathComponent("cosmokit-sample-\(index).txt")
                if (try? "sample \(index)".write(to: file, atomically: true, encoding: .utf8)) != nil {
                    written += 1
                }
            }
        }
        summary = "wrote \(written) files"
    }

    func count() {
        let fm = FileManager.default
        var total = 0
        for directory in [documents,
                          fm.urls(for: .libraryDirectory, in: .userDomainMask)[0],
                          fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]] {
            let contents = (try? fm.contentsOfDirectory(atPath: directory.path)) ?? []
            total += contents.filter { $0.hasPrefix("cosmokit-sample-") }.count
        }
        summary = "\(total) sample files present"
    }
}
