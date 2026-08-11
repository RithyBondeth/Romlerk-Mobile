import Flutter
import Foundation
import os

#if canImport(FoundationModels)
  import FoundationModels
#endif

/// iOS side of the `dev.romlerk/local_ai` channel.
///
/// Backed by Apple's Foundation Models framework on eligible devices. On
/// everything else — an older OS, an ineligible device, Apple Intelligence
/// switched off, a model still downloading — it reports that state honestly
/// and the Dart capability router runs the deterministic parser instead.
///
/// Nothing here decides product behaviour. It reports capability, returns
/// structured drafts, and translates vendor errors into the shared code
/// taxonomy; validity rules live in Dart.
final class LocalAiBridge {
  static let channelName = "dev.romlerk/local_ai"

  /// Bumped in lockstep with `TaskParseResult.currentSchemaVersion`.
  static let schemaVersion = 1

  /// Longer than the Dart-side timeout on purpose: Dart gives up first and
  /// cancels, so this only catches a genuinely wedged session.
  private static let maxInputCharacters = 1000

  private var inFlight: [String: Task<Void, Never>] = [:]

  static func register(messenger: any FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    let bridge = LocalAiBridge()
    channel.setMethodCallHandler { call, result in
      bridge.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "capabilities":
      result(capabilities())

    case "parseTasks":
      guard let arguments = call.arguments as? [String: Any] else {
        result(error(.unknown, "missing arguments"))
        return
      }
      parseTasks(arguments, result: result)

    case "estimateDuration":
      // Not offered yet: the capability payload does not advertise
      // durationEstimate, so Dart never routes here.
      result(nil)

    case "cancel":
      let requestId = (call.arguments as? [String: Any])?["requestId"] as? String
      cancel(requestId)
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Capabilities

  private func capabilities() -> [String: Any] {
    #if canImport(FoundationModels)
      if #available(iOS 26.0, *) {
        let model = SystemLanguageModel.default
        let (availability, reason): (String, String?) = {
          switch model.availability {
          case .available:
            return ("available", nil)
          case .unavailable(.deviceNotEligible):
            return ("notEligible", "DEVICE_NOT_ELIGIBLE")
          case .unavailable(.appleIntelligenceNotEnabled):
            return ("disabled", "APPLE_INTELLIGENCE_NOT_ENABLED")
          case .unavailable(.modelNotReady):
            return ("modelNotReady", "MODEL_NOT_READY")
          @unknown default:
            return ("unknown", "UNKNOWN_AVAILABILITY")
          }
        }()

        var payload: [String: Any] = [
          "provider": "appleFoundationModels",
          "availability": availability,
          "features": ["structuredText"],
          "languages": model.supportedLanguages.compactMap {
            $0.languageCode?.identifier
          },
          "constraints": [
            // Foundation Models has no foreground restriction and no quota of
            // the kind ML Kit imposes, so neither is claimed here.
            "foregroundOnly": false,
            "quotaPossible": false,
            "maxInputCharacters": Self.maxInputCharacters,
          ],
        ]
        if let reason { payload["reason"] = reason }
        return payload
      }
    #endif

    // Built without the SDK, or running on an OS that predates it.
    return [
      "provider": "appleFoundationModels",
      "availability": "notEligible",
      "features": [String](),
      "constraints": ["maxInputCharacters": Self.maxInputCharacters],
      "reason": "OS_TOO_OLD",
    ]
  }

  // MARK: - Parsing

  private func parseTasks(_ arguments: [String: Any], result: @escaping FlutterResult) {
    #if canImport(FoundationModels)
      if #available(iOS 26.0, *) {
        let text = (arguments["text"] as? String) ?? ""
        let requestId = (arguments["requestId"] as? String) ?? UUID().uuidString

        guard !text.isEmpty else {
          result(["schemaVersion": Self.schemaVersion, "tasks": [Any]()])
          return
        }
        guard text.count <= Self.maxInputCharacters else {
          result(error(.inputTooLong, "length=\(text.count)"))
          return
        }
        guard SystemLanguageModel.default.isAvailable else {
          result(error(.modelUnavailable, "model reported unavailable"))
          return
        }

        let task = Task { [weak self] in
          guard let self else { return }
          defer { self.inFlight.removeValue(forKey: requestId) }
          do {
            let payload = try await self.generate(arguments: arguments, text: text)
            guard !Task.isCancelled else {
              result(self.error(.cancelled, nil))
              return
            }
            result(payload)
          } catch is CancellationError {
            result(self.error(.cancelled, nil))
          } catch {
            result(self.translate(error))
          }
        }
        inFlight[requestId] = task
        return
      }
    #endif

    result(error(.modelUnavailable, "no on-device model on this OS"))
  }

  private func cancel(_ requestId: String?) {
    guard let requestId else { return }
    inFlight.removeValue(forKey: requestId)?.cancel()
  }

  #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func generate(
      arguments: [String: Any],
      text: String
    ) async throws -> [String: Any] {
      let referenceNow = (arguments["referenceNow"] as? String) ?? ""
      let timezone = (arguments["timezone"] as? String) ?? TimeZone.current.identifier
      let locale = (arguments["locale"] as? String) ?? Locale.current.identifier
      let knownTags = (arguments["knownTags"] as? [String]) ?? []
      let allowMultiple = (arguments["allowMultipleTasks"] as? Bool) ?? true

      let session = LanguageModelSession(
        instructions: Self.instructions(allowMultiple: allowMultiple)
      )

      // A 3B model is poor at calendar arithmetic. Rather than ask it to work
      // out which date "Friday" is, the upcoming dates are computed here and
      // handed over as a lookup table. Measured on device, this is the
      // difference between "Friday" resolving correctly and landing three days
      // late.
      let zone = TimeZone(identifier: timezone) ?? .current
      var prompt = """
        Current time: \(referenceNow)
        Timezone: \(timezone)
        Locale: \(locale)

        Calendar (use these exact dates, do not calculate your own):
        \(Self.calendarAnchor(referenceNow: referenceNow, timezone: zone))
        """
      if !knownTags.isEmpty {
        prompt += "\n\nExisting tags: \(knownTags.joined(separator: ", "))"
      }
      prompt += "\n\nInput: \(text)"

      let response = try await session.respond(
        to: prompt,
        generating: GeneratedTaskList.self,
        options: GenerationOptions(temperature: 0.1)
      )

      return try Self.encode(
        response.content,
        allowMultiple: allowMultiple,
        timezone: TimeZone(identifier: timezone) ?? .current
      )
    }

    /// The next fortnight as an explicit weekday → date table, so resolving
    /// "Friday" is a lookup rather than arithmetic.
    private static func calendarAnchor(
      referenceNow: String,
      timezone: TimeZone
    ) -> String {
      let start =
        isoWithFraction.date(from: referenceNow)
        ?? isoPlain.date(from: referenceNow)
        ?? Date()

      var calendar = Calendar(identifier: .gregorian)
      calendar.timeZone = timezone

      let formatter = DateFormatter()
      formatter.locale = Locale(identifier: "en_US_POSIX")
      formatter.timeZone = timezone
      formatter.dateFormat = "EEEE yyyy-MM-dd"

      // Eight days covers every weekday name plus "next <weekday>" for the
      // common cases. Longer tables cost tokens, and tokens cost latency.
      return (0...8)
        .compactMap { offset -> String? in
          guard
            let day = calendar.date(byAdding: .day, value: offset, to: start)
          else { return nil }
          let label =
            switch offset {
            case 0: " (today)"
            case 1: " (tomorrow)"
            default: ""
            }
          return "- \(formatter.string(from: day))\(label)"
        }
        .joined(separator: "\n")
    }

    /// Short, task-specific, and explicit about the one rule that matters:
    /// flag rather than guess. Apple's guidance is that on-device models do
    /// better with small tasks and clear instructions than with long prompts.
    private static func instructions(allowMultiple: Bool) -> String {
      var text = """
        You convert a person's note to themselves into structured task data.

        Rules:
        - Keep the title short and actionable, in sentence case. Strip \
        scheduling words, priority words and #tags out of it.
        - For dates, copy the matching line from the supplied calendar. Never \
        compute a date yourself. Output ISO-8601 with the supplied offset.
        - If a time is vague, such as "later" or "sometime", do NOT invent one. \
        Leave the date empty and record an ambiguity explaining what is unclear.
        - Never schedule anything in the past.
        - Leave reminderAt EMPTY unless the person explicitly asked to be \
        reminded at a different moment from the due date.
        - Only use a tag the person literally typed with a # prefix. If they \
        typed none, return no tags.
        - Only set a duration the person stated. Do not estimate one.
        - Only set a priority the person signalled with words like "urgent" or \
        "!". Otherwise use none.
        """
      text +=
        allowMultiple
        ? "\n- Split genuinely separate commitments into separate tasks."
        : "\n- Produce exactly one task."
      return text
    }

    /// Converts guided-generation output into the channel payload.
    ///
    /// Timestamps are validated here: a present-but-unparseable date means the
    /// model produced something the app cannot trust, so the whole result is
    /// rejected and the deterministic parser takes over.
    @available(iOS 26.0, *)
    private static func encode(
      _ list: GeneratedTaskList,
      allowMultiple: Bool,
      timezone: TimeZone
    ) throws -> [String: Any] {
      let candidates = allowMultiple ? list.tasks : Array(list.tasks.prefix(1))

      var tasks: [[String: Any]] = []
      for task in candidates {
        let title = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { continue }

        var encoded: [String: Any] = [
          "title": String(title.prefix(200)),
          "priority": task.priority.rawValue,
        ]

        let notes = task.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !notes.isEmpty { encoded["notes"] = String(notes.prefix(2000)) }

        if let dueAt = try normalizeTimestamp(task.dueAt, timezone: timezone) {
          encoded["dueAt"] = dueAt
          // Default the reminder to the due time unless the model named a
          // different one; Dart drops it if it lands in the past.
          encoded["reminderAt"] =
            try normalizeTimestamp(task.reminderAt, timezone: timezone) ?? dueAt
        }

        if task.durationMinutes > 0 && task.durationMinutes <= 1440 {
          encoded["durationMinutes"] = task.durationMinutes
          encoded["durationIsEstimate"] = true
        }

        let tags = task.tags
          .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
          .filter { !$0.isEmpty }
        if !tags.isEmpty { encoded["tags"] = Array(tags.prefix(10)) }

        if task.recurrence.frequency != .none {
          var recurrence: [String: Any] = [
            "frequency": task.recurrence.frequency.rawValue,
            "interval": min(max(task.recurrence.interval, 1), 365),
          ]
          let weekdays = task.recurrence.byWeekday.filter { (1...7).contains($0) }
          if !weekdays.isEmpty { recurrence["byWeekday"] = weekdays }
          encoded["recurrence"] = recurrence
        }

        let ambiguities = task.ambiguities.compactMap { ambiguity -> [String: Any]? in
          let reason = ambiguity.reason.trimmingCharacters(in: .whitespacesAndNewlines)
          guard !reason.isEmpty else { return nil }
          var entry: [String: Any] = [
            "field": normalizeField(ambiguity.field),
            "reason": String(reason.prefix(200)),
          ]
          let span = ambiguity.sourceSpan.trimmingCharacters(in: .whitespacesAndNewlines)
          if !span.isEmpty { entry["sourceSpan"] = String(span.prefix(120)) }
          return entry
        }
        if !ambiguities.isEmpty { encoded["ambiguities"] = ambiguities }

        tasks.append(encoded)
      }

      return [
        "schemaVersion": schemaVersion,
        "provider": "appleFoundationModels",
        "tasks": Array(tasks.prefix(8)),
      ]
    }

    /// Layouts the model plausibly emits, in preference order.
    ///
    /// A small model asked for "ISO-8601 with an offset" will sometimes return
    /// a bare local time instead. That is a formatting slip, not a wrong
    /// answer, so it is repaired against the request's timezone rather than
    /// used as grounds to throw the whole result away. Anything genuinely
    /// unreadable still fails closed.
    private static let localLayouts = [
      "yyyy-MM-dd'T'HH:mm:ss",
      "yyyy-MM-dd'T'HH:mm",
      "yyyy-MM-dd HH:mm:ss",
      "yyyy-MM-dd HH:mm",
      "yyyy-MM-dd",
    ]

    private static func makeIsoFormatter(
      _ options: ISO8601DateFormatter.Options
    ) -> ISO8601DateFormatter {
      let formatter = ISO8601DateFormatter()
      formatter.formatOptions = options
      return formatter
    }

    private static let isoWithFraction = makeIsoFormatter([
      .withInternetDateTime, .withFractionalSeconds,
    ])
    private static let isoPlain = makeIsoFormatter([.withInternetDateTime])

    /// Returns nil for "no date", a normalized ISO-8601 string with an offset
    /// for anything readable, and throws only when the model claimed a date
    /// that cannot be interpreted at all.
    private static func normalizeTimestamp(
      _ raw: String,
      timezone: TimeZone
    ) throws -> String? {
      let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty, trimmed.lowercased() != "null" else { return nil }

      if let date = isoWithFraction.date(from: trimmed)
        ?? isoPlain.date(from: trimmed)
      {
        return output(date, timezone: timezone)
      }

      let formatter = DateFormatter()
      formatter.locale = Locale(identifier: "en_US_POSIX")
      formatter.timeZone = timezone
      for layout in localLayouts {
        formatter.dateFormat = layout
        if let date = formatter.date(from: trimmed) {
          return output(date, timezone: timezone)
        }
      }

      throw LocalAiBridgeError.invalidOutput("unparseable timestamp")
    }

    private static func output(_ date: Date, timezone: TimeZone) -> String {
      let formatter = makeIsoFormatter([.withInternetDateTime])
      formatter.timeZone = timezone
      return formatter.string(from: date)
    }

    private static func normalizeField(_ raw: String) -> String {
      switch raw.trimmingCharacters(in: .whitespacesAndNewlines) {
      case "reminderAt": return "reminderAt"
      case "recurrence": return "recurrence"
      case "startAt": return "startAt"
      case "priority": return "priority"
      case "duration": return "duration"
      case "tags": return "tags"
      case "title": return "title"
      case "notes": return "notes"
      default: return "dueAt"
      }
    }
  #endif

  // MARK: - Errors

  /// Mirrors `LocalAiErrorCode` in Dart. Every value degrades to the
  /// deterministic parser rather than surfacing as a user-visible failure.
  private enum Code: String {
    case modelUnavailable = "MODEL_UNAVAILABLE"
    case modelNotReady = "MODEL_NOT_READY"
    case busyOrQuota = "BUSY_OR_QUOTA"
    case unsupportedLanguage = "UNSUPPORTED_LANGUAGE"
    case outputInvalid = "OUTPUT_INVALID"
    case cancelled = "CANCELLED"
    case inputTooLong = "INPUT_TOO_LONG"
    case unknown = "UNKNOWN"
  }

  /// Error shape only — never user task text, since this is both logged and
  /// forwarded to the local audit table.
  /// `OSLog` rather than `Logger`, which needs iOS 14 — the app still targets
  /// iOS 13.
  private static let log = OSLog(subsystem: "dev.romlerk", category: "local_ai")

  private func error(_ code: Code, _ details: String?) -> FlutterError {
    // Marked public in the log because these are fixed identifiers written by
    // this file. No interpolated value here can carry user content.
    os_log(
      "local_ai degraded: %{public}@ %{public}@",
      log: Self.log, type: .info, code.rawValue, details ?? "-")
    return FlutterError(code: code.rawValue, message: nil, details: details)
  }

  private func translate(_ raw: Error) -> FlutterError {
    if case LocalAiBridgeError.invalidOutput(let detail) = raw {
      return error(.outputInvalid, detail)
    }

    #if canImport(FoundationModels)
      if #available(iOS 26.0, *),
        let generation = raw as? LanguageModelSession.GenerationError
      {
        switch generation {
        case .exceededContextWindowSize:
          return error(.inputTooLong, "context window")
        case .assetsUnavailable:
          return error(.modelNotReady, "assets unavailable")
        case .rateLimited, .concurrentRequests:
          return error(.busyOrQuota, "rate limited")
        case .unsupportedLanguageOrLocale:
          return error(.unsupportedLanguage, "locale unsupported")
        case .decodingFailure, .unsupportedGuide, .guardrailViolation, .refusal:
          return error(.outputInvalid, "guided generation rejected")
        @unknown default:
          return error(.unknown, "generation error")
        }
      }
    #endif

    return error(.unknown, String(describing: type(of: raw)))
  }
}

enum LocalAiBridgeError: Error {
  case invalidOutput(String)
}
