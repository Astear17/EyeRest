import Foundation
struct Completion: Codable, Identifiable, Equatable { let id: UUID; let kind: ReminderKind; let completedAt: Date; init(kind: ReminderKind, completedAt: Date = .now) { id = UUID(); self.kind = kind; self.completedAt = completedAt } }
