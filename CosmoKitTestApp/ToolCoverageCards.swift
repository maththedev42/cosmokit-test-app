//
//  ToolCoverageCards.swift
//  CosmoKitTestApp
//

import SwiftUI

// MARK: - Logs

struct LogsCard: View {
    @StateObject private var emitter = LogEmitter()

    var body: some View {
        FeaturePanel(icon: "text.alignleft", iconColor: .teal, title: "Log Stream",
                     subtitle: "os.Logger output CosmoKit can follow", borderColor: .teal) {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    toolButton("Emit 6 levels", tint: .teal) { emitter.emitOneOfEach() }
                    toolButton(emitter.isStreaming ? "Stop stream" : "Stream every 0.9s",
                               tint: emitter.isStreaming ? .red : .green) { emitter.toggleStream() }
                }

                readout("Lines emitted", "\(emitter.emitted)")
                readout("Subsystem", TestLog.subsystem)

                Text("CosmoKit matches on subsystem. print() and NSLog go to stdout under the process name, so they will not appear.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Permissions

struct PermissionsCard: View {
    @StateObject private var probe = PermissionProbe()

    var body: some View {
        FeaturePanel(icon: "hand.raised.fill", iconColor: .red, title: "Permissions",
                     subtitle: "simctl privacy grant, revoke and reset", borderColor: nil) {
            VStack(spacing: 10) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                    toolButton("Camera", tint: .blue) { probe.requestCamera() }
                    toolButton("Microphone", tint: .orange) { probe.requestMicrophone() }
                    toolButton("Photos", tint: .pink) { probe.requestPhotos() }
                    toolButton("Contacts", tint: .green) { probe.requestContacts() }
                    toolButton("Notifications", tint: .purple) { probe.requestNotifications() }
                    toolButton("Face ID", tint: .indigo) { probe.authenticate() }
                }

                VStack(spacing: 6) {
                    readout("Camera", probe.camera)
                    readout("Microphone", probe.microphone)
                    readout("Photos", probe.photos)
                    readout("Contacts", probe.contacts)
                    readout("Notifications", probe.notifications)
                    readout("Biometrics", probe.biometrics)
                }

                toolButton("Refresh statuses", tint: .gray) { probe.refresh() }
            }
        }
        .onAppear { probe.refresh() }
    }
}

// MARK: - Simulator environment

/// Nothing to press here. Appearance, Dynamic Type and the layout direction are
/// pushed from CosmoKit's Simulator Tools, and this panel exists to show that
/// they landed - the app is otherwise pinned to a light background and would
/// hide a dark-mode switch entirely.
struct EnvironmentCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        FeaturePanel(icon: "slider.horizontal.3", iconColor: .purple, title: "Simulator Environment",
                     subtitle: "Appearance, Dynamic Type, locale", borderColor: .purple) {
            VStack(spacing: 6) {
                readout("Appearance", colorScheme == .dark ? "dark" : "light")
                readout("Dynamic Type", "\(dynamicTypeSize)")
                readout("Layout direction", layoutDirection == .rightToLeft ? "right to left" : "left to right")
                readout("Locale", locale.identifier)
                readout("Reduce motion", reduceMotion ? "on" : "off")

                Text("Sample text at the current Dynamic Type size.")
                    .font(.body)
                    .foregroundStyle(.black.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
        }
    }
}

// MARK: - User defaults

struct DefaultsCard: View {
    @StateObject private var playground = DefaultsPlayground()

    var body: some View {
        FeaturePanel(icon: "externaldrive.fill", iconColor: .brown, title: "User Defaults",
                     subtitle: "Live values for the editor", borderColor: nil) {
            VStack(spacing: 10) {
                Stepper("testCounter: \(playground.counter)", value: $playground.counter)
                    .font(.system(size: 13, weight: .semibold))
                Toggle("testFeatureEnabled", isOn: $playground.featureEnabled)
                    .font(.system(size: 13, weight: .semibold))

                HStack(spacing: 8) {
                    toolButton("Re-seed sample keys", tint: .brown) { playground.reseed() }
                    toolButton("Reload", tint: .blue) { playground.reload() }
                }

                readout("Live", playground.liveReadout)

                Text("Seeded: testString, testDouble, testArray, testDictionary, testDate, testActualBool, and testIntThatLooksLikeBool = 1 next to testZeroThatLooksLikeFalse = 0.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.gray)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Edited a value in CosmoKit and nothing moved here? Press Reload. If it still shows the old value, the app has it cached from launch — restart it with CosmoKit's Restart App button.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - App data

struct AppDataCard: View {
    @StateObject private var playground = AppDataPlayground()

    var body: some View {
        FeaturePanel(icon: "folder.fill", iconColor: .yellow, title: "App Data",
                     subtitle: "Files for Clear App Data and the container", borderColor: nil) {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    toolButton("Write 9 files", tint: .yellow) { playground.writeSamples() }
                    toolButton("Count files", tint: .gray) { playground.count() }
                }
                readout("Status", playground.summary)
                Text("Three files each in Documents, Library and Caches. Clear App Data should take the count to zero.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Shared bits

@ViewBuilder
func readout(_ label: String, _ value: String) -> some View {
    HStack(alignment: .firstTextBaseline) {
        Text(label)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.gray)
        Spacer(minLength: 8)
        Text(value)
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundStyle(.black.opacity(0.82))
            .multilineTextAlignment(.trailing)
            .lineLimit(2)
            .truncationMode(.middle)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 7)
    .background(.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
}

func toolButton(_ title: String, tint: Color, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Text(title)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(tint.opacity(0.24), lineWidth: 1)
            }
    }
    .buttonStyle(.plain)
}
