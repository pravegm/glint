import Foundation

// MARK: - Today's Dawn seed (GAME-DESIGN §6): the same sunrise for everyone on a UTC day

enum DailySeed {

    /// A Gregorian calendar fixed to UTC.
    static var utcCalendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0) ?? c.timeZone
        return c
    }

    /// Days since 2026-01-01 (day 0) on the UTC calendar. Negative before then.
    static func day(for date: Date) -> Int {
        let calendar: Calendar = utcCalendar
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 1
        comps.day = 1
        comps.hour = 12
        guard let epoch = calendar.date(from: comps) else { return 0 }
        let a: Date = calendar.startOfDay(for: epoch)
        let b: Date = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: a, to: b).day ?? 0
    }

    /// The day's seed (deterministic and well mixed: neighbouring days are unrelated).
    static func seed(day: Int) -> UInt64 {
        var rng = SeededRandom(seed: 0x474C_494E_5400_0000 ^ UInt64(bitPattern: Int64(day)))
        return rng.next()
    }
}
