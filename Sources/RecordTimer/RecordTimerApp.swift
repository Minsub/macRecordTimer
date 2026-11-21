import AppKit
import Darwin
import SwiftUI

@main
struct RecordTimerApp: App {
    @StateObject private var monitor = RecordingMonitor()

    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "timer")
                        .foregroundStyle(monitor.isRecording ? .blue : .secondary)
                    Text(monitor.isRecording ? "화면 녹화 중" : "녹화 대기 중")
                        .font(.headline)
                }

                if monitor.isRecording {
                    Text(monitor.elapsedText)
                        .font(.system(.title2, design: .monospaced).weight(.semibold))
                        .monospacedDigit()
                } else {
                    Text("Shift–Command–5로 녹화를 시작하세요.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()
                Toggle("화면에 큰 타이머 표시", isOn: $monitor.overlayEnabled)

                HStack {
                    Text("크기")
                    Slider(value: $monitor.fontSize, in: 32...72, step: 4)
                    Text("\(Int(monitor.fontSize)) pt")
                        .monospacedDigit()
                        .frame(width: 48, alignment: .trailing)
                }
                .disabled(!monitor.overlayEnabled)

                HStack(spacing: 12) {
                    Stepper(value: $monitor.thresholdMinutes, in: 0...180) {
                        Text("분: \(monitor.thresholdMinutes)")
                    }
                    Stepper(value: $monitor.thresholdSeconds, in: 0...59) {
                        Text("초: \(monitor.thresholdSeconds)")
                    }
                }
                Text("강조 시작 시간")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Picker("강조 방식", selection: $monitor.alertStyle) {
                    Text("빨간색").tag(TimerAlertStyle.red)
                    Text("깜빡임").tag(TimerAlertStyle.blink)
                }
                .pickerStyle(.segmented)

                Text("타이머를 드래그해 화면에서 위치를 바꿀 수 있어요.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Divider()
                Button("종료") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            }
            .padding(14)
            .frame(minWidth: 290)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "timer")
                if monitor.isRecording {
                    Text(monitor.elapsedText).monospacedDigit()
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}

enum TimerAlertStyle: String {
    case red
    case blink
}

@MainActor
final class RecordingMonitor: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var elapsedText = "00:00"
    @Published private(set) var elapsedSeconds = 0
    @Published private(set) var blinkOn = false

    @Published var overlayEnabled: Bool {
        didSet { UserDefaults.standard.set(overlayEnabled, forKey: "overlayEnabled"); updateOverlay() }
    }
    @Published var fontSize: Double {
        didSet { UserDefaults.standard.set(fontSize, forKey: "overlayFontSize"); updateOverlay() }
    }
    @Published var thresholdMinutes: Int {
        didSet {
            UserDefaults.standard.set(thresholdMinutes, forKey: "thresholdMinutesV2")
            if thresholdMinutes == 0 && thresholdSeconds == 0 { thresholdSeconds = 1 }
            updateOverlay()
        }
    }
    @Published var thresholdSeconds: Int {
        didSet {
            UserDefaults.standard.set(thresholdSeconds, forKey: "thresholdSeconds")
            if thresholdMinutes == 0 && thresholdSeconds == 0 { thresholdSeconds = 1 }
            updateOverlay()
        }
    }
    @Published var alertStyle: TimerAlertStyle {
        didSet { UserDefaults.standard.set(alertStyle.rawValue, forKey: "alertStyle"); updateOverlay() }
    }

    var shouldEmphasize: Bool {
        isRecording && TimerClock.isEmphasized(
            elapsedSeconds: elapsedSeconds,
            thresholdSeconds: thresholdMinutes * 60 + thresholdSeconds
        )
    }

    private var timer: Timer?
    private var recordingStartUptime: TimeInterval?
    private var elapsedOffsetAtStart: TimeInterval = 0
    private var missingSince: Date?
    private var hasCompletedInitialDetection = false
    private var isCheckingProcess = false
    private let missingGracePeriod: TimeInterval = 2
    private let overlayController = TimerOverlayController()

    init() {
        let defaults = UserDefaults.standard
        overlayEnabled = defaults.object(forKey: "overlayEnabled") as? Bool ?? true
        fontSize = defaults.object(forKey: "overlayFontSize") as? Double ?? 48
        thresholdMinutes = defaults.object(forKey: "thresholdMinutesV2") as? Int ?? 2
        thresholdSeconds = defaults.object(forKey: "thresholdSeconds") as? Int ?? 0
        alertStyle = TimerAlertStyle(rawValue: defaults.string(forKey: "alertStyle") ?? "red") ?? .red
        refresh()
        let updateTimer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        timer = updateTimer
        RunLoop.main.add(updateTimer, forMode: .common)
    }

    private func tick() {
        let now = Date()
        updateElapsedTime(now: now)
        updateBlinkPhase()
        refresh()
    }

    private func refresh() {
        guard !isCheckingProcess else { return }
        isCheckingProcess = true
        Task.detached(priority: .utility) { [weak self] in
            let recordingStartDate = Self.activeRecordingStartDate()
            await self?.applyRecordingState(recordingStartDate: recordingStartDate, now: Date())
        }
    }

    private func applyRecordingState(recordingStartDate: Date?, now: Date) {
        isCheckingProcess = false
        let wasRecording = isRecording
        if let recordingStartDate {
            missingSince = nil
            if recordingStartUptime == nil {
                // Recover the elapsed portion only when the app launches mid-recording.
                elapsedOffsetAtStart = hasCompletedInitialDetection
                    ? 0
                    : max(0, now.timeIntervalSince(recordingStartDate))
                recordingStartUptime = ProcessInfo.processInfo.systemUptime
            }
            isRecording = true
        } else if isRecording {
            if missingSince == nil { missingSince = now }
            if let missingStart = missingSince, now.timeIntervalSince(missingStart) >= missingGracePeriod {
                recordingStartUptime = nil
                elapsedOffsetAtStart = 0
                missingSince = nil
                isRecording = false
            }
        }

        hasCompletedInitialDetection = true
        if wasRecording != isRecording { updateOverlay() }
        updateElapsedTime(now: now)
        updateBlinkPhase()
    }

    private func updateElapsedTime(now: Date) {
        let nextSeconds: Int
        if isRecording, let recordingStartUptime {
            nextSeconds = TimerClock.elapsedSeconds(
                startUptime: recordingStartUptime,
                nowUptime: ProcessInfo.processInfo.systemUptime,
                offset: elapsedOffsetAtStart
            )
        } else {
            nextSeconds = 0
        }
        guard nextSeconds != elapsedSeconds else { return }
        elapsedSeconds = nextSeconds
        elapsedText = String(format: "%02d:%02d", elapsedSeconds / 60, elapsedSeconds % 60)
        updateOverlay()
    }

    private func updateBlinkPhase() {
        let next = shouldEmphasize
            && alertStyle == .blink
            && TimerClock.blinkPhase(uptime: ProcessInfo.processInfo.systemUptime)
        guard blinkOn != next else { return }
        blinkOn = next
        updateOverlay()
    }

    private func updateOverlay() {
        overlayController.update(
            isVisible: isRecording && overlayEnabled,
            elapsedText: elapsedText,
            fontSize: fontSize,
            emphasized: shouldEmphasize,
            alertStyle: alertStyle,
            blinkOn: blinkOn
        )
    }

    /// The selection UI can run without recording. While capturing, Apple's
    /// `replayd` owns the active file descriptor on this macOS version; the
    /// `screencapture` UI process itself does not. Match the native capture
    /// container path so old MOVs and unrelated ReplayKit files are ignored.
    nonisolated private static func activeRecordingStartDate() -> Date? {
        let lsof = Process()
        lsof.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        lsof.arguments = ["-Fn", "-c", "replayd"]
        let output = Pipe()
        lsof.standardOutput = output
        lsof.standardError = FileHandle.nullDevice

        do {
            try lsof.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            lsof.waitUntilExit()
            guard lsof.terminationStatus == 0,
                  let text = String(data: data, encoding: .utf8) else { return nil }
            for line in text.split(separator: "\n") where line.first == "n" {
                let path = String(line.dropFirst())
                guard path.contains("/group.com.apple.screencapture/ScreenRecordings/"),
                      URL(fileURLWithPath: path).pathExtension.lowercased() == "mov" else { continue }
                return (try? URL(fileURLWithPath: path).resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
            }
            return nil
        } catch {
            return nil
        }
    }
}

@MainActor
private final class TimerOverlayController: NSObject, NSWindowDelegate {
    private var panel: NSPanel?

    func update(isVisible: Bool, elapsedText: String, fontSize: Double, emphasized: Bool, alertStyle: TimerAlertStyle, blinkOn: Bool) {
        guard isVisible else {
            panel?.orderOut(nil)
            return
        }

        let view = TimerOverlayView(
            elapsedText: elapsedText,
            fontSize: fontSize,
            emphasized: emphasized,
            alertStyle: alertStyle,
            blinkOn: blinkOn
        )
        let width = max(190, fontSize * 5.0)
        let height = fontSize * 1.75

        if let panel {
            panel.contentView = NSHostingView(rootView: view)
            var frame = panel.frame
            frame.size = NSSize(width: width, height: height)
            panel.setFrame(frame, display: true)
            panel.orderFrontRegardless()
            return
        }

        let newPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        newPanel.contentView = NSHostingView(rootView: view)
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = true
        newPanel.isMovableByWindowBackground = true
        newPanel.level = .statusBar
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        newPanel.hidesOnDeactivate = false
        newPanel.delegate = self
        if UserDefaults.standard.object(forKey: "overlayX") != nil,
           UserDefaults.standard.object(forKey: "overlayY") != nil {
            newPanel.setFrameOrigin(NSPoint(
                x: UserDefaults.standard.double(forKey: "overlayX"),
                y: UserDefaults.standard.double(forKey: "overlayY")
            ))
        } else if let screen = NSScreen.main {
            newPanel.setFrameOrigin(NSPoint(
                x: screen.visibleFrame.maxX - width - 24,
                y: screen.visibleFrame.maxY - height - 40
            ))
        }
        panel = newPanel
        newPanel.orderFrontRegardless()
    }

    func windowDidMove(_ notification: Notification) {
        guard let panel else { return }
        UserDefaults.standard.set(panel.frame.origin.x, forKey: "overlayX")
        UserDefaults.standard.set(panel.frame.origin.y, forKey: "overlayY")
    }
}

private struct TimerOverlayView: View {
    let elapsedText: String
    let fontSize: Double
    let emphasized: Bool
    let alertStyle: TimerAlertStyle
    let blinkOn: Bool

    private var blinking: Bool { emphasized && alertStyle == .blink }

    var body: some View {
        Text(elapsedText)
            .font(.system(size: fontSize, weight: .bold, design: .monospaced))
            .monospacedDigit()
            .foregroundStyle(emphasized ? (blinking && !blinkOn ? Color.black : Color.white) : Color.primary)
            .padding(.horizontal, fontSize * 0.35)
            .padding(.vertical, fontSize * 0.12)
            .background {
                if emphasized && alertStyle == .red {
                    Capsule().fill(Color.red)
                } else if blinking {
                    Capsule().fill(blinkOn ? Color.red : Color.yellow)
                } else {
                    Capsule().fill(.ultraThickMaterial)
                }
            }
            .overlay(Capsule().strokeBorder(.white.opacity(emphasized ? 0.8 : 0.25), lineWidth: emphasized ? 2 : 1))
            .shadow(color: emphasized ? .red.opacity(0.7) : .clear, radius: emphasized ? 12 : 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

