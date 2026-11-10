import Foundation
final class CaptureInbox {
  struct Request: Codable { let id: String; let text: String }
  static let group = "group.dev.romlerk.app"
  static let maxText = 12000
  static func mutate<T>(_ operation: (inout [Request]) throws -> T) throws -> T {
    guard let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else {
      throw NSError(domain: "CaptureInbox", code: 1)
    }
    let url = directory.appendingPathComponent("capture-inbox.json")
    let coordinator = NSFileCoordinator()
    var coordinationError: NSError?
    var outcome: Result<T, Error>?
    coordinator.coordinate(writingItemAt: url, options: .forMerging, error: &coordinationError) { path in
      outcome = Result {
        var values: [Request] = []
        if FileManager.default.fileExists(atPath: path.path) {
          let data = try Data(contentsOf: path)
          if let entries = try? JSONDecoder().decode([Request].self, from: data) { values = entries }
          else { values = try JSONDecoder().decode([String].self, from: data).map { Request(id: UUID().uuidString, text: $0) } }
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
      values.append(Request(id: UUID().uuidString, text: text))
    }
  }
  static func peek() throws -> [String: String]? { try mutate { values in values.first.map { ["id": $0.id, "text": $0.text] } } }
  static func acknowledge(_ id: String) throws { try mutate { values in if values.first?.id == id { values.removeFirst() } } }
  static func clear() throws { try mutate { $0.removeAll() } }
}

