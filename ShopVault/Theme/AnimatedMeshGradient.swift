import SwiftUI

struct AnimatedMeshGradientView: View {
    @State private var animate = false

    var body: some View {
        MeshGradient(
            width: 3, height: 3,
            points: [
                [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                [animate ? 0.0 : 0.1, 0.5], [animate ? 0.7 : 0.3, animate ? 0.6 : 0.4], [1.0, 0.5],
                [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
            ],
            colors: [
                Color(hex: "0A1118"), Color(hex: "0D1820"), Color(hex: "0A1118"),
                Color(hex: "0D1820"), Color(hex: "0A2A1F"), Color(hex: "0D1820"),
                Color(hex: "0A1118"), Color(hex: "0D1820"), Color(hex: "0A1118")
            ]
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

struct AnimatedMeshGradientLockView: View {
    @State private var animate = false

    var body: some View {
        MeshGradient(
            width: 3, height: 3,
            points: [
                [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                [animate ? 0.1 : 0.0, 0.5], [animate ? 0.6 : 0.4, animate ? 0.7 : 0.3], [1.0, 0.5],
                [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
            ],
            colors: [
                Color(hex: "0A1118"), Color(hex: "0D1A20"), Color(hex: "0A1118"),
                Color(hex: "0D1A20"), Color(hex: "003D2E"), Color(hex: "0D1A20"),
                Color(hex: "0A1118"), Color(hex: "0D1A20"), Color(hex: "0A1118")
            ]
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}
