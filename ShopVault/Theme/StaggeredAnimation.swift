import SwiftUI

struct StaggeredAppearModifier: ViewModifier {
    let index: Int
    let delay: Double
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * delay)) {
                    appeared = true
                }
            }
    }
}

struct ShakeModifier: ViewModifier {
    var shakes: Int

    var animatableData: CGFloat {
        get { CGFloat(shakes) }
        set { shakes = Int(newValue) }
    }

    func body(content: Content) -> some View {
        content
            .offset(x: sin(CGFloat(shakes) * .pi * 2) * 8)
    }
}

extension View {
    func staggeredAppear(index: Int, delay: Double = 0.08) -> some View {
        modifier(StaggeredAppearModifier(index: index, delay: delay))
    }

    func shake(_ shakes: Int) -> some View {
        modifier(ShakeModifier(shakes: shakes))
    }
}
