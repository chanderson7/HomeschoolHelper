import SwiftUI

struct SplashScreenView: View {
    @State private var sunGlowPulse = false
    @State private var logoBloom = false
    @State private var textFade = false

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Hero Logo Section with Sun Glow Animation
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.orange.opacity(sunGlowPulse ? 0.28 : 0.12),
                                    Color.yellow.opacity(sunGlowPulse ? 0.18 : 0.05),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 10,
                                endRadius: 110
                            )
                        )
                        .frame(width: 220, height: 220)
                        .scaleEffect(sunGlowPulse ? 1.12 : 0.94)
                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: sunGlowPulse)

                    Image("AppLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 220, maxHeight: 160)
                        .scaleEffect(logoBloom ? 1.0 : 0.88)
                        .opacity(logoBloom ? 1.0 : 0.0)
                        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 5)
                }

                // Typography
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "leaf.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Sage.accent)
                        Text("EZHomeschool")
                            .font(.system(size: 32, weight: .bold, design: .serif))
                            .foregroundStyle(.primary)
                    }

                    Text("A little structure. More room to learn together.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .opacity(textFade ? 1.0 : 0.0)
                .offset(y: textFade ? 0 : 8)

                Spacer()

                // Subtle Loading Status
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(Sage.accent)
                        .scaleEffect(0.85)
                    Text("Preparing your day…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 48)
                .opacity(textFade ? 1.0 : 0.0)
            }
        }
        .accessibilityIdentifier("appSplashScreen")
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                logoBloom = true
                sunGlowPulse = true
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                textFade = true
            }
        }
    }
}
