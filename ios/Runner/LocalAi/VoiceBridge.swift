import AVFoundation
import Flutter
import Foundation
import Speech

/// iOS side of the `dev.romlerk/voice` channel (FR-16, Journey C).
///
/// Recognition is pinned to on-device with `requiresOnDeviceRecognition`.
/// Where the device or language cannot do that, this reports `unsupported`
/// or `languageUnsupported` rather than letting Apple's servers do the work:
/// NFR-07 says voice content never leaves the phone, and a quiet server
/// fallback would break that promise without the user ever knowing.
///
/// The bridge only transcribes. What the words mean is decided in Dart, from
/// the same text field typing uses.
final class VoiceBridge {
  static let channelName = "dev.romlerk/voice"

  private let channel: FlutterMethodChannel
  private let audioEngine = AVAudioEngine()
  private var request: SFSpeechAudioBufferRecognitionRequest?
  private var task: SFSpeechRecognitionTask?

  /// Bumped per session so a late callback from a cancelled recognizer cannot
  /// write into the next one.
  private var session = 0

  private init(channel: FlutterMethodChannel) {
    self.channel = channel
  }

  @discardableResult
  static func register(messenger: any FlutterBinaryMessenger) -> VoiceBridge {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    let bridge = VoiceBridge(channel: channel)
    channel.setMethodCallHandler { call, result in
      bridge.handle(call, result: result)
    }
    return bridge
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let arguments = call.arguments as? [String: Any]
    switch call.method {
    case "availability":
      result(["status": availability(locale: arguments?["locale"] as? String)])
    case "requestPermission":
      requestPermission(result)
    case "start":
      start(locale: arguments?["locale"] as? String, result: result)
    case "stop":
      stop()
      result(nil)
    case "cancel":
      cancel()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Availability

  private func recognizer(for locale: String?) -> SFSpeechRecognizer? {
    guard let locale, !locale.isEmpty else { return SFSpeechRecognizer() }
    return SFSpeechRecognizer(locale: Locale(identifier: locale))
  }

  private func availability(locale: String?) -> String {
    guard let recognizer = recognizer(for: locale) else {
      return "languageUnsupported"
    }
    guard recognizer.supportsOnDeviceRecognition else {
      // A recognizer exists for the language but only on the server.
      return SFSpeechRecognizer().map(\.supportsOnDeviceRecognition) == true
        ? "languageUnsupported" : "unsupported"
    }

    switch SFSpeechRecognizer.authorizationStatus() {
    case .denied, .restricted:
      return "permissionDenied"
    case .notDetermined:
      return "permissionNeeded"
    case .authorized:
      break
    @unknown default:
      return "permissionNeeded"
    }

    switch microphonePermission() {
    case .denied: return "permissionDenied"
    case .undetermined: return "permissionNeeded"
    case .granted: return "available"
    }
  }

  private enum MicrophonePermission { case granted, denied, undetermined }

  private func microphonePermission() -> MicrophonePermission {
    if #available(iOS 17.0, *) {
      switch AVAudioApplication.shared.recordPermission {
      case .granted: return .granted
      case .denied: return .denied
      default: return .undetermined
      }
    }
    switch AVAudioSession.sharedInstance().recordPermission {
    case .granted: return .granted
    case .denied: return .denied
    default: return .undetermined
    }
  }

  private func requestPermission(_ result: @escaping FlutterResult) {
    SFSpeechRecognizer.requestAuthorization { status in
      guard status == .authorized else {
        DispatchQueue.main.async { result(false) }
        return
      }
      let completion: (Bool) -> Void = { granted in
        DispatchQueue.main.async { result(granted) }
      }
      if #available(iOS 17.0, *) {
        AVAudioApplication.requestRecordPermission(completionHandler: completion)
      } else {
        AVAudioSession.sharedInstance().requestRecordPermission(completion)
      }
    }
  }

  // MARK: - Session

  private func start(locale: String?, result: @escaping FlutterResult) {
    cancel()

    guard let recognizer = recognizer(for: locale) else {
      result(FlutterError(code: "LANGUAGE_UNSUPPORTED", message: nil, details: nil))
      return
    }
    guard recognizer.supportsOnDeviceRecognition else {
      result(FlutterError(code: "UNAVAILABLE", message: nil, details: nil))
      return
    }
    guard SFSpeechRecognizer.authorizationStatus() == .authorized,
      microphonePermission() == .granted
    else {
      result(FlutterError(code: "PERMISSION_DENIED", message: nil, details: nil))
      return
    }
    guard recognizer.isAvailable else {
      result(FlutterError(code: "BUSY", message: nil, details: nil))
      return
    }

    let request = SFSpeechAudioBufferRecognitionRequest()
    request.requiresOnDeviceRecognition = true
    request.shouldReportPartialResults = true
    if #available(iOS 16.0, *) {
      request.addsPunctuation = true
    }

    do {
      let audioSession = AVAudioSession.sharedInstance()
      try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
      try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

      let input = audioEngine.inputNode
      let format = input.outputFormat(forBus: 0)
      input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
        request.append(buffer)
      }
      audioEngine.prepare()
      try audioEngine.start()
    } catch {
      teardownAudio()
      result(FlutterError(code: "BUSY", message: nil, details: nil))
      return
    }

    session += 1
    let current = session
    self.request = request
    task = recognizer.recognitionTask(with: request) { [weak self] recognition, error in
      DispatchQueue.main.async {
        guard let self, current == self.session else { return }
        if let recognition {
          self.channel.invokeMethod(
            "onTranscript",
            arguments: [
              "text": recognition.bestTranscription.formattedString,
              "isFinal": recognition.isFinal,
            ]
          )
          if recognition.isFinal {
            self.finish(error: nil)
            return
          }
        }
        if let error {
          self.finish(error: Self.code(for: error))
        }
      }
    }
    result(nil)
  }

  /// Ends recording; the recognizer then delivers its final transcript.
  private func stop() {
    guard task != nil else { return }
    teardownAudio()
    request?.endAudio()
  }

  private func cancel() {
    session += 1
    task?.cancel()
    task = nil
    request = nil
    teardownAudio()
  }

  private func finish(error: String?) {
    session += 1
    task = nil
    request = nil
    teardownAudio()
    channel.invokeMethod("onEnded", arguments: error.map { ["error": $0] } ?? [:])
  }

  private func teardownAudio() {
    if audioEngine.isRunning {
      audioEngine.stop()
    }
    audioEngine.inputNode.removeTap(onBus: 0)
    try? AVAudioSession.sharedInstance().setActive(
      false, options: .notifyOthersOnDeactivation)
  }

  private static func code(for error: Error) -> String {
    let nsError = error as NSError
    // kAFAssistantErrorDomain 1110: recording ended with nothing recognised.
    if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1110 {
      return "NO_SPEECH"
    }
    return "RECOGNITION_FAILED"
  }
}
