import Foundation
import Flutter
import UIKit
import AppIntents

/// A coordinated app-group inbox lets the share extension hand off without
/// reading task data or launching the host through unsupported extension APIs.

@MainActor
final class QuickCaptureBridge {
  static var channel: FlutterMethodChannel?
  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "dev.romlerk/capture", binaryMessenger: messenger)
    self.channel = channel
    channel.setMethodCallHandler { call, result in
      do {
        switch call.method {
        case "take": result(try CaptureInbox.take())
        case "clear": try CaptureInbox.clear(); result(nil)
        default: result(FlutterMethodNotImplemented)
        }
      } catch { result(FlutterError(code: "CAPTURE_STORAGE", message: "Capture inbox unavailable", details: nil)) }
    }
  }
  static func enqueue(_ text: String = "") {
    do { try CaptureInbox.append(text); channel?.invokeMethod("available", arguments: nil) }
    catch { /* Keep the normal capture bar available; no text is logged. */ }
  }
  static func open(_ url: URL) -> Bool {
    guard url.scheme == "romlerk", url.host == "capture" else { return false }
    let text = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "text" })?.value ?? ""
    enqueue(text)
    return true
  }
}

@available(iOS 16.0, *)
struct CaptureTaskIntent: AppIntent {
  static var title: LocalizedStringResource = "Capture a task"
  static var description = IntentDescription("Open Romlerk to review and save a task. Text stays on this device.")
  static var openAppWhenRun = true
  @Parameter(title: "Text") var text: String?
  @MainActor func perform() async throws -> some IntentResult {
    try CaptureInbox.append(text ?? "")
    QuickCaptureBridge.channel?.invokeMethod("available", arguments: nil)
    return .result()
  }
}

@available(iOS 16.0, *)
struct RomlerkShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(intent: CaptureTaskIntent(), phrases: ["Capture a task in \(.applicationName)"], shortTitle: "Quick capture", systemImageName: "plus.circle")
  }
}
