import Foundation
extension DateFormatter { static let eyeRestTime: DateFormatter = { let f = DateFormatter(); f.timeStyle = .short; f.dateStyle = .none; return f }() }
extension Date { var eyeRestTime: String { DateFormatter.eyeRestTime.string(from: self) } }
