import AppKit
import Carbon
import Charts
import ServiceManagement
import SwiftUI

private let commandNotification = Notification.Name("com.viraj.f3counter.command")
private let incrementHotKeyID: UInt32 = 1
private let resetHotKeyID: UInt32 = 2
private let hotKeySignature: OSType = 0x4633_4354 // 'F3CT'

struct HotKeyCombo: Codable, Equatable {
    var keyCode: UInt16
    var modifiers: UInt32

    static let countDefault = HotKeyCombo(keyCode: UInt16(kVK_F3), modifiers: 0)
    static let resetDefault = HotKeyCombo(keyCode: UInt16(kVK_F3), modifiers: UInt32(shiftKey))

    static let functionKeyCodes: Set<UInt16> = [
        UInt16(kVK_F1), UInt16(kVK_F2), UInt16(kVK_F3), UInt16(kVK_F4),
        UInt16(kVK_F5), UInt16(kVK_F6), UInt16(kVK_F7), UInt16(kVK_F8),
        UInt16(kVK_F9), UInt16(kVK_F10), UInt16(kVK_F11), UInt16(kVK_F12),
        UInt16(kVK_F13), UInt16(kVK_F14), UInt16(kVK_F15), UInt16(kVK_F16),
        UInt16(kVK_F17), UInt16(kVK_F18), UInt16(kVK_F19), UInt16(kVK_F20),
    ]

    static let modifierKeyCodes: Set<UInt16> = [
        UInt16(kVK_Command), UInt16(kVK_Shift), UInt16(kVK_CapsLock),
        UInt16(kVK_Option), UInt16(kVK_Control), UInt16(kVK_RightShift),
        UInt16(kVK_RightOption), UInt16(kVK_RightControl), UInt16(kVK_Function),
    ]

    var label: String {
        var symbols = ""
        if modifiers & UInt32(controlKey) != 0 { symbols += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { symbols += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { symbols += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { symbols += "⌘" }
        return symbols + keyTitle(for: keyCode)
    }

    var isSafe: Bool {
        if Self.functionKeyCodes.contains(keyCode) { return true }
        return modifiers & UInt32(cmdKey | optionKey | controlKey) != 0
    }

    /// The key the user pressed. Karabiner delivers F3 as F18 and Shift–F3 as F17.
    static func interpreted(keyCode: UInt16, modifiers: UInt32) -> HotKeyCombo {
        guard F3KeyShim.isActive else {
            return HotKeyCombo(keyCode: keyCode, modifiers: modifiers)
        }
        if keyCode == UInt16(kVK_F18), modifiers == 0 { return countDefault }
        if keyCode == UInt16(kVK_F17), modifiers == 0 { return resetDefault }
        return HotKeyCombo(keyCode: keyCode, modifiers: modifiers)
    }

    /// Codes to register. Includes the key Karabiner actually emits for F3.
    var registrationCombos: [HotKeyCombo] {
        guard F3KeyShim.isActive else { return [self] }
        if self == .countDefault {
            return [self, HotKeyCombo(keyCode: UInt16(kVK_F18), modifiers: 0)]
        }
        if self == .resetDefault {
            return [self, HotKeyCombo(keyCode: UInt16(kVK_F17), modifiers: 0)]
        }
        return [self]
    }
}

/// The F3 key on this keyboard is Mission Control, so Karabiner turns it into
/// F18 (and Shift–F3 into F17) before any app sees it.
private enum F3KeyShim {
    static var isActive: Bool {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/karabiner/karabiner.json")
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return false }
        return text.contains("\"key_code\": \"f18\"") && text.contains("\"key_code\": \"f3\"")
    }
}

private enum ShortcutRole: Equatable {
    case count
    case reset
}

private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
    var mask: UInt32 = 0
    if flags.contains(.control) { mask |= UInt32(controlKey) }
    if flags.contains(.option) { mask |= UInt32(optionKey) }
    if flags.contains(.shift) { mask |= UInt32(shiftKey) }
    if flags.contains(.command) { mask |= UInt32(cmdKey) }
    return mask
}

private func keyTitle(for keyCode: UInt16) -> String {
    switch Int(keyCode) {
    case kVK_F1: return "F1"
    case kVK_F2: return "F2"
    case kVK_F3: return "F3"
    case kVK_F4: return "F4"
    case kVK_F5: return "F5"
    case kVK_F6: return "F6"
    case kVK_F7: return "F7"
    case kVK_F8: return "F8"
    case kVK_F9: return "F9"
    case kVK_F10: return "F10"
    case kVK_F11: return "F11"
    case kVK_F12: return "F12"
    case kVK_F13: return "F13"
    case kVK_F14: return "F14"
    case kVK_F15: return "F15"
    case kVK_F16: return "F16"
    case kVK_F17: return "F17"
    case kVK_F18: return "F18"
    case kVK_F19: return "F19"
    case kVK_F20: return "F20"
    case kVK_Return: return "Return"
    case kVK_Tab: return "Tab"
    case kVK_Space: return "Space"
    case kVK_Delete: return "Delete"
    case kVK_ForwardDelete: return "⌦"
    case kVK_Escape: return "Esc"
    case kVK_LeftArrow: return "Left"
    case kVK_RightArrow: return "Right"
    case kVK_UpArrow: return "Up"
    case kVK_DownArrow: return "Down"
    case kVK_Home: return "Home"
    case kVK_End: return "End"
    case kVK_PageUp: return "Page Up"
    case kVK_PageDown: return "Page Down"
    default:
        return translatedKeyTitle(keyCode) ?? "Key \(keyCode)"
    }
}

private func translatedKeyTitle(_ keyCode: UInt16) -> String? {
    guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
          let raw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
        return nil
    }
    let data = unsafeBitCast(raw, to: CFData.self) as Data
    var deadKeyState: UInt32 = 0
    var length = 0
    var chars = [UniChar](repeating: 0, count: 4)
    let status = data.withUnsafeBytes { buffer -> OSStatus in
        guard let base = buffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return -1 }
        return UCKeyTranslate(
            base,
            keyCode,
            UInt16(kUCKeyActionDisplay),
            0,
            UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            chars.count,
            &length,
            &chars
        )
    }
    guard status == noErr, length > 0 else { return nil }
    return String(utf16CodeUnits: chars, count: Int(length)).uppercased()
}

@MainActor
private final class ShortcutCapture: ObservableObject {
    var onKey: ((NSEvent) -> NSEvent?)?
    private var monitor: Any?

    func start() {
        stop()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.onKey?(event) ?? event
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}

struct DistractionSession: Codable, Identifiable, Equatable {
    var id: UUID
    var startedAt: Date
    var endedAt: Date
    var distractionCount: Int

    var duration: TimeInterval {
        endedAt.timeIntervalSince(startedAt)
    }
}

private struct OpenSessionRecord: Codable {
    var startedAt: Date
}

enum RateBucket: String, CaseIterable, Identifiable {
    case day
    case week
    case month

    var id: String { rawValue }

    var component: Calendar.Component {
        switch self {
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        }
    }

    var previousName: String {
        switch self {
        case .day: "day"
        case .week: "week"
        case .month: "month"
        }
    }

    func startDate(for date: Date, calendar: Calendar = .current) -> Date {
        switch self {
        case .day:
            return calendar.startOfDay(for: date)
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: date)?.start
                ?? calendar.startOfDay(for: date)
        case .month:
            let parts = calendar.dateComponents([.year, .month], from: date)
            return calendar.date(from: parts) ?? calendar.startOfDay(for: date)
        }
    }
}

struct RatePoint: Identifiable {
    var start: Date
    var rate: Double
    var id: Date { start }
}

enum DurationSpan: String, CaseIterable, Identifiable {
    case day
    case week
    case month
    case year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day: "Days"
        case .week: "Weeks"
        case .month: "Months"
        case .year: "Years"
        }
    }

    fileprivate func start(count: Int, before end: Date, calendar: Calendar) -> Date {
        let start: Date?
        switch self {
        case .day:
            start = calendar.date(byAdding: .day, value: -count, to: end)
        case .week:
            let today = calendar.startOfDay(for: end)
            start = calendar.date(byAdding: .day, value: -(count * 7 - 1), to: today)
        case .month:
            start = calendar.date(byAdding: .month, value: -count, to: end)
        case .year:
            start = calendar.date(byAdding: .year, value: -count, to: end)
        }
        return start ?? end
    }

    fileprivate func phrase(count: Int, previous: Bool) -> String {
        switch (count, self, previous) {
        case (1, .week, false):
            return "past 7 days"
        case (1, .week, true):
            return "7 days before that"
        case (1, .month, false):
            return "past month"
        case (1, .month, true):
            return "previous month"
        case (1, .year, false):
            return "past year"
        case (1, .year, true):
            return "previous year"
        case (1, _, false):
            return "past \(rawValue)"
        case (1, _, true):
            return "\(rawValue) before that"
        case (_, _, false):
            return "past \(count) \(title.lowercased())"
        case (_, _, true):
            return "\(count) \(title.lowercased()) before that"
        }
    }
}

enum ResolvedDuration: Equatable {
    case trailing(count: Int, span: DurationSpan)
    case dates(start: Date, end: Date)

    func window(endingAt now: Date, calendar: Calendar = .current) -> DateInterval {
        switch self {
        case let .trailing(count, span):
            let start = span.start(count: count, before: now, calendar: calendar)
            return DateInterval(start: min(start, now), end: now)
        case let .dates(start, end):
            let from = calendar.startOfDay(for: min(start, end))
            let toDay = calendar.startOfDay(for: max(start, end))
            let nextDay = calendar.date(byAdding: .day, value: 1, to: toDay) ?? toDay
            let to = min(nextDay, max(now, from))
            return DateInterval(start: min(from, to), end: max(from, to))
        }
    }

    func previousWindow(before window: DateInterval, calendar: Calendar = .current) -> DateInterval {
        switch self {
        case .trailing:
            return self.window(endingAt: window.start, calendar: calendar)
        case .dates:
            let length = max(0, window.duration)
            return DateInterval(start: window.start.addingTimeInterval(-length), end: window.start)
        }
    }

    func isLonger(than unit: AverageUnit, endingAt now: Date, calendar: Calendar = .current) -> Bool {
        let window = window(endingAt: now, calendar: calendar)
        guard window.end > window.start else { return false }
        return window.start < unit.oneUnitBefore(window.end, calendar: calendar)
    }

    func rangeCaption(endingAt now: Date, calendar: Calendar = .current) -> String {
        switch self {
        case let .trailing(count, span):
            return "In the \(span.phrase(count: count, previous: false))"
        case let .dates(start, end):
            let from = calendar.startOfDay(for: min(start, end))
            let to = calendar.startOfDay(for: max(start, end))
            let formattedStart = from.formatted(date: .abbreviated, time: .omitted)
            let formattedEnd = to.formatted(date: .abbreviated, time: .omitted)
            return "\(formattedStart) – \(formattedEnd)"
        }
    }

    func emptyCaption(endingAt now: Date, calendar: Calendar = .current) -> String {
        switch self {
        case let .trailing(count, span):
            return "No sessions in the \(span.phrase(count: count, previous: false))."
        case .dates:
            return "No sessions from \(rangeCaption(endingAt: now, calendar: calendar))."
        }
    }

    func previousPhrase(endingAt now: Date, calendar: Calendar = .current) -> String {
        switch self {
        case let .trailing(count, span):
            return span.phrase(count: count, previous: true)
        case .dates:
            return "previous period"
        }
    }
}

enum AnalyticsRange: String, CaseIterable, Identifiable {
    case week
    case month
    case year
    case fiveYears
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week: "Week"
        case .month: "Month"
        case .year: "Year"
        case .fiveYears: "5 Years"
        case .custom: "Custom"
        }
    }

    func resolved(customStart: Date, customEnd: Date, now: Date) -> ResolvedDuration {
        switch self {
        case .week:
            return .trailing(count: 1, span: .week)
        case .month:
            return .trailing(count: 1, span: .month)
        case .year:
            return .trailing(count: 1, span: .year)
        case .fiveYears:
            return .trailing(count: 5, span: .year)
        case .custom:
            return .dates(start: customStart, end: customEnd)
        }
    }

    static func shortestPreset(
        longerThan unit: AverageUnit,
        endingAt end: Date,
        calendar: Calendar = .current
    ) -> AnalyticsRange? {
        let presets: [AnalyticsRange] = [.week, .month, .year, .fiveYears]
        return presets.first {
            $0.resolved(customStart: end, customEnd: end, now: end)
                .isLonger(than: unit, endingAt: end, calendar: calendar)
        }
    }
}

enum AverageUnit: String, CaseIterable, Identifiable {
    case day
    case week
    case month
    case year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day: "Day"
        case .week: "Week"
        case .month: "Month"
        case .year: "Year"
        }
    }

    var name: String { rawValue }

    func oneUnitBefore(_ end: Date, calendar: Calendar = .current) -> Date {
        switch self {
        case .day:
            return calendar.date(byAdding: .day, value: -1, to: end) ?? end
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: end) ?? end
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: end) ?? end
        case .year:
            return calendar.date(byAdding: .year, value: -1, to: end) ?? end
        }
    }

    var component: Calendar.Component {
        switch self {
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        case .year: .year
        }
    }

    func startDate(for date: Date, calendar: Calendar = .current) -> Date {
        switch self {
        case .day:
            return calendar.startOfDay(for: date)
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: date)?.start
                ?? calendar.startOfDay(for: date)
        case .month:
            let parts = calendar.dateComponents([.year, .month], from: date)
            return calendar.date(from: parts) ?? calendar.startOfDay(for: date)
        case .year:
            let parts = calendar.dateComponents([.year], from: date)
            return calendar.date(from: parts) ?? calendar.startOfDay(for: date)
        }
    }

    func nextDate(after date: Date, calendar: Calendar = .current) -> Date? {
        calendar.date(byAdding: component, value: 1, to: date)
    }
}

struct BucketPoint: Identifiable {
    var start: Date
    var hours: Double
    var distractions: Double
    var id: Date { start }

    /// Distractions per hour inside this bucket. Empty buckets stay at 0 so the chart still shows every day.
    var hourlyRate: Double {
        guard hours > 0 else { return 0 }
        return distractions / hours
    }
}

struct AnalyticsSummary {
    var hours: Double
    var distractions: Double
    var hoursPerUnit: Double
    var hourlyRatePerUnit: Double
    var previousHoursPerUnit: Double
    var previousHourlyRatePerUnit: Double
    var perHour: Double?
    var points: [BucketPoint]
}

enum SessionAnalytics {
    static func pooledRate(_ sessions: [DistractionSession]) -> Double? {
        let usable = sessions.filter { $0.duration > 0 }
        let seconds = usable.reduce(0.0) { $0 + $1.duration }
        guard seconds > 0 else { return nil }
        let count = usable.reduce(0) { $0 + $1.distractionCount }
        return Double(count) / (seconds / 3600)
    }

    static func series(
        _ sessions: [DistractionSession],
        bucket: RateBucket,
        calendar: Calendar = .current
    ) -> [RatePoint] {
        let grouped = Dictionary(grouping: sessions.filter { $0.duration > 0 }) {
            bucket.startDate(for: $0.startedAt, calendar: calendar)
        }
        return grouped.keys.sorted().compactMap { start in
            guard let group = grouped[start], let rate = pooledRate(group) else { return nil }
            return RatePoint(start: start, rate: rate)
        }
    }

    static func changeDescription(points: [RatePoint], bucket: RateBucket) -> String? {
        guard points.count >= 2 else { return nil }
        let delta = points[points.count - 1].rate - points[points.count - 2].rate
        if abs(delta) < 0.05 {
            return "Same as the previous \(bucket.previousName)"
        }
        let direction = delta > 0 ? "Up" : "Down"
        return String(format: "%@ %.1f / hour from the previous %@", direction, abs(delta), bucket.previousName)
    }

    static func summary(
        _ sessions: [DistractionSession],
        duration: ResolvedDuration,
        unit: AverageUnit,
        now: Date,
        calendar: Calendar = .current
    ) -> AnalyticsSummary {
        let window = duration.window(endingAt: now, calendar: calendar)
        let previous = duration.previousWindow(before: window, calendar: calendar)
        let current = totals(sessions, in: window)
        let prior = totals(sessions, in: previous)
        let units = unitCount(in: window, unit: unit, calendar: calendar)
        let previousUnits = unitCount(in: previous, unit: unit, calendar: calendar)
        let points = buckets(sessions, in: window, unit: unit, calendar: calendar)
        let previousPoints = buckets(sessions, in: previous, unit: unit, calendar: calendar)
        return AnalyticsSummary(
            hours: current.hours,
            distractions: current.distractions,
            hoursPerUnit: units > 0 ? current.hours / units : 0,
            hourlyRatePerUnit: meanHourlyRate(points),
            previousHoursPerUnit: previousUnits > 0 ? prior.hours / previousUnits : 0,
            previousHourlyRatePerUnit: meanHourlyRate(previousPoints),
            perHour: current.hours > 0 ? current.distractions / current.hours : nil,
            points: points
        )
    }

    /// Average of each bucket's distractions-per-hour. Days with no session are left out, since they have no rate.
    private static func meanHourlyRate(_ points: [BucketPoint]) -> Double {
        let rates = points.filter { $0.hours > 0 }.map(\.hourlyRate)
        guard !rates.isEmpty else { return 0 }
        return rates.reduce(0, +) / Double(rates.count)
    }

    private static func totals(
        _ sessions: [DistractionSession],
        in window: DateInterval
    ) -> (hours: Double, distractions: Double) {
        var hours = 0.0
        var distractions = 0.0
        for session in sessions where session.duration > 0 {
            let start = max(session.startedAt, window.start)
            let end = min(session.endedAt, window.end)
            let overlap = end.timeIntervalSince(start)
            guard overlap > 0 else { continue }
            hours += overlap / 3600
            distractions += Double(session.distractionCount) * (overlap / session.duration)
        }
        return (hours, distractions)
    }

    private static func unitCount(
        in window: DateInterval,
        unit: AverageUnit,
        calendar: Calendar
    ) -> Double {
        switch unit {
        case .day:
            return fractionalDays(from: window.start, to: window.end, calendar: calendar)
        case .week:
            return fractionalDays(from: window.start, to: window.end, calendar: calendar) / 7
        case .month:
            return fractional(.month, from: window.start, to: window.end, calendar: calendar)
        case .year:
            return fractional(.year, from: window.start, to: window.end, calendar: calendar)
        }
    }

    private static func fractionalDays(from start: Date, to end: Date, calendar: Calendar) -> Double {
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        let whole = calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0
        let startLength = dayLength(startDay, calendar: calendar)
        let endLength = dayLength(endDay, calendar: calendar)
        let startFraction = startLength > 0 ? start.timeIntervalSince(startDay) / startLength : 0
        let endFraction = endLength > 0 ? end.timeIntervalSince(endDay) / endLength : 0
        return max(0, Double(whole) - startFraction + endFraction)
    }

    private static func dayLength(_ dayStart: Date, calendar: Calendar) -> TimeInterval {
        let next = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86_400)
        return next.timeIntervalSince(dayStart)
    }

    private static func fractional(
        _ component: Calendar.Component,
        from start: Date,
        to end: Date,
        calendar: Calendar
    ) -> Double {
        let whole = calendar.dateComponents([component], from: start, to: end).value(for: component) ?? 0
        guard
            let anchor = calendar.date(byAdding: component, value: whole, to: start),
            let next = calendar.date(byAdding: component, value: whole + 1, to: start)
        else {
            return Double(max(0, whole))
        }
        let span = next.timeIntervalSince(anchor)
        guard span > 0 else { return Double(max(0, whole)) }
        return max(0, Double(whole) + end.timeIntervalSince(anchor) / span)
    }

    private static func buckets(
        _ sessions: [DistractionSession],
        in window: DateInterval,
        unit: AverageUnit,
        calendar: Calendar
    ) -> [BucketPoint] {
        var points: [BucketPoint] = []
        var cursor = unit.startDate(for: window.start, calendar: calendar)
        var steps = 0
        while cursor < window.end && steps < 20_000 {
            steps += 1
            guard let next = unit.nextDate(after: cursor, calendar: calendar), next > cursor else { break }
            let slice = DateInterval(
                start: max(cursor, window.start),
                end: min(next, window.end)
            )
            let total = totals(sessions, in: slice)
            points.append(BucketPoint(start: cursor, hours: total.hours, distractions: total.distractions))
            cursor = next
        }
        return points
    }
}

@main
struct F3CounterMain {
    static func main() {
        let args = CommandLine.arguments
        if args.contains("--increment") {
            postCommand("increment")
            return
        }
        if args.contains("--reset") {
            postCommand("reset")
            return
        }
        if args.contains("--start-session") {
            postCommand("start-session")
            return
        }
        if args.contains("--end-session") {
            postCommand("end-session")
            return
        }

        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.delegate = AppDelegate.shared
        app.run()
    }

    private static func postCommand(_ command: String) {
        DistributedNotificationCenter.default().postNotificationName(
            commandNotification,
            object: command,
            userInfo: nil,
            deliverImmediately: true
        )
    }
}

@MainActor
final class CounterStore: ObservableObject {
    static let shared = CounterStore()

    @Published private(set) var count: Int
    @Published private(set) var sessionStartedAt: Date?
    @Published private(set) var sessions: [DistractionSession] = []
    @Published private(set) var launchAtLogin = false
    @Published private(set) var needsLoginApproval = false
    @Published var loginNote: String?
    @Published var hotkeyProblem: String?
    @Published private(set) var countHotKey: HotKeyCombo
    @Published private(set) var resetHotKey: HotKeyCombo
    @Published private(set) var appearanceMode: AppearanceMode = .system
    @Published private(set) var accentTheme: AccentTheme = .sage
    @Published var windowPage: AppPage = .analytics

    var onCountChange: ((Int) -> Void)?
    var onHotKeysChange: (() -> Void)?
    var onThemeChange: (() -> Void)?

    var allTimeRate: Double? {
        SessionAnalytics.pooledRate(sessions)
    }

    private let countURL: URL
    private let sessionsURL: URL
    private let openSessionURL: URL
    private let defaults = UserDefaults.standard
    private let didConfigureLoginKey = "didConfigureLogin"
    private let countHotKeyKey = "countHotKey"
    private let resetHotKeyKey = "resetHotKey"
    private let appearanceModeKey = "appearanceMode"
    private let accentThemeKey = "accentTheme"

    private init() {
        let directory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("F3Counter", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        countURL = directory.appendingPathComponent("count")
        sessionsURL = directory.appendingPathComponent("sessions.json")
        openSessionURL = directory.appendingPathComponent("open-session.json")

        if let text = try? String(contentsOf: countURL, encoding: .utf8),
           let stored = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) {
            count = max(0, stored)
        } else {
            count = max(0, defaults.integer(forKey: "count"))
        }
        sessions = Self.read([DistractionSession].self, from: sessionsURL) ?? []
        sessionStartedAt = Self.read(OpenSessionRecord.self, from: openSessionURL)?.startedAt
        countHotKey = Self.storedCombo(forKey: "countHotKey", fallback: .countDefault, defaults: defaults)
        resetHotKey = Self.storedCombo(forKey: "resetHotKey", fallback: .resetDefault, defaults: defaults)
        persistInterpretedCombo(countHotKey, forKey: countHotKeyKey)
        persistInterpretedCombo(resetHotKey, forKey: resetHotKeyKey)
        if let storedMode = defaults.string(forKey: appearanceModeKey),
           let mode = AppearanceMode(rawValue: storedMode) {
            appearanceMode = mode
        }
        if let storedAccent = defaults.string(forKey: accentThemeKey),
           let accent = AccentTheme(rawValue: storedAccent) {
            accentTheme = accent
        }

        refreshLoginStatus()
        if !defaults.bool(forKey: didConfigureLoginKey) {
            setLaunchAtLogin(true)
            if launchAtLogin || needsLoginApproval {
                defaults.set(true, forKey: didConfigureLoginKey)
            }
        }
    }

    func increment() {
        count += 1
        commit(caption: "Count")
    }

    func setCountHotKey(_ combo: HotKeyCombo) {
        countHotKey = combo
        storeCombo(combo, forKey: countHotKeyKey)
        hotkeyProblem = nil
        onHotKeysChange?()
    }

    func setResetHotKey(_ combo: HotKeyCombo) {
        resetHotKey = combo
        storeCombo(combo, forKey: resetHotKeyKey)
        hotkeyProblem = nil
        onHotKeysChange?()
    }

    func setAppearanceMode(_ mode: AppearanceMode) {
        appearanceMode = mode
        defaults.set(mode.rawValue, forKey: appearanceModeKey)
        onThemeChange?()
    }

    func setAccentTheme(_ theme: AccentTheme) {
        accentTheme = theme
        defaults.set(theme.rawValue, forKey: accentThemeKey)
    }

    private func storeCombo(_ combo: HotKeyCombo, forKey key: String) {
        guard let data = try? JSONEncoder().encode(combo) else { return }
        defaults.set(data, forKey: key)
    }

    private func persistInterpretedCombo(_ combo: HotKeyCombo, forKey key: String) {
        guard let data = defaults.data(forKey: key),
              let raw = try? JSONDecoder().decode(HotKeyCombo.self, from: data),
              raw != combo else { return }
        storeCombo(combo, forKey: key)
    }

    private static func storedCombo(forKey key: String, fallback: HotKeyCombo, defaults: UserDefaults) -> HotKeyCombo {
        guard let data = defaults.data(forKey: key),
              let combo = try? JSONDecoder().decode(HotKeyCombo.self, from: data) else {
            return fallback
        }
        return HotKeyCombo.interpreted(keyCode: combo.keyCode, modifiers: combo.modifiers)
    }

    func reset() {
        count = 0
        commit(caption: "Reset")
    }

    func startSession() {
        guard sessionStartedAt == nil else { return }
        count = 0
        commit(caption: "Start")
        let startedAt = Date()
        sessionStartedAt = startedAt
        Self.write(OpenSessionRecord(startedAt: startedAt), to: openSessionURL)
        onCountChange?(count)
    }

    func endSession() {
        guard let startedAt = sessionStartedAt else { return }
        let endedAt = Date()
        sessions.append(
            DistractionSession(
                id: UUID(),
                startedAt: startedAt,
                endedAt: endedAt,
                distractionCount: count
            )
        )
        sessions.sort { $0.startedAt < $1.startedAt }
        Self.write(sessions, to: sessionsURL)
        sessionStartedAt = nil
        try? FileManager.default.removeItem(at: openSessionURL)
        count = 0
        commit(caption: "Saved")
    }

    func trackedSessions(now: Date) -> [DistractionSession] {
        var tracked = sessions
        if let started = sessionStartedAt, now > started {
            tracked.append(
                DistractionSession(
                    id: UUID(),
                    startedAt: started,
                    endedAt: now,
                    distractionCount: count
                )
            )
        }
        return tracked
    }

    func series(for bucket: RateBucket) -> [RatePoint] {
        SessionAnalytics.series(sessions, bucket: bucket)
    }

    func changeDescription(for bucket: RateBucket) -> String? {
        SessionAnalytics.changeDescription(points: series(for: bucket), bucket: bucket)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginNote = nil
        } catch {
            loginNote = error.localizedDescription
        }
        refreshLoginStatus()
    }

    func refreshLoginStatus() {
        switch SMAppService.mainApp.status {
        case .enabled:
            launchAtLogin = true
            needsLoginApproval = false
        case .requiresApproval:
            launchAtLogin = true
            needsLoginApproval = true
            loginNote = "Allow F3 Counter in System Settings → General → Login Items."
        case .notFound:
            launchAtLogin = false
            needsLoginApproval = false
            loginNote = "Keep F3 Counter in your Applications folder."
        default:
            launchAtLogin = false
            needsLoginApproval = false
        }
    }

    private func commit(caption: String) {
        defaults.set(count, forKey: "count")
        try? String(count).write(to: countURL, atomically: true, encoding: .utf8)
        onCountChange?(count)
        HUD.shared.show(count: count, caption: caption)
    }

    private static func write<T: Encodable>(_ value: T, to url: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private static func read<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(type, from: data)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate, NSWindowDelegate {
    static let shared = AppDelegate()

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var historyWindow: NSWindow?
    private var activity: NSObjectProtocol?
    private let commandBridge = CommandBridge()
    private var hotKeyRefs: [EventHotKeyRef] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        activity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep,
            reason: "Counting F3 presses"
        )

        let store = CounterStore.shared
        store.onCountChange = { [weak self] count in
            self?.updateTitle(count)
        }
        store.onHotKeysChange = { [weak self] in
            self?.reregisterHotKeys()
        }
        store.onThemeChange = { [weak self] in
            self?.applyAppearance()
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateTitle(store.count)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        let host = NSHostingController(rootView: CounterPanel(store: store))
        host.sizingOptions = [.preferredContentSize]
        popover.contentViewController = host
        applyAppearance()

        commandBridge.onCommand = { command in
            switch command {
            case "increment":
                CounterStore.shared.increment()
            case "reset":
                CounterStore.shared.reset()
            case "start-session":
                CounterStore.shared.startSession()
            case "end-session":
                CounterStore.shared.endSession()
            default:
                break
            }
        }
        DistributedNotificationCenter.default().addObserver(
            commandBridge,
            selector: #selector(CommandBridge.handle(_:)),
            name: commandNotification,
            object: nil,
            suspensionBehavior: .deliverImmediately
        )

        registerHotKeys()
        writeStatus()
    }

    func popoverDidClose(_ notification: Notification) {
        statusItem.button?.highlight(false)
    }

    func showHistory() {
        presentWindow(page: .analytics)
    }

    func showSettings() {
        presentWindow(page: .settings)
    }

    func applyAppearance() {
        let appearance = CounterStore.shared.appearanceMode.nsAppearance
        historyWindow?.appearance = appearance
        popover.contentViewController?.view.appearance = appearance
        HUD.shared.apply(appearance)
    }

    private func presentWindow(page: AppPage) {
        CounterStore.shared.windowPage = page
        let window: NSWindow
        if let historyWindow {
            window = historyWindow
        } else {
            let host = NSHostingController(rootView: AppRoot(store: CounterStore.shared))
            let created = NSWindow(contentViewController: host)
            created.title = "F3 Counter"
            created.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            created.titlebarAppearsTransparent = true
            created.isMovableByWindowBackground = true
            created.backgroundColor = .windowBackgroundColor
            created.setContentSize(NSSize(width: 720, height: 760))
            created.isReleasedWhenClosed = false
            created.hidesOnDeactivate = false
            created.delegate = self
            created.center()
            historyWindow = created
            window = created
        }
        applyAppearance()
        popover.performClose(nil)
        statusItem.button?.highlight(false)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === historyWindow else { return }
        NSApp.setActivationPolicy(.accessory)
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
            button.highlight(false)
            return
        }
        CounterStore.shared.refreshLoginStatus()
        button.highlight(true)
        NSApp.activate()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func updateTitle(_ count: Int) {
        guard let button = statusItem?.button else { return }
        let inSession = CounterStore.shared.sessionStartedAt != nil
        button.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        button.title = "\(inSession ? "◉" : "●") \(count)"
        let state = inSession ? "Session running. " : ""
        button.setAccessibilityLabel("\(state)Counter, \(count).")
    }

    func suspendHotKeys() {
        unregisterHotKeys()
    }

    func resumeHotKeys() {
        reregisterHotKeys()
    }

    private var hotKeyHandlerInstalled = false

    private func registerHotKeys() {
        if !hotKeyHandlerInstalled {
            var spec = EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            )
            let installed = InstallEventHandler(
                GetApplicationEventTarget(),
                hotKeyHandler,
                1,
                &spec,
                nil,
                nil
            )
            guard installed == noErr else {
                CounterStore.shared.hotkeyProblem = "Could not listen for the counter key (\(installed))."
                return
            }
            hotKeyHandlerInstalled = true
        }
        reregisterHotKeys()
    }

    private func reregisterHotKeys() {
        unregisterHotKeys()
        let store = CounterStore.shared
        let countStatus = registerHotKeys(for: store.countHotKey, id: incrementHotKeyID)
        let resetStatus = registerHotKeys(for: store.resetHotKey, id: resetHotKeyID)
        var problems: [String] = []
        if countStatus != noErr {
            problems.append("Count key isn’t available (\(countStatus)).")
        }
        if resetStatus != noErr {
            problems.append("Reset key isn’t available (\(resetStatus)).")
        }
        store.hotkeyProblem = problems.isEmpty ? nil : problems.joined(separator: " ")
        hotkeyStatus = "count=\(countStatus) reset=\(resetStatus) \(store.countHotKey.label) \(store.resetHotKey.label)"
    }

    private func unregisterHotKeys() {
        for ref in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
    }

    private var hotkeyStatus = "pending"

    private func registerHotKeys(for combo: HotKeyCombo, id: UInt32) -> OSStatus {
        var failure: OSStatus = -1
        var registered = false
        for item in combo.registrationCombos {
            let status = registerHotKey(combo: item, id: id)
            if status == noErr {
                registered = true
            } else {
                failure = status
            }
        }
        return registered ? noErr : failure
    }

    private func registerHotKey(combo: HotKeyCombo, id: UInt32) -> OSStatus {
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(combo.keyCode),
            combo.modifiers,
            EventHotKeyID(signature: hotKeySignature, id: id),
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if let ref, status == noErr {
            hotKeyRefs.append(ref)
        }
        return status
    }

    private func writeStatus() {
        let directory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("F3Counter", isDirectory: true)
        let url = directory.appendingPathComponent("status.txt")
        let store = CounterStore.shared
        let problem = store.hotkeyProblem ?? "ok"
        let rate = store.allTimeRate.map { String(format: "%.4f", $0) } ?? "none"
        let session = store.sessionStartedAt == nil ? "none" : "open"
        let change = store.changeDescription(for: .day) ?? "none"
        try? """
        hotkeys: \(problem)
        \(hotkeyStatus)
        count: \(store.count)
        session: \(session)
        all-time: \(rate)
        day-change: \(change)
        """.write(
            to: url,
            atomically: true,
            encoding: .utf8
        )
    }
}

private final class CommandBridge: NSObject {
    var onCommand: ((String) -> Void)?

    @objc func handle(_ notification: Notification) {
        guard let command = notification.object as? String else { return }
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                self?.onCommand?(command)
            }
        }
    }
}

private func hotKeyHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event else { return noErr }
    var hotKeyID = EventHotKeyID()
    let status = withUnsafeMutablePointer(to: &hotKeyID) { pointer in
        GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            pointer
        )
    }
    guard status == noErr else { return status }
    let action = hotKeyID.id
    DispatchQueue.main.async {
        MainActor.assumeIsolated {
            switch action {
            case incrementHotKeyID:
                CounterStore.shared.increment()
            case resetHotKeyID:
                CounterStore.shared.reset()
            default:
                break
            }
        }
    }
    return noErr
}

@MainActor
final class HUD {
    static let shared = HUD()

    private let panel: NSPanel
    private let numberLabel = NSTextField(labelWithString: "0")
    private let captionLabel = NSTextField(labelWithString: "")
    private var generation = 0

    private init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 210, height: 118),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isMovable = false

        let effect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 210, height: 118))
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 22
        effect.layer?.masksToBounds = true
        effect.autoresizingMask = [.width, .height]
        panel.contentView = effect

        numberLabel.font = roundedFont(size: 52, weight: .semibold)
        numberLabel.alignment = .center
        numberLabel.textColor = .labelColor
        numberLabel.translatesAutoresizingMaskIntoConstraints = false
        numberLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        captionLabel.font = .systemFont(ofSize: 13, weight: .medium)
        captionLabel.alignment = .center
        captionLabel.textColor = .secondaryLabelColor
        captionLabel.translatesAutoresizingMaskIntoConstraints = false

        effect.addSubview(numberLabel)
        effect.addSubview(captionLabel)
        NSLayoutConstraint.activate([
            numberLabel.topAnchor.constraint(equalTo: effect.topAnchor, constant: 14),
            numberLabel.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 24),
            numberLabel.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -24),
            captionLabel.topAnchor.constraint(equalTo: numberLabel.bottomAnchor, constant: -2),
            captionLabel.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 16),
            captionLabel.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -16),
            captionLabel.bottomAnchor.constraint(equalTo: effect.bottomAnchor, constant: -14),
        ])
    }

    func apply(_ appearance: NSAppearance?) {
        panel.appearance = appearance
    }

    func show(count: Int, caption: String) {
        generation += 1
        let token = generation
        numberLabel.stringValue = "\(count)"
        captionLabel.stringValue = caption
        numberLabel.font = roundedFont(size: count > 999 ? 40 : 52, weight: .semibold)

        let screen = NSScreen.main ?? NSScreen.screens.first
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let width: CGFloat = count > 999 ? 240 : 200
        let height: CGFloat = 116
        let origin = NSPoint(
            x: visible.midX - width / 2,
            y: visible.maxY - height - 28
        )
        panel.setFrame(NSRect(origin: origin, size: NSSize(width: width, height: height)), display: true)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.generation == token else { return }
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.18
                    self.panel.animator().alphaValue = 0
                } completionHandler: {
                    DispatchQueue.main.async {
                        MainActor.assumeIsolated {
                            HUD.shared.orderOutIfCurrent(token)
                        }
                    }
                }
            }
        }
    }

    private func orderOutIfCurrent(_ token: Int) {
        guard generation == token else { return }
        panel.orderOut(nil)
    }
}

private func roundedFont(size: CGFloat, weight: NSFont.Weight) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: weight)
    guard let descriptor = base.fontDescriptor.withDesign(.rounded),
          let font = NSFont(descriptor: descriptor, size: size) else {
        return base
    }
    return font
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}

enum AccentTheme: String, CaseIterable, Identifiable {
    case sage
    case sea
    case clay
    case iris
    case ink

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sage: "Sage"
        case .sea: "Sea"
        case .clay: "Clay"
        case .iris: "Iris"
        case .ink: "Ink"
        }
    }

    func palette(for scheme: ColorScheme) -> AccentPalette {
        let dark = scheme == .dark
        switch self {
        case .sage:
            return dark
                ? AccentPalette(accent: rgb(0.64, 0.79, 0.73), onAccent: rgb(0.09, 0.13, 0.12))
                : AccentPalette(accent: rgb(0.20, 0.40, 0.36), onAccent: .white)
        case .sea:
            return dark
                ? AccentPalette(accent: rgb(0.55, 0.75, 0.84), onAccent: rgb(0.07, 0.12, 0.15))
                : AccentPalette(accent: rgb(0.14, 0.36, 0.46), onAccent: .white)
        case .clay:
            return dark
                ? AccentPalette(accent: rgb(0.86, 0.66, 0.50), onAccent: rgb(0.16, 0.10, 0.07))
                : AccentPalette(accent: rgb(0.52, 0.30, 0.20), onAccent: .white)
        case .iris:
            return dark
                ? AccentPalette(accent: rgb(0.73, 0.66, 0.88), onAccent: rgb(0.12, 0.10, 0.16))
                : AccentPalette(accent: rgb(0.34, 0.28, 0.52), onAccent: .white)
        case .ink:
            return dark
                ? AccentPalette(accent: rgb(0.84, 0.83, 0.80), onAccent: rgb(0.10, 0.10, 0.09))
                : AccentPalette(accent: rgb(0.18, 0.18, 0.16), onAccent: .white)
        }
    }
}

struct AccentPalette {
    var accent: Color
    var onAccent: Color
}

private func rgb(_ red: Double, _ green: Double, _ blue: Double) -> Color {
    Color(.sRGB, red: red, green: green, blue: blue, opacity: 1)
}

private struct AccentThemeKey: EnvironmentKey {
    static let defaultValue = AccentTheme.sage
}

extension EnvironmentValues {
    var accentTheme: AccentTheme {
        get { self[AccentThemeKey.self] }
        set { self[AccentThemeKey.self] = newValue }
    }
}

enum AppPage {
    case analytics
    case settings
}

private struct PointingCursor: ViewModifier {
    var enabled: Bool

    func body(content: Content) -> some View {
        content.onHover { inside in
            guard enabled else { return }
            if inside {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

extension View {
    fileprivate func pointingCursor(_ enabled: Bool = true) -> some View {
        modifier(PointingCursor(enabled: enabled))
    }

    fileprivate func appTheme(mode: AppearanceMode, accent: AccentTheme) -> some View {
        environment(\.accentTheme, accent)
            .preferredColorScheme(mode.colorScheme)
    }
}

private struct CalmButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accentTheme) private var accentTheme

    func makeBody(configuration: Configuration) -> some View {
        let palette = accentTheme.palette(for: colorScheme)
        return configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(palette.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(
                palette.accent.opacity(configuration.isPressed ? 0.82 : 1),
                in: Capsule(style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .pointingCursor()
    }
}

private struct QuietChoice<Option: Hashable>: View {
    var options: [Option]
    @Binding var selection: Option
    var title: (Option) -> String
    var isEnabled: (Option) -> Bool = { _ in true }

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accentTheme) private var accentTheme

    var body: some View {
        let palette = accentTheme.palette(for: colorScheme)
        return HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                let selected = selection == option
                let enabled = isEnabled(option)
                Button {
                    selection = option
                } label: {
                    Text(title(option))
                        .font(.system(size: 12.5, weight: selected ? .semibold : .medium))
                        .foregroundStyle(selected ? palette.onAccent : Color.primary.opacity(enabled ? 0.78 : 0.28))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background {
                            if selected {
                                Capsule(style: .continuous)
                                    .fill(palette.accent)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .pointingCursor(enabled)
                .disabled(!enabled)
            }
        }
        .padding(3)
        .background(Color.primary.opacity(0.06), in: Capsule(style: .continuous))
        .animation(.easeOut(duration: 0.16), value: selection)
    }
}

private struct MetricCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            }
    }
}

struct CounterPanel: View {
    @ObservedObject var store: CounterStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accentTheme) private var accentTheme

    private var inSession: Bool { store.sessionStartedAt != nil }
    private var accent: Color { accentTheme.palette(for: colorScheme).accent }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sessionMark
                .frame(maxWidth: .infinity)

            Text("\(store.count)")
                .font(.system(size: 56, weight: .medium, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.22), value: store.count)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

            Text("distractions")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)

            sessionClock
                .padding(.top, 6)

            Button {
                if store.sessionStartedAt == nil {
                    store.startSession()
                } else {
                    store.endSession()
                }
            } label: {
                Text(inSession ? "End session" : "Start session")
            }
            .buttonStyle(CalmButtonStyle())
            .padding(.top, 10)

            Text(allTimeLabel)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
                .padding(.top, 7)

            HStack {
                Button {
                    AppDelegate.shared.showHistory()
                } label: {
                    Text("Analytics")
                        .contentShape(Rectangle())
                }
                .pointingCursor()
                Spacer()
                Button("Settings") {
                    AppDelegate.shared.showSettings()
                }
                .pointingCursor()
                Spacer()
                Button("Reset") {
                    store.reset()
                }
                .pointingCursor()
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .font(.callout)
            .padding(.top, 12)

            if let problem = store.hotkeyProblem {
                Text(problem)
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(store.countHotKey.label) counts  ·  \(store.resetHotKey.label) resets")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 8)
                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .pointingCursor()
                .buttonStyle(.plain)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .frame(width: 248)
        .appTheme(mode: store.appearanceMode, accent: store.accentTheme)
    }

    private var sessionMark: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(inSession ? accent : Color.secondary.opacity(0.4))
                .frame(width: 6, height: 6)
            Text(inSession ? "In session" : "Idle")
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(inSession ? accent : .secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule(style: .continuous)
                .fill(inSession ? accent.opacity(0.16) : Color.primary.opacity(0.05))
        )
    }

    @ViewBuilder
    private var sessionClock: some View {
        if let started = store.sessionStartedAt {
            TimelineView(.periodic(from: started, by: 1)) { context in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(elapsedString(from: started, to: context.date))
                        .font(.system(size: 20, weight: .regular, design: .rounded))
                        .monospacedDigit()
                    Text("elapsed")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var allTimeLabel: String {
        guard let rate = store.allTimeRate else { return "No all-time rate yet" }
        return String(format: "%.1f per hour, all time", rate)
    }
}

private func elapsedString(from start: Date, to end: Date) -> String {
    let total = max(0, Int(end.timeIntervalSince(start)))
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    let seconds = total % 60
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }
    return String(format: "%d:%02d", minutes, seconds)
}

private struct AnalyticsChart: View {
    var points: [BucketPoint]
    var unit: AverageUnit
    var value: KeyPath<BucketPoint, Double>
    var yLabel: String
    var title: String
    var format: (Double) -> String

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accentTheme) private var accentTheme
    @State private var hover: HoveredBar?

    var body: some View {
        MetricCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                chart
                    .frame(minHeight: 176)
            }
        }
    }

    private var chart: some View {
        let peak = points.map { $0[keyPath: value] }.max() ?? 0
        let accent = accentTheme.palette(for: colorScheme).accent
        return Chart {
            ForEach(points) { point in
                BarMark(
                    x: .value("Period", point.start, unit: unit.component),
                    y: .value(yLabel, point[keyPath: value])
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [accent, accent.opacity(0.45)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(5)
                .opacity(hover == nil || hover?.start == point.start ? 1 : 0.35)
            }
        }
        .chartYScale(domain: 0.0 ... max(1, peak * 1.15))
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.primary.opacity(0.16))
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(number.formatted(.number.precision(.fractionLength(0...1))))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(axisInk)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date, format: xAxisFormat)
                            .font(.caption)
                            .foregroundStyle(axisInk)
                    }
                }
            }
        }
        .chartPlotStyle { plot in
            plot.frame(maxWidth: .infinity, minHeight: 150)
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Color.clear
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            updateHover(at: location, proxy: proxy, geometry: geometry)
                        case .ended:
                            hover = nil
                        }
                    }
                if let hover {
                    tooltip(hover)
                        .fixedSize()
                        .position(x: hover.x, y: hover.y)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    private func updateHover(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let frame = plotFrame(proxy: proxy, geometry: geometry) else {
            hover = nil
            return
        }
        let xInPlot = location.x - frame.minX
        guard xInPlot >= 0, xInPlot <= frame.width,
              let date = proxy.value(atX: xInPlot, as: Date.self),
              let point = bucket(at: date) else {
            hover = nil
            return
        }
        let barY = frame.minY + (proxy.position(forY: point[keyPath: value]) ?? frame.midY)
        let barX = frame.minX + (proxy.position(forX: point.start) ?? xInPlot)
        let width = geometry.size.width
        hover = HoveredBar(
            start: point.start,
            text: format(point[keyPath: value]),
            when: whenLabel(point.start),
            x: min(max(barX, 44), max(44, width - 44)),
            y: max(barY - 26, 18)
        )
    }

    private var axisInk: Color { Color.primary.opacity(0.86) }

    private var xAxisFormat: Date.FormatStyle {
        switch unit {
        case .day, .week:
            return .dateTime.day().month(.abbreviated)
        case .month:
            return .dateTime.month(.abbreviated)
        case .year:
            return .dateTime.year()
        }
    }

    private func plotFrame(proxy: ChartProxy, geometry: GeometryProxy) -> CGRect? {
        guard let anchor = proxy.plotFrame else { return nil }
        return geometry[anchor]
    }

    private func bucket(at date: Date) -> BucketPoint? {
        if let index = points.lastIndex(where: { $0.start <= date }) {
            return points[index]
        }
        return points.first
    }

    private func whenLabel(_ date: Date) -> String {
        switch unit {
        case .day:
            return date.formatted(.dateTime.day().month(.abbreviated))
        case .week:
            let end = Calendar.current.date(byAdding: .day, value: 6, to: date) ?? date
            let startText = date.formatted(.dateTime.day().month(.abbreviated))
            let endText = end.formatted(.dateTime.day().month(.abbreviated))
            return "\(startText) – \(endText)"
        case .month:
            return date.formatted(.dateTime.month(.wide).year())
        case .year:
            return date.formatted(.dateTime.year())
        }
    }

    private func tooltip(_ hover: HoveredBar) -> some View {
        VStack(spacing: 1) {
            Text(hover.text)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(hover.when)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        }
    }
}

private struct HoveredBar: Equatable {
    var start: Date
    var text: String
    var when: String
    var x: CGFloat
    var y: CGFloat
}

struct AppRoot: View {
    @ObservedObject var store: CounterStore

    var body: some View {
        ZStack {
            HistoryView(store: store)
                .opacity(store.windowPage == .analytics ? 1 : 0)
                .allowsHitTesting(store.windowPage == .analytics)
                .accessibilityHidden(store.windowPage != .analytics)
            if store.windowPage == .settings {
                SettingsView(store: store)
                    .background(Color(nsColor: .windowBackgroundColor))
            }
        }
        .frame(minWidth: 680, minHeight: 520)
        .background(Color(nsColor: .windowBackgroundColor))
        .appTheme(mode: store.appearanceMode, accent: store.accentTheme)
    }
}

struct HistoryView: View {
    @ObservedObject var store: CounterStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accentTheme) private var accentTheme
    @State private var range: AnalyticsRange = .month
    @State private var unit: AverageUnit = .day
    @State private var customStart = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var customEnd = Date()

    private var accent: Color { accentTheme.palette(for: colorScheme).accent }

    private func resolvedDuration(now: Date) -> ResolvedDuration {
        range.resolved(customStart: customStart, customEnd: customEnd, now: now)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Analytics")
                    .font(.title2.weight(.medium))
                Spacer()
                Button {
                    store.windowPage = .settings
                } label: {
                    Image(systemName: "gearshape")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pointingCursor()
                .help("Settings")
            }
            .padding(.horizontal, 28)
            .padding(.top, 16)
            .padding(.bottom, 2)

            TimelineView(.periodic(from: .now, by: 30)) { context in
                analytics(now: context.date)
            }
        }
    }

    private func analytics(now: Date) -> some View {
        let duration = resolvedDuration(now: now)
        let summary = SessionAnalytics.summary(
            store.trackedSessions(now: now),
            duration: duration,
            unit: unit,
            now: now
        )
        let hasSessions = summary.hours > 0 || summary.distractions > 0
        return ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                rangePicker(now: now)
                totals(summary, duration: duration)
                unitPicker(now: now, duration: duration)

                HStack(alignment: .top, spacing: 12) {
                    averageCard(
                        eyebrow: "Hours",
                        value: formatHours(summary.hoursPerUnit),
                        detail: "per \(unit.name)",
                        change: changeLine(
                            current: summary.hoursPerUnit,
                            previous: summary.previousHoursPerUnit,
                            formatted: formatHours
                        )
                    )
                    averageCard(
                        eyebrow: "Distractions",
                        value: formatCount(summary.hourlyRatePerUnit),
                        detail: "per hour, each \(unit.name)",
                        change: changeLine(
                            current: summary.hourlyRatePerUnit,
                            previous: summary.previousHourlyRatePerUnit,
                            formatted: formatCount
                        )
                    )
                }

                if hasSessions {
                    AnalyticsChart(
                        points: summary.points,
                        unit: unit,
                        value: \.hours,
                        yLabel: "Hours",
                        title: "Hours by \(unit.name)",
                        format: formatHours
                    )
                    AnalyticsChart(
                        points: summary.points,
                        unit: unit,
                        value: \.hourlyRate,
                        yLabel: "Per hour",
                        title: "Distractions / hour by \(unit.name)",
                        format: formatCount
                    )
                } else {
                    Text(duration.emptyCaption(endingAt: now))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 160)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
    }

    private func rangePicker(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Duration")
            QuietChoice(
                options: AnalyticsRange.allCases,
                selection: $range,
                title: { $0.title },
                isEnabled: { item in
                    item == .custom || item.resolved(customStart: customStart, customEnd: customEnd, now: now).isLonger(than: unit, endingAt: now)
                }
            )
            .onChange(of: range) { _, new in
                if new == .custom {
                    ensureCustomRangeFitsUnit(now: now)
                }
                reconcileUnit(now: now)
            }

            if range == .custom {
                HStack(spacing: 16) {
                    dateField("From", selection: $customStart, range: ...max(customStart, customEnd))
                    dateField("To", selection: $customEnd, range: min(customStart, customEnd)...max(customEnd, now))
                }
                .onChange(of: customStart) { _, _ in
                    clampCustomDates(now: Date())
                }
                .onChange(of: customEnd) { _, _ in
                    clampCustomDates(now: Date())
                }
            }
        }
    }

    private func dateField(
        _ title: String,
        selection: Binding<Date>,
        range: ClosedRange<Date>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.tertiary)
            DatePicker(title, selection: selection, in: range, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.field)
                .tint(accent)
                .pointingCursor()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dateField(
        _ title: String,
        selection: Binding<Date>,
        range: PartialRangeThrough<Date>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.tertiary)
            DatePicker(title, selection: selection, in: range, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.field)
                .tint(accent)
                .pointingCursor()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func unitPicker(now: Date, duration: ResolvedDuration) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Average by")
            QuietChoice(
                options: AverageUnit.allCases,
                selection: $unit,
                title: { $0.title },
                isEnabled: { duration.isLonger(than: $0, endingAt: now) }
            )
            .onChange(of: unit) { old, new in
                let now = Date()
                guard range != .custom else {
                    if !resolvedDuration(now: now).isLonger(than: new, endingAt: now) {
                        unit = old
                    }
                    return
                }
                reconcileDuration(now: now)
            }
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption2.weight(.semibold))
            .tracking(1.1)
            .foregroundStyle(.tertiary)
    }

    private func ensureCustomRangeFitsUnit(now: Date) {
        moveCustomStart(soRangeIsLongerThan: unit, now: now)
    }

    private func clampCustomDates(now: Date) {
        if customEnd > now {
            customEnd = now
        }
        if customStart > customEnd {
            customStart = customEnd
        }
        moveCustomStart(soRangeIsLongerThan: .day, now: now)
        reconcileUnit(now: now)
    }

    private func moveCustomStart(soRangeIsLongerThan unit: AverageUnit, now: Date) {
        let calendar = Calendar.current
        let duration = AnalyticsRange.custom.resolved(customStart: customStart, customEnd: customEnd, now: now)
        guard !duration.isLonger(than: unit, endingAt: now, calendar: calendar) else { return }
        let window = duration.window(endingAt: now, calendar: calendar)
        let boundary = unit.oneUnitBefore(window.end, calendar: calendar)
        let startDay = calendar.startOfDay(for: boundary)
        let start = startDay < boundary
            ? startDay
            : (calendar.date(byAdding: .day, value: -1, to: startDay) ?? startDay)
        if customStart != start {
            customStart = start
        }
    }

    private func reconcileUnit(now: Date) {
        let duration = resolvedDuration(now: now)
        guard !duration.isLonger(than: unit, endingAt: now) else { return }
        if let fit = AverageUnit.allCases.reversed().first(where: { duration.isLonger(than: $0, endingAt: now) }) {
            unit = fit
        }
    }

    private func reconcileDuration(now: Date) {
        let duration = resolvedDuration(now: now)
        guard !duration.isLonger(than: unit, endingAt: now) else { return }
        if let preset = AnalyticsRange.shortestPreset(longerThan: unit, endingAt: now) {
            range = preset
        }
    }

    private func totals(_ summary: AnalyticsSummary, duration: ResolvedDuration) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(formatHours(summary.hours))
                    .font(.system(size: 56, weight: .medium, design: .rounded))
                    .monospacedDigit()
                Text("worked")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 4) {
                Text(duration.rangeCaption(endingAt: .now))
                    .font(.callout.weight(.medium))
                Text(rateLine(summary))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.trailing)
        }
    }

    private func rateLine(_ summary: AnalyticsSummary) -> String {
        let count = formatCount(summary.distractions)
        guard let perHour = summary.perHour else {
            return "\(count) distractions"
        }
        return "\(count) distractions · \(formatCount(perHour)) / hour overall"
    }

    private func averageCard(eyebrow: String, value: String, detail: String, change: String) -> some View {
        MetricCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(eyebrow.uppercased())
                    .font(.caption2.weight(.semibold))
                    .tracking(1.1)
                    .foregroundStyle(.tertiary)
                Text(value)
                    .font(.system(size: 32, weight: .medium, design: .rounded))
                    .monospacedDigit()
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(change)
                    .font(.caption)
                    .foregroundStyle(accent)
                    .padding(.top, 2)
            }
        }
    }

    private func changeLine(
        current: Double,
        previous: Double,
        formatted: (Double) -> String
    ) -> String {
        let delta = current - previous
        if abs(delta) < 0.05 {
            return "Same as previous"
        }
        let mark = delta > 0 ? "↑" : "↓"
        return "\(mark) \(formatted(abs(delta))) vs previous"
    }

    private func formatHours(_ value: Double) -> String {
        if abs(value) < 0.05 { return "0 h" }
        if abs(value) >= 100 { return String(format: "%.0f h", value) }
        return String(format: "%.1f h", value)
    }

    private func formatCount(_ value: Double) -> String {
        if abs(value) < 0.05 { return "0" }
        if abs(value - value.rounded()) < 0.05 || abs(value) >= 100 {
            return String(format: "%.0f", value.rounded())
        }
        return String(format: "%.1f", value)
    }

}

struct SettingsView: View {
    @ObservedObject var store: CounterStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accentTheme) private var accentTheme
    @State private var recordingShortcut: ShortcutRole?
    @StateObject private var shortcutCapture = ShortcutCapture()

    private var accent: Color { accentTheme.palette(for: colorScheme).accent }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    store.windowPage = .analytics
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.caption.weight(.bold))
                        Text("Analytics")
                            .font(.callout)
                    }
                    .foregroundStyle(.secondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pointingCursor()
                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.top, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    Text("Settings")
                        .font(.title2.weight(.medium))
                        .padding(.top, 8)

                    appearanceSetting
                    colorSetting
                    shortcutSettings
                    loginSetting
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 32)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear { store.refreshLoginStatus() }
        .onDisappear {
            if recordingShortcut != nil {
                stopShortcutRecording(resume: true)
            }
        }
    }

    private var appearanceSetting: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Appearance")
            QuietChoice(
                options: AppearanceMode.allCases,
                selection: Binding(
                    get: { store.appearanceMode },
                    set: { store.setAppearanceMode($0) }
                ),
                title: { $0.title }
            )
        }
    }

    private var colorSetting: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Color")
            HStack(spacing: 6) {
                ForEach(AccentTheme.allCases) { theme in
                    colorSwatch(theme)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            }
        }
    }

    private func colorSwatch(_ theme: AccentTheme) -> some View {
        let selected = store.accentTheme == theme
        let swatch = theme.palette(for: colorScheme).accent
        return Button {
            store.setAccentTheme(theme)
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            selected ? Color.primary.opacity(0.8) : Color.primary.opacity(0.12),
                            lineWidth: selected ? 1.5 : 1
                        )
                        .frame(width: 34, height: 34)
                    Circle()
                        .fill(swatch)
                        .frame(width: 18, height: 18)
                }
                Text(theme.title)
                    .font(.caption2.weight(selected ? .semibold : .medium))
                    .foregroundStyle(selected ? Color.primary : Color.secondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointingCursor()
    }

    private var shortcutSettings: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Shortcuts")
            VStack(alignment: .leading, spacing: 0) {
                shortcutRow("Count", role: .count, combo: store.countHotKey)
                Rectangle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(height: 1)
                    .padding(.horizontal, 16)
                shortcutRow("Reset", role: .reset, combo: store.resetHotKey)
            }
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            }

            Text("Function keys work alone. Other keys need ⌘, ⌥, or ⌃. Esc cancels.")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            if let problem = store.hotkeyProblem {
                Text(problem)
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.85))
            }
        }
    }

    private func shortcutRow(_ title: String, role: ShortcutRole, combo: HotKeyCombo) -> some View {
        let recording = recordingShortcut == role
        return HStack {
            Text(title)
                .font(.callout)
            Spacer()
            Button(recording ? "Press a key" : combo.label) {
                if recording {
                    stopShortcutRecording(resume: true)
                } else {
                    beginRecording(role)
                }
            }
            .buttonStyle(.plain)
            .pointingCursor()
            .font(.callout.weight(.medium))
            .foregroundStyle(recording ? accent : .primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(recording ? accent.opacity(0.16) : Color.primary.opacity(0.06))
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func beginRecording(_ role: ShortcutRole) {
        if recordingShortcut != nil {
            shortcutCapture.stop()
        }
        recordingShortcut = role
        store.hotkeyProblem = nil
        AppDelegate.shared.suspendHotKeys()
        shortcutCapture.onKey = { event in
            captureShortcut(event)
            return nil
        }
        shortcutCapture.start()
    }

    private func stopShortcutRecording(resume: Bool) {
        shortcutCapture.stop()
        shortcutCapture.onKey = nil
        recordingShortcut = nil
        if resume {
            AppDelegate.shared.resumeHotKeys()
        }
    }

    private func captureShortcut(_ event: NSEvent) {
        guard let role = recordingShortcut else { return }
        if event.keyCode == UInt16(kVK_Escape) {
            stopShortcutRecording(resume: true)
            return
        }
        if HotKeyCombo.modifierKeyCodes.contains(event.keyCode) {
            return
        }
        let combo = HotKeyCombo.interpreted(
            keyCode: event.keyCode,
            modifiers: carbonModifiers(from: event.modifierFlags)
        )
        guard combo.isSafe else {
            store.hotkeyProblem = "Use a function key, or add ⌘, ⌥, or ⌃."
            return
        }
        let other = role == .count ? store.resetHotKey : store.countHotKey
        guard combo != other else {
            store.hotkeyProblem = "Count and reset need different keys."
            return
        }
        stopShortcutRecording(resume: false)
        switch role {
        case .count:
            store.setCountHotKey(combo)
        case .reset:
            store.setResetHotKey(combo)
        }
    }

    private var loginSetting: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Open at login")
                    .font(.callout)
                Spacer()
                Toggle("Open at login", isOn: Binding(
                    get: { store.launchAtLogin },
                    set: { store.setLaunchAtLogin($0) }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(accent)
                .pointingCursor()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            }

            if store.needsLoginApproval {
                Button("Open Login Items Settings") {
                    SMAppService.openSystemSettingsLoginItems()
                }
                .buttonStyle(.plain)
                .pointingCursor()
                .font(.caption)
                .foregroundStyle(accent)
            }

            if let note = store.loginNote {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption2.weight(.semibold))
            .tracking(1.1)
            .foregroundStyle(.tertiary)
    }
}
