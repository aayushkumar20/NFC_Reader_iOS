import SwiftUI

public struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    
    public init() {}
    
    public func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.clear,
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.40),
                            Color.white.opacity(0.15),
                            Color.clear
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: geo.size.width * 2)
                    .offset(x: -geo.size.width + (phase * geo.size.width * 2))
                }
            )
            .mask(content)
            .onAppear {
                withAnimation(Animation.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    public func shimmer() -> some View {
        modifier(ShimmerEffect())
    }
}
