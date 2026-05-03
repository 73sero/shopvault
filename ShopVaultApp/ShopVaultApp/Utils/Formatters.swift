import Foundation

enum AppFormatters {
    static func currency(_ amount: Decimal, currencyCode: String, localeIdentifier: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = Locale(identifier: localeIdentifier)

        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount)"
    }

    static func mediumDate(_ date: Date, localeIdentifier: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: localeIdentifier)
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    static func monthYear(_ date: Date, localeIdentifier: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: localeIdentifier)
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter.string(from: date)
    }

    static func decimalSeparator(localeIdentifier: String) -> String {
        Locale(identifier: localeIdentifier).decimalSeparator ?? "."
    }

    static func normalizeDecimalInput(
        _ input: String,
        localeIdentifier: String,
        maxFractionDigits: Int = 2
    ) -> String {
        let separator = decimalSeparator(localeIdentifier: localeIdentifier)
        let alternateSeparator = separator == "," ? "." : ","
        let unified = input.replacingOccurrences(of: alternateSeparator, with: separator)

        var normalized = ""
        var hasSeparator = false

        for scalar in unified.unicodeScalars {
            if CharacterSet.decimalDigits.contains(scalar) {
                normalized.unicodeScalars.append(scalar)
                continue
            }

            if String(scalar) == separator, !hasSeparator {
                hasSeparator = true
                if normalized.isEmpty {
                    normalized = "0\(separator)"
                } else {
                    normalized += separator
                }
            }
        }

        guard hasSeparator,
              maxFractionDigits >= 0,
              let separatorRange = normalized.range(of: separator) else {
            return normalized
        }

        let fraction = normalized[separatorRange.upperBound...]
        if fraction.count <= maxFractionDigits {
            return normalized
        }

        let trimmedFraction = fraction.prefix(maxFractionDigits)
        return String(normalized[..<separatorRange.upperBound] + trimmedFraction)
    }

    static func decimal(from input: String, localeIdentifier: String) -> Decimal? {
        let separator = decimalSeparator(localeIdentifier: localeIdentifier)
        var normalized = normalizeDecimalInput(input, localeIdentifier: localeIdentifier)

        if normalized.hasSuffix(separator) {
            normalized.removeLast(separator.count)
        }

        guard !normalized.isEmpty else {
            return nil
        }

        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: localeIdentifier)
        formatter.numberStyle = .decimal
        formatter.generatesDecimalNumbers = true

        if let number = formatter.number(from: normalized) as? NSDecimalNumber {
            return number.decimalValue
        }

        return Decimal(string: normalized.replacingOccurrences(of: separator, with: "."))
    }
}
