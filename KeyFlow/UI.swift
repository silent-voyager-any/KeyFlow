// UI.swift — KeyFlow
// ─────────────────────────────────────────────────────────────
// This is your blank base. Build the UI here.
// The engine is already wired up in ViewModel — just call:
//   vm.startTyping()
//   vm.togglePause()
//   vm.clearAll()
// And bind to:
//   vm.inputText      — the text to type
//   vm.startDelay     — seconds before typing starts (Double)
//   vm.wpm            — words per minute (Double)
//   vm.variation      — speed randomness 0–100 (Double)
//   vm.pauseChance    — random pause % 0–40 (Double)
//   vm.longPauses     — Bool
//   vm.punctPauses    — Bool
//   vm.isRunning      — Bool
//   vm.isPaused       — Bool
//   vm.progress       — 0.0–1.0
//   vm.statusText     — String
//   vm.statusColor    — Color
//   vm.charCountText  — String
// ─────────────────────────────────────────────────────────────

import SwiftUI
import Cocoa
import Carbon.HIToolbox

// ─────────────────────────────────────────────────────────────
// MARK: App entry point
// ─────────────────────────────────────────────────────────────

@main
struct KeyFlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands { CommandGroup(replacing: .newItem) {} }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        for window in NSApplication.shared.windows {
            window.isOpaque        = false
            window.backgroundColor = .clear
            window.hasShadow       = true
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: ContentView  ← build your UI here
// ─────────────────────────────────────────────────────────────

struct ContentView: View {
    @StateObject private var vm = KeyFlowViewModel()

    var body: some View {
        VStack {
            Text("KeyFlow")
        }
        .frame(minWidth: 600, minHeight: 400)
        .preferredColorScheme(.dark)
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: ViewModel  — do not edit, engine is wired here
// ─────────────────────────────────────────────────────────────

enum TypingStatus {
    case ready, countdown(Int), typing, paused, done, accessibilityNeeded
}

@MainActor
class KeyFlowViewModel: ObservableObject {
    @Published var inputText   = ""
    @Published var startDelay  = 5.0
    @Published var wpm         = 60.0
    @Published var variation   = 40.0
    @Published var pauseChance = 8.0
    @Published var longPauses  = true
    @Published var punctPauses = true

    @Published var status:   TypingStatus = .ready
    @Published var progress: Double = 0
    @Published var isRunning = false
    @Published var isPaused  = false

    private let engine = KFEngine()
    private var countdownTimer: Timer?
    private var countdownSecs  = 0

    var charCountText: String { inputText.isEmpty ? "0 chars" : "\(inputText.count) chars" }
    var progressText:  String { progress > 0 ? String(format: "%.0f%%", progress * 100) : "" }

    var statusText: String {
        switch status {
        case .ready:                return "Ready"
        case .countdown(let s):     return "Starting in \(s)s — click your target window!"
        case .typing:               return "Typing..."
        case .paused:               return "Paused"
        case .done:                 return "Done"
        case .accessibilityNeeded:  return "Grant Accessibility in System Settings, then restart"
        }
    }

    var statusColor: Color {
        switch status {
        case .ready:               return .secondary
        case .countdown:           return .orange
        case .typing:              return .green
        case .paused:              return .orange
        case .done:                return .green
        case .accessibilityNeeded: return .orange
        }
    }

    func startTyping() {
        guard !inputText.isEmpty else { return }
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        guard AXIsProcessTrustedWithOptions(opts as CFDictionary) else {
            status = .accessibilityNeeded; return
        }
        var cfg         = KFTypingConfig()
        cfg.wpm         = wpm
        cfg.variation   = variation / 100.0
        cfg.pauseChance = pauseChance / 100.0
        cfg.longPauses  = ObjCBool(longPauses)
        cfg.punctPauses = ObjCBool(punctPauses)
        let delay       = Int32(startDelay)
        countdownSecs   = Int(startDelay)
        isRunning       = true
        isPaused        = false
        progress        = 0
        status          = .countdown(countdownSecs)
        engine.onProgress = { [weak self] done, total in
            self?.progress = Double(done) / Double(total)
        }
        engine.onDone = { [weak self] in
            self?.isRunning = false
            self?.status    = .done
        }
        engine.startWithText(inputText, delaySecs: delay, config: cfg)
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
            guard let self else { t.invalidate(); return }
            Task { @MainActor in
                self.countdownSecs -= 1
                if self.countdownSecs > 0 {
                    self.status = .countdown(self.countdownSecs)
                } else {
                    t.invalidate()
                    self.status = .typing
                }
            }
        }
    }

    func togglePause() {
        if isPaused { engine.resume(); isPaused = false; status = .typing }
        else        { engine.pause();  isPaused = true;  status = .paused }
    }

    func clearAll() {
        countdownTimer?.invalidate()
        engine.stop()
        isRunning = false; isPaused = false
        progress  = 0;     status   = .ready
        inputText = ""
    }
}
