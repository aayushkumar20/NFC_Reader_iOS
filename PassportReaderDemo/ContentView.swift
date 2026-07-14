import SwiftUI
import UniversalPassportReader

struct ContentView: View {
    @State private var showingScanner = false
    @State private var lastScannedDoc: DocumentData? = nil
    
    var body: some View {
        ZStack {
            // Dark elegant background
            Color.black.edgesIgnoringSafeArea(.all)
            
            // Abstract radial glow
            Circle()
                .fill(Color.cyan.opacity(0.12))
                .frame(width: 400, height: 400)
                .blur(radius: 80)
                .offset(y: -150)
            
            VStack(spacing: 28) {
                Spacer()
                
                // Welcome header
                VStack(spacing: 12) {
                    Image(systemName: "globe.badge.shield.half.filled")
                        .font(.system(size: 68))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.cyan, Color.blue, Color.purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.cyan.opacity(0.4), radius: 10)
                        .padding(.bottom, 8)
                    
                    Text("Universal NFC Reader")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Read and verify world passports & identity cards securely using ICAO 9303 standards.")
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                Spacer()
                
                // Card showing last scanned document summary if any
                if let doc = lastScannedDoc {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 16) {
                            if let face = doc.faceImage {
                                Image(uiImage: face)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 50, height: 64)
                                    .cornerRadius(6)
                            } else {
                                Image(systemName: "person.crop.square.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white.opacity(0.3))
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(doc.firstName) \(doc.lastName)")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                
                                Text("\(doc.documentType): \(doc.documentNumber)")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(.cyan)
                            }
                            Spacer()
                        }
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        HStack {
                            Label("BAC Verified", systemImage: "shield.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.cyan)
                            Spacer()
                            Text(doc.issuingCountry)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .padding(.all, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 24)
                    .transition(.opacity.combined(with: .scale))
                } else {
                    // Empty state visual placeholder
                    VStack(spacing: 8) {
                        Image(systemName: "creditcard")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.15))
                        Text("No documents scanned yet")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    .frame(height: 100)
                }
                
                Spacer()
                
                // Call to Action button
                Button(action: {
                    showingScanner = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "viewfinder.circle.fill")
                            .font(.system(size: 20, weight: .bold))
                        
                        Text("Scan Passport / ID Card")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color.cyan, Color.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: Color.cyan.opacity(0.35), radius: 12, y: 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .fullScreenCover(isPresented: $showingScanner) {
            PassportScannerView(onScanCompleted: { doc in
                withAnimation(.spring()) {
                    self.lastScannedDoc = doc
                }
            }, onDismiss: {
                showingScanner = false
            })
        }
        .preferredColorScheme(.dark)
    }
}
