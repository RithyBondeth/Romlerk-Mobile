import Foundation

#if canImport(FoundationModels)
  import FoundationModels
#endif

/// The structure the on-device model is constrained to produce.
///
/// `@Generable` gives guided generation: the model cannot emit a shape that
/// does not match this type, which removes the whole class of "the model
/// returned prose instead of JSON" failures. Field descriptions are part of
/// the prompt the framework builds, so they are written for the model, not for
/// a human reader.
///
/// Apple's guidance is that on-device models are small and benefit from clear
/// instructions and reduced reasoning burden, so the schema stays flat and
/// every field is optional except the title.
@available(iOS 26.0, *)
@Generable
struct GeneratedTaskList {
  @Guide(description: "One entry per independently actionable commitment.")
  var tasks: [GeneratedTask]
}

@available(iOS 26.0, *)
@Generable
struct GeneratedTask {
  @Guide(
    description:
      "The action to take, with any date, time or priority wording removed. "
      + "For example 'Call David', not 'Call David tomorrow at 9'."
  )
  var title: String

  @Guide(
    description:
      "Supporting detail only. Never repeat scheduling wording here. "
      + "Empty when there is nothing to add."
  )
  var notes: String

  @Guide(
    description:
      "When the task is due, as an ISO-8601 timestamp with a timezone offset, "
      + "resolved against the supplied current time. Empty if no date was "
      + "stated or implied."
  )
  var dueAt: String

  @Guide(
    description:
      "Empty unless the user asked to be reminded at a different time from "
      + "the due date. Otherwise an ISO-8601 timestamp with offset."
  )
  var reminderAt: String

  @Guide(description: "One of: none, low, medium, high.")
  var priority: GeneratedPriority

  @Guide(description: "How long the task takes in minutes, or 0 if unstated.")
  var durationMinutes: Int

  @Guide(description: "Topic labels the user wrote with a # prefix.")
  var tags: [String]

  @Guide(
    description:
      "How the task repeats. Leave frequency as 'none' for a one-off task."
  )
  var recurrence: GeneratedRecurrence

  @Guide(
    description:
      "Anything you could not resolve safely, such as a vague time like "
      + "'later'. Prefer flagging over guessing when the answer would change "
      + "when a reminder fires."
  )
  var ambiguities: [GeneratedAmbiguity]
}

@available(iOS 26.0, *)
@Generable
enum GeneratedPriority: String {
  case none
  case low
  case medium
  case high
}

@available(iOS 26.0, *)
@Generable
struct GeneratedRecurrence {
  @Guide(description: "One of: none, daily, weekly, monthly, yearly.")
  var frequency: GeneratedFrequency

  @Guide(description: "Repeat every N periods. 1 for every period.")
  var interval: Int

  @Guide(
    description:
      "For weekly repeats only: ISO weekday numbers, Monday is 1 and Sunday "
      + "is 7. Empty otherwise."
  )
  var byWeekday: [Int]
}

@available(iOS 26.0, *)
@Generable
enum GeneratedFrequency: String {
  case none
  case daily
  case weekly
  case monthly
  case yearly
}

@available(iOS 26.0, *)
@Generable
struct GeneratedAmbiguity {
  @Guide(description: "The field in question: dueAt, reminderAt, or recurrence.")
  var field: String

  @Guide(
    description:
      "A short question for the user explaining what is unclear and why, in "
      + "plain language. For example: \"'later' doesn't say when. Pick a time.\""
  )
  var reason: String

  @Guide(description: "The words from the input that caused this.")
  var sourceSpan: String
}
