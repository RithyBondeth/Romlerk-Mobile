import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // App-level channel rather than a plugin: the adapter is specific to this
    // product's task schema and has no reuse value outside it.
    LocalAiBridge.register(messenger: engineBridge.applicationRegistrar.messenger())
    VoiceBridge.register(messenger: engineBridge.applicationRegistrar.messenger())
    registerStorageChannel(messenger: engineBridge.applicationRegistrar.messenger())
  }

  /// `dev.romlerk/storage`: marks the database's private directory as
  /// excluded from iCloud backup (FR-26). Setting the flag on a directory
  /// covers everything inside it, including SQLite's -wal and -shm files.
  private func registerStorageChannel(messenger: any FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "dev.romlerk/storage", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "excludeFromBackup",
        let path = (call.arguments as? [String: Any])?["path"] as? String
      else {
        result(FlutterMethodNotImplemented)
        return
      }
      var url = URL(fileURLWithPath: path, isDirectory: true)
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      do {
        try url.setResourceValues(values)
        result(nil)
      } catch {
        result(FlutterError(code: "EXCLUDE_FAILED", message: nil, details: nil))
      }
    }
  }
}
