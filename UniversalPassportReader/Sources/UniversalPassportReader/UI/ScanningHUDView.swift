import SwiftUI

public struct ScanningHUDView: View {
    let instruction: String
    let isNFCActive: Bool
    let nfcProgress: Double
    let nfcStatus: String
    
    public init(
        instruction: String,
        isNFCActive: Bool = false,
        nfcProgress: Double = 0.0,
        nfcStatus: String = ""
    ) {
        self.instruction = instruction
        self.isNFCActive = isNFCActive
        self.nfcProgress = nfcProgress
        self.nfcStatus = nfcStatus
    }
    
    public var body: some View {
        ZStack {
            // Cutout view for Camera viewfinder (dim around the center card box)
            if !isNFCActive {
                Color.black.opacity(0.55)
                    .edgesIgnoringSafeArea(.all)
                    .mask(
                        ViewfinderMask()
                            .fill(style: FillStyle(eoFill: true))
                    )
                
                // Viewfinder Glowing Target Borders
                GeometryReader { geo in
                    let cardWidth = geo.size.width * 0.90
                    let cardHeight = cardWidth * 0.63 // ID-1 ratio
                    
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [Color.cyan, Color.blue, Color.purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .shadow(color: Color.cyan.opacity(0.5), radius: 8)
                        .frame(width: cardWidth, height: cardHeight)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2 - 30)
                    
                    // MRZ focus strip guide at the bottom of the card box
                    let mrzBoxHeight = cardHeight * 0.3
                    let mrzBoxY = (geo.size.height / 2 - 30) + (cardHeight / 2) - (mrzBoxHeight / 2) - 8
                    
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        .frame(width: cardWidth - 16, height: mrzBoxHeight)
                        .position(x: geo.size.width / 2, y: mrzBoxY)
                }
            } else {
                // Dim everything under NFC reading mode
                Color.black.opacity(0.8)
                    .edgesIgnoringSafeArea(.all)
                
                // Beautiful NFC Pulsing HUD Graphic
                VStack(spacing: 24) {
                    Spacer()
                    
                    // Wireless/NFC Reader Glowing Emblem
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.08), lineWidth: 4)
                            .frame(width: 140, height: 140)
                        
                        Circle()
                            .stroke(
                                LinearGradient(colors: [Color.cyan, Color.purple], startPoint: .top, endPoint: .bottom),
                                lineWidth: 2
                            )
                            .frame(width: 110, height: 110)
                            .rotationEffect(.degrees(nfcProgress * 360))
                            .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: nfcProgress)
                        
                        Image(systemName: "wave.3.right")
                            .font(.system(size: 40, weight: .semibold))
                            .foregroundColor(.cyan)
                            .rotationEffect(.degrees(-90))
                            .shadow(color: Color.cyan.opacity(0.5), radius: 6)
                            .scaleEffect(1.1)
                    }
                    
                    VStack(spacing: 12) {
                        Text(nfcStatus.isEmpty ? "Reading NFC Tag..." : nfcStatus)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        // Circular progress indicator bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 6)
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.cyan, Color.blue, Color.purple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geo.size.width * CGFloat(nfcProgress), height: 6)
                                    .shadow(color: Color.cyan.opacity(0.5), radius: 4)
                            }
                        }
                        .frame(width: 220, height: 6)
                        .padding(.top, 4)
                        
                        Text("\(Int(nfcProgress * 100))%")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 32)
                    
                    Spacer()
                }
            }
            
            // HUD Floating Info Card (Instructions)
            if !isNFCActive {
                VStack {
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Image(systemName: "doc.text.viewfinder")
                            .font(.system(size: 22))
                            .foregroundColor(.cyan)
                        
                        Text(instruction)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.4))
                            .background(
                                VisualEffectBlur(style: .systemUltraThinMaterialDark)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 60)
                }
            }
        }
    }
}

// SwiftUI cutout mask implementation
private struct ViewfinderMask: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        
        let cardWidth = rect.width * 0.90
        let cardHeight = cardWidth * 0.63
        let cardRect = CGRect(
            x: (rect.width - cardWidth) / 2,
            y: (rect.height - cardHeight) / 2 - 30,
            width: cardWidth,
            height: cardHeight
        )
        
        path.addRoundedRect(in: cardRect, cornerSize: CGSize(width: 16, height: 16))
        return path
    }
}

// Visual Effect Blur helper to support system blurs inside SPM libraries
public struct VisualEffectBlur: UIViewRepresentable {
    var style: UIBlurEffect.Style
    
    public init(style: UIBlurEffect.Style) {
        self.style = style
    }
    
    public func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    
    public func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}
