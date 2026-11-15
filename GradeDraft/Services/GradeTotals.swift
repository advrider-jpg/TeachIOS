import Foundation

/// Display formatting for points. Totals are never stored: a draft's or final review's total is
/// the sum of its stored criterion points, computed by the types that own those criteria.
enum GradeTotals {
    static func formatted(_ value: Double) -> String {
        if value.rounded() == value, abs(value) < 1e15 {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }
}
