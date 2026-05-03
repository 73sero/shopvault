import SwiftUI

struct CountUpText: View {
    let target: Double
    let duration: Double

    @State private var displayValue: Double = 0
    @State private var hasAppeared = false

    init(_ target: Decimal, duration: Double = 0.6) {
        self.target = NSDecimalNumber(decimal: target).doubleValue
        self.duration = duration
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !hasAppeared)) { timeline in
            Text(formatted(displayValue))
                .monospacedDigit()
        }
        .onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
            animateToTarget()
        }
        .onChange(of: target) { _, _ in
            animateToTarget()
        }
    }

    private func animateToTarget() {
        let start = displayValue
        let change = target - start
        let startTime = Date()

        Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { timer in
            let elapsed = Date().timeIntervalSince(startTime)
            let progress = min(elapsed / duration, 1.0)
            // ease-out curve
            let eased = 1.0 - pow(1.0 - progress, 3.0)

            DispatchQueue.main.async {
                displayValue = start + change * eased
            }

            if progress >= 1.0 {
                timer.invalidate()
                DispatchQueue.main.async {
                    displayValue = target
                }
            }
        }
    }

    private func formatted(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
}
