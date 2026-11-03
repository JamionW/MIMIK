import Foundation

/// The time tabs follow the clock unless the user picks another one, and go back to following
/// it when the hour bucket changes. Same rule as render() in app/index.html.
public struct ClockFollower: Equatable, Sendable {
    public private(set) var chosen: String?
    public private(set) var lastAuto: String?

    public init() {}

    /// Call with the clock's section id whenever it may have changed (on appear, on each tick).
    public mutating func observe(nowID: String) {
        if nowID != lastAuto {
            chosen = nil
            lastAuto = nowID
        }
    }

    /// Picking the clock's own tab goes back to following the clock.
    public mutating func choose(_ id: String, nowID: String) {
        observe(nowID: nowID)
        chosen = id == nowID ? nil : id
    }

    public func shown(nowID: String) -> String {
        chosen ?? nowID
    }
}

extension Language {
    /// The dates in (date, date + 24 h] at which the clock's section changes, with the section
    /// from then on: the widget's timeline. Only whole hours matter, since sections are set in hours.
    public func sectionChanges(after date: Date, calendar: Calendar = .current) -> [(date: Date, section: Section)] {
        guard let start = calendar.dateInterval(of: .hour, for: date)?.start,
              var current = section(forHour: calendar.component(.hour, from: date)) else { return [] }
        var out: [(date: Date, section: Section)] = []
        for step in 1...24 {
            guard let t = calendar.date(byAdding: .hour, value: step, to: start),
                  let s = section(forHour: calendar.component(.hour, from: t)) else { continue }
            if s.id != current.id {
                out.append((t, s))
                current = s
            }
        }
        return out
    }
}
