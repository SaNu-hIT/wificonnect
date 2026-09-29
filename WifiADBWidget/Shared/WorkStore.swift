import Foundation
import WidgetKit

struct WorkProject: Codable, Equatable {
    var name: String
    var status: String?
    var next: String?
    var due: String?  // yyyy-MM-dd

    private static let dateFormat: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var dueDate: Date? { due.flatMap { Self.dateFormat.date(from: $0) } }

    /// Whole days from today until the due date; negative when overdue.
    var daysLeft: Int? {
        guard let dueDate else { return nil }
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: dueDate)).day
    }
}

struct WorkData: Codable, Equatable {
    var focus: String?
    var projects: [WorkProject] = []

    /// The project named in `focus`, else the first one.
    var focused: WorkProject? {
        projects.first { $0.name == focus } ?? projects.first
    }

    var others: [WorkProject] {
        guard let focused else { return projects }
        return projects.filter { $0.name != focused.name }
    }
}

/// Work-buddy data: the app reads work.json from ~/Documents and publishes it here for the widget.
enum WorkStore {
    private static let key = "work"

    static let example = """
    {
      "focus": "wificonnect",
      "projects": [
        {
          "name": "wificonnect",
          "status": "in progress",
          "next": "Build the widget in Xcode and add it to the desktop",
          "due": "2026-10-05"
        },
        {
          "name": "Example project",
          "status": "waiting on review",
          "next": "Reply to review comments",
          "due": "2026-10-15"
        }
      ]
    }

    """

    static func load() -> WorkData {
        guard let data = sharedDefaults.data(forKey: key) else { return WorkData() }
        return (try? sharedDecoder.decode(WorkData.self, from: data)) ?? WorkData()
    }

    /// Stores the data and refreshes the widget only when something changed.
    static func save(_ work: WorkData) {
        guard work != load() else { return }
        sharedDefaults.set(try? sharedEncoder.encode(work), forKey: key)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func decode(_ data: Data) throws -> WorkData {
        try sharedDecoder.decode(WorkData.self, from: data)
    }
}
