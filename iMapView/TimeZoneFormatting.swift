import Foundation

enum TimeZoneFormatting {
    static func displayName(for timeZone: TimeZone, locale: Locale = .current) -> String {
        timeZone.localizedName(for: .generic, locale: locale)
            ?? timeZone.identifier.replacingOccurrences(of: "_", with: " ")
    }

    static func time(_ date: Date, in timeZone: TimeZone, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    static func difference(from base: TimeZone, to target: TimeZone, at date: Date) -> String {
        let minutes = (target.secondsFromGMT(for: date) - base.secondsFromGMT(for: date)) / 60
        guard minutes != 0 else { return "Gleiche Zeit wie bei dir" }

        let absoluteMinutes = abs(minutes)
        let hours = absoluteMinutes / 60
        let remainder = absoluteMinutes % 60
        let amount: String
        if remainder == 0 {
            amount = "\(hours) Std."
        } else if hours == 0 {
            amount = "\(remainder) Min."
        } else {
            amount = "\(hours) Std. \(remainder) Min."
        }
        return minutes > 0 ? "\(amount) voraus" : "\(amount) zurück"
    }
}
