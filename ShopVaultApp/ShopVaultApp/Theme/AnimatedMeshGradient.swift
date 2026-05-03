import SwiftUI

struct AnimatedMeshGradientView: View {
    @State private var drift = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient.appBackground

                Circle()
                    .fill(Color.App.accentPrimary.opacity(0.12))
                    .frame(width: max(proxy.size.width * 0.75, 280), height: max(proxy.size.width * 0.75, 280))
                    .blur(radius: 70)
                    .offset(x: drift ? 120 : -100, y: drift ? -160 : -220)

                Circle()
                    .fill(Color.App.categoryBlue.opacity(0.1))
                    .frame(width: max(proxy.size.width * 0.64, 240), height: max(proxy.size.width * 0.64, 240))
                    .blur(radius: 65)
                    .offset(x: drift ? -140 : 130, y: drift ? 260 : 180)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 16).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
    }
}

struct AnimatedMeshGradientLockView: View {
    @State private var drift = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "0A1118"), Color(hex: "0D1A20")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(Color.App.accentSecondary.opacity(0.11))
                    .frame(width: max(proxy.size.width * 0.68, 240), height: max(proxy.size.width * 0.68, 240))
                    .blur(radius: 70)
                    .offset(x: drift ? 100 : -110, y: drift ? -210 : -160)

                Circle()
                    .fill(Color.App.accentPrimary.opacity(0.09))
                    .frame(width: max(proxy.size.width * 0.58, 210), height: max(proxy.size.width * 0.58, 210))
                    .blur(radius: 65)
                    .offset(x: drift ? -120 : 110, y: drift ? 240 : 190)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 14).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
    }
}
