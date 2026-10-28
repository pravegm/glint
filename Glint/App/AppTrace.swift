import Foundation

/// Two kinds of lines.
///
/// - `note(_:)`: a plain diagnostics ring (the last 200 notes, Release too), copied by About's hold-the-version
///   gesture. Notes are plain words with no `GLINT-` prefix.
/// - `demo(_:)`: the `GLINT-T …` lines CI greps (design/ROUND-1.md, App section). The function exists in DEBUG builds
///   only and prints through Feel's `FeelDemoLog.line(_:)`, which is silent unless the app was launched with
///   `-glintDemo`. EVERY call site sits inside `#if DEBUG` with the whole literal, so no `GLINT-T` literal (the release
///   guard greps for "GLINT-T paused shut") ever reaches a Release binary.
enum AppTrace {
    static let ringSize = 200
    nonisolated(unsafe) private static var ring: [String] = []

    /// One diagnostics note (kept in memory only; never sent anywhere).
    static func note(_ text: String) {
        let stamp = String(format: "%.2f", ProcessInfo.processInfo.systemUptime)
        ring.append(stamp + " " + text)
        if ring.count > ringSize { ring.removeFirst(ring.count - ringSize) }
    }

    /// The ring, oldest first.
    static func recentNotes() -> String {
        ring.joined(separator: "\n")
    }

    /// A finite Double with `places` decimals (0 for NaN / infinity), for log lines.
    static func fixed(_ value: Double, _ places: Int) -> String {
        let v = value.isFinite ? value : 0
        return String(format: "%.\(places)f", v)
    }

    #if DEBUG
    /// Prints a CI line (`GLINT-T …`, `GLINT-ICON …`) when launched with `-glintDemo`. DEBUG only.
    static func demo(_ line: String) {
        FeelDemoLog.line(line)
    }

    /// True when demo lines print (DEBUG + `-glintDemo`): skip building costly lines otherwise.
    static var demoEnabled: Bool { FeelDemoLog.isEnabled }
    #endif
}
