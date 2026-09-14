//
//  DiagnosticsPlayground.swift
//  CosmoKitTestApp
//
//  TA-01: Diagnostics playground for testing scheme diagnostics switches.
//  Each button commits the specific diagnostic violation caught by CosmoKit.
//

import SwiftUI
import UIKit
import OSLog

// MARK: - Helper Targets

final class ZombieProbeTarget: NSObject {
    @objc dynamic func poke() -> String {
        return "zombie-ok"
    }
}

final class MTCLabelHolder {
    static let shared = MTCLabelHolder()
    weak var label: UILabel?
}

struct MTCRepresentableLabel: UIViewRepresentable {
    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.text = "Main Thread Checker Target Label"
        label.font = .systemFont(ofSize: 11)
        label.textColor = .gray
        MTCLabelHolder.shared.label = label
        return label
    }

    func updateUIView(_ uiView: UILabel, context: Context) {}
}

final class LayoutLoopUIView: UIView {
    static let shared = LayoutLoopUIView()
    private var widthConstraint: NSLayoutConstraint?
    private var toggleState = false
    var isSpinning = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        let c = widthAnchor.constraint(equalToConstant: 24)
        c.isActive = true
        self.widthConstraint = c
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard isSpinning else { return }
        toggleState.toggle()
        widthConstraint?.constant = toggleState ? 25 : 24
        setNeedsLayout()
    }

    func triggerLoop() {
        isSpinning = true
        setNeedsLayout()
        layoutIfNeeded()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.isSpinning = false
        }
    }
}

struct LayoutLoopRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> LayoutLoopUIView {
        LayoutLoopUIView.shared
    }

    func updateUIView(_ uiView: LayoutLoopUIView, context: Context) {}
}

// MARK: - State & Executor

@MainActor
final class DiagnosticsPlaygroundState: ObservableObject {
    static let shared = DiagnosticsPlaygroundState()

    @Published var scribbleReadout: String = "Tap button to inspect freed memory"
    @Published var coreDataStatus: String = "Idle"
    @Published var quietLogCount: Int = 0
    @Published var cfNetworkStatus: String = "Idle"
}

enum DiagnosticsPlayground {
    static let crashingSwitches: Set<String> = [
        "zombies",
        "mallocScribble",
        "coreDataConcurrency",
        "layoutFeedback"
    ]

    static func expectValue(for key: String) -> String {
        switch key {
        case "zombies": return "deallocated instance"
        case "mallocStackLogging": return "recording malloc"
        case "mallocScribble": return "guard"
        case "mainThreadChecker": return "Main Thread Checker"
        case "coreDataSQL": return "CoreData: sql"
        case "coreDataConcurrency": return "Multithreading_Violation"
        case "layoutFeedback": return "LayoutFeedbackLoop"
        case "nonLocalizedStrings": return "ui"
        case "doubleLocalizedStrings": return "ui"
        case "quietLog": return "ui"
        case "cfNetwork": return "CFNetwork"
        default: return "unknown"
        }
    }

    static func execute(key: String) {
        Receipts.record(kind: "diagnostic.\(key)", payload: ["triggered": true, "expect": expectValue(for: key)])
        switch key {
        case "zombies":
            var probe: ZombieProbeTarget? = ZombieProbeTarget()
            let unmanaged = Unmanaged.passUnretained(probe!)
            probe = nil
            _ = unmanaged.takeUnretainedValue().poke()

        case "mallocStackLogging":
            for _ in 0..<10 {
                let ptr = malloc(1024 * 1024)
                _ = ptr
            }
            TestLog.general.notice("leaked 10 MB")

        case "mallocScribble":
            if let ptr = malloc(16)?.assumingMemoryBound(to: UInt8.self) {
                free(ptr)
                let bytes = (0..<16).map { String(format: "%02x", ptr[$0]) }.joined(separator: " ")
                Task { @MainActor in
                    DiagnosticsPlaygroundState.shared.scribbleReadout = "Freed: \(bytes)"
                }
            }
            if let guardPtr = malloc(16)?.assumingMemoryBound(to: UInt8.self) {
                guardPtr[16] = 0xAA
                free(guardPtr)
            }

        case "mainThreadChecker":
            DispatchQueue.global().async {
                MTCLabelHolder.shared.label?.text = "MTC violation triggered: \(Date())"
            }

        case "coreDataSQL":
            let count = CoreDataStack.shared.insertAndFetchNotes(count: 20)
            Task { @MainActor in
                DiagnosticsPlaygroundState.shared.coreDataStatus = "\(count) notes inserted and fetched"
            }

        case "coreDataConcurrency":
            CoreDataStack.shared.violateConcurrency()

        case "layoutFeedback":
            LayoutLoopUIView.shared.triggerLoop()

        case "nonLocalizedStrings", "doubleLocalizedStrings":
            break

        case "quietLog":
            let log = Logger(subsystem: TestLog.subsystem, category: "quietLog")
            for i in 1...20 {
                log.info("QuietLog info message \(i)")
                log.debug("QuietLog debug message \(i)")
            }
            Task { @MainActor in
                DiagnosticsPlaygroundState.shared.quietLogCount = 20
            }

        case "cfNetwork":
            Task { @MainActor in
                DiagnosticsPlaygroundState.shared.cfNetworkStatus = "Sending GET..."
            }
            Task {
                let session = URLSession(configuration: .default)
                let url = URL(string: "https://httpbin.org/get")!
                do {
                    let (_, response) = try await session.data(from: url)
                    if let http = response as? HTTPURLResponse {
                        await MainActor.run {
                            DiagnosticsPlaygroundState.shared.cfNetworkStatus = "HTTP \(http.statusCode)"
                        }
                    }
                } catch {
                    await MainActor.run {
                        DiagnosticsPlaygroundState.shared.cfNetworkStatus = "Error: \(error.localizedDescription)"
                    }
                }
            }

        default:
            break
        }
    }

    @discardableResult
    static func handleDeepLink(url: URL) -> Bool {
        guard url.scheme == "cosmokittestapp", url.host == "diagnostic" else { return false }
        let key = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        execute(key: key)
        return true
    }
}

// MARK: - Diagnostics Card View

struct DiagnosticsCard: View {
    @StateObject private var state = DiagnosticsPlaygroundState.shared
    @State private var isExpanded: Bool = false
    @State private var awaitingConfirmKey: String? = nil
    @State private var confirmTimerTask: Task<Void, Never>? = nil

    var shouldShowCard: Bool {
        !ProcessInfo.processInfo.arguments.contains("--hide-diagnostics-playground")
    }

    var body: some View {
        if shouldShowCard {
            FeaturePanel(
                icon: "waveform.path.ecg",
                iconColor: .red,
                title: "Diagnostics Playground",
                subtitle: "One button per diagnostic switch",
                borderColor: isExpanded ? .red : nil
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    // Header expand / collapse trigger
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        HStack {
                            Text("Diagnostics playground — these crash on purpose")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.red)
                            Spacer()
                            Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.red)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)

                    if isExpanded {
                        VStack(spacing: 14) {
                            // 1. Zombies
                            diagnosticRow(
                                key: "zombies",
                                title: "Zombies",
                                whatToSee: "Messages a released object: aborts with 'message sent to deallocated instance'",
                                expectValue: "deallocated instance",
                                isCrashing: true
                            )

                            Divider()

                            // 2. Malloc stack logging
                            diagnosticRow(
                                key: "mallocStackLogging",
                                title: "Malloc stack logging",
                                whatToSee: "Allocates & leaks 10 MB; 'recording malloc' banner logged on launch",
                                expectValue: "recording malloc",
                                isCrashing: false
                            )

                            Divider()

                            // 3. Malloc scribble and guard edges
                            VStack(alignment: .leading, spacing: 6) {
                                diagnosticRow(
                                    key: "mallocScribble",
                                    title: "Malloc scribble and guard edges",
                                    whatToSee: "Inspects freed buffer (shows 0x55 if on) & writes past boundary (guard abort)",
                                    expectValue: "guard",
                                    isCrashing: true
                                )
                                readout("Scribble buffer", state.scribbleReadout)
                            }

                            Divider()

                            // 4. Main Thread Checker
                            VStack(alignment: .leading, spacing: 6) {
                                diagnosticRow(
                                    key: "mainThreadChecker",
                                    title: "Main Thread Checker",
                                    whatToSee: "Updates UIKit UILabel on background queue: logs MTC stack trace to stderr",
                                    expectValue: "Main Thread Checker",
                                    isCrashing: false
                                )
                                MTCRepresentableLabel()
                                    .frame(height: 18)
                            }

                            Divider()

                            // 5. Core Data SQL log
                            VStack(alignment: .leading, spacing: 6) {
                                diagnosticRow(
                                    key: "coreDataSQL",
                                    title: "Core Data SQL log",
                                    whatToSee: "Inserts & fetches 20 rows: logs 'CoreData: sql' statements and timings",
                                    expectValue: "CoreData: sql",
                                    isCrashing: false
                                )
                                readout("Core Data status", state.coreDataStatus)
                            }

                            Divider()

                            // 6. Core Data concurrency
                            diagnosticRow(
                                key: "coreDataConcurrency",
                                title: "Core Data concurrency",
                                whatToSee: "Accesses background object from main thread: aborts with Multithreading_Violation",
                                expectValue: "Multithreading_Violation",
                                isCrashing: true
                            )

                            Divider()

                            // 7. Layout feedback loop
                            VStack(alignment: .leading, spacing: 6) {
                                diagnosticRow(
                                    key: "layoutFeedback",
                                    title: "Layout feedback loop",
                                    whatToSee: "Toggles constraints in layoutSubviews: triggers LayoutFeedbackLoop abort (stops in 3s if off)",
                                    expectValue: "LayoutFeedbackLoop",
                                    isCrashing: true
                                )
                                LayoutLoopRepresentable()
                                    .frame(width: 24, height: 10)
                            }

                            Divider()

                            // 8 & 9. Strings: Non-localized & Double-length strings
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Non-localized strings")
                                            .font(.system(size: 13, weight: .bold))
                                        Text("Shows untranslated key in UPPERCASE")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.gray)
                                    }
                                    Spacer()
                                    toolButton("Test", tint: .blue) {
                                        DiagnosticsPlayground.execute(key: "nonLocalizedStrings")
                                    }
                                    .accessibilityIdentifier("diag.nonLocalizedStrings")
                                    .frame(width: 80)
                                }

                                HStack(spacing: 8) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Double-length strings")
                                            .font(.system(size: 13, weight: .bold))
                                        Text("Doubles localized string length to verify UI expansion")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.gray)
                                    }
                                    Spacer()
                                    toolButton("Test", tint: .blue) {
                                        DiagnosticsPlayground.execute(key: "doubleLocalizedStrings")
                                    }
                                    .accessibilityIdentifier("diag.doubleLocalizedStrings")
                                    .frame(width: 80)
                                }

                                // Live string display for visual verification of both switches
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Localized key:")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(.gray)
                                        Text(NSLocalizedString("diag.localized_sample", comment: ""))
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(.primary)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("Missing key:")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(.gray)
                                        Text(NSLocalizedString("diag.missing_key_sample", comment: ""))
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(.orange)
                                    }
                                }
                                .padding(8)
                                .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                            }

                            Divider()

                            // 10. Quiet os_log
                            VStack(alignment: .leading, spacing: 6) {
                                diagnosticRow(
                                    key: "quietLog",
                                    title: "Quiet os_log",
                                    whatToSee: "Emits 20 logs: hidden in unified stream when quiet log mode is active",
                                    expectValue: "ui",
                                    isCrashing: false
                                )
                                if state.quietLogCount > 0 {
                                    readout("QuietLog emitted", "\(state.quietLogCount) lines")
                                }
                            }

                            Divider()

                            // 11. CFNetwork diagnostics
                            VStack(alignment: .leading, spacing: 6) {
                                diagnosticRow(
                                    key: "cfNetwork",
                                    title: "CFNetwork diagnostics",
                                    whatToSee: "GET httpbin.org/get: floods stream with CFNetwork diagnostic traces",
                                    expectValue: "CFNetwork",
                                    isCrashing: false
                                )
                                readout("CFNetwork status", state.cfNetworkStatus)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
    }

    // MARK: - Row Builder

    private func diagnosticRow(
        key: String,
        title: String,
        whatToSee: String,
        expectValue: String,
        isCrashing: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.black.opacity(0.85))
                Text(whatToSee)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            let isAwaiting = awaitingConfirmKey == key
            Button {
                handleButtonTap(key: key, isCrashing: isCrashing)
            } label: {
                Text(isAwaiting ? "Tap to confirm" : (isCrashing ? "Trigger" : "Run"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isAwaiting ? Color.white : (isCrashing ? Color.red : Color.blue))
                    .frame(width: isAwaiting ? 104 : 76, height: 32)
                    .background(
                        isAwaiting ? Color.red : (isCrashing ? Color.red.opacity(0.12) : Color.blue.opacity(0.12)),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(isCrashing ? Color.red.opacity(0.3) : Color.blue.opacity(0.25), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("diag.\(key)")
        }
    }

    private func handleButtonTap(
        key: String,
        isCrashing: Bool
    ) {
        if isCrashing {
            if awaitingConfirmKey == key {
                // Confirmed tap within 2 seconds
                confirmTimerTask?.cancel()
                confirmTimerTask = nil
                awaitingConfirmKey = nil
                DiagnosticsPlayground.execute(key: key)
            } else {
                // First tap: start 2-second confirmation window
                confirmTimerTask?.cancel()
                awaitingConfirmKey = key
                confirmTimerTask = Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    if awaitingConfirmKey == key {
                        awaitingConfirmKey = nil
                    }
                }
            }
        } else {
            DiagnosticsPlayground.execute(key: key)
        }
    }

    private func readout(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label + ":")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.gray)
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
    }

    private func toolButton(_ title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(tint.opacity(0.25), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}
