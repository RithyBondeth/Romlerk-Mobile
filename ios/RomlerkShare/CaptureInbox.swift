import Foundation
final class CaptureInbox {
  static let group = "group.dev.romlerk.app"
  static let maxText = 12000
  static func mutate<T>(_ operation: (inout [String]) throws -> T) throws -> T {
    guard let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else {
      throw NSError(domain: "CaptureInbox", code: 1)
    }
    let url = directory.appendingPathComponent("capture-inbox.json")
    let coordinator = NSFileCoordinator()
    var coordinationError: NSError?
    var outcome: Result<T, Error>?
    coordinator.coordinate(writingItemAt: url, options: .forMerging, error: &coordinationError) { path in
      outcome = Result {
        var values: [String] = []
        if FileManager.default.fileExists(atPath: path.path) {
          values = try JSONDecoder().decode([String].self, from: Data(contentsOf: path))
        }
        let result = try operation(&values)
        let data = try JSONEncoder().encode(values)
        try data.write(to: path, options: [.atomic, .completeFileProtection])
        var excluded = path
        var attributes = URLResourceValues()
        attributes.isExcludedFromBackup = true
        try excluded.setResourceValues(attributes)
        return result
      }
    }
    if let error = coordinationError { throw error }
    guard let outcome else { throw NSError(domain: "CaptureInbox", code: 2) }
    return try outcome.get()
  }
  static func append(_ text: String) throws {
    try mutate { values in
      guard text.count <= maxText, values.count < 100 else { throw NSError(domain: "CaptureInbox", code: 3) }
      values.append(text)
    }
  }
  static func take() throws -> String? { try mutate { values in values.isEmpty ? nil : values.removeFirst() } }
  static func clear() throws { try mutate { $0.removeAll() } }
}

