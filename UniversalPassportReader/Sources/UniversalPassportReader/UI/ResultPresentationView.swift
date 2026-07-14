import SwiftUI

public struct ResultPresentationView: View {
    let data: DocumentData
    let onDismiss: () -> Void
    
    public init(data: DocumentData, onDismiss: @escaping () -> Void) {
        self.data = data
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                Color.black.edgesIgnoringSafeArea(.all)
                
                // Abstract glow blobs
                VStack {
                    HStack {
                        Circle()
                            .fill(Color.purple.opacity(0.18))
                            .frame(width: 250, height: 250)
                            .blur(radius: 60)
                            .offset(x: -80, y: -40)
                        Spacer()
                    }
                    Spacer()
                    HStack {
                        Spacer()
                        Circle()
                            .fill(Color.cyan.opacity(0.15))
                            .frame(width: 300, height: 300)
                            .blur(radius: 70)
                            .offset(x: 100, y: 100)
                    }
                }
                .edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // Glassmorphic Digital Identity Card Preview
                        VStack(spacing: 0) {
                            
                            // Card Top Header
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(data.documentType.uppercased())
                                        .font(.system(size: 11, weight: .black, design: .rounded))
                                        .foregroundColor(.cyan)
                                        .tracking(1.5)
                                    
                                    Text(data.issuingCountry)
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                }
                                Spacer()
                                
                                // Glowing Chip Symbol
                                Image(systemName: "cpu")
                                    .font(.system(size: 24))
                                    .foregroundColor(.yellow.opacity(0.8))
                                    .shadow(color: .yellow, radius: 4)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.04))
                            
                            Divider().background(Color.white.opacity(0.08))
                            
                            // Card Body (Photo & Essential Info)
                            HStack(alignment: .top, spacing: 20) {
                                
                                // Face photo frame
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.05))
                                        .frame(width: 105, height: 135)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(
                                                    LinearGradient(colors: [Color.cyan.opacity(0.6), Color.purple.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                                    lineWidth: 1.5
                                                )
                                        )
                                    
                                    if let face = data.faceImage {
                                        Image(uiImage: face)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 105, height: 135)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                    } else {
                                        Image(systemName: "person.crop.square.fill")
                                            .font(.system(size: 60))
                                            .foregroundColor(.white.opacity(0.2))
                                    }
                                }
                                .shadow(color: Color.black.opacity(0.3), radius: 6)
                                
                                // Primary fields
                                VStack(alignment: .leading, spacing: 14) {
                                    FieldItem(label: "LAST NAME", value: data.lastName, isBold: true)
                                    FieldItem(label: "FIRST NAME", value: data.firstName, isBold: true)
                                    
                                    HStack(spacing: 24) {
                                        FieldItem(label: "DOCUMENT NO", value: data.documentNumber)
                                        FieldItem(label: "SEX", value: data.gender)
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding(.all, 20)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.03))
                                .background(VisualEffectBlur(style: .systemUltraThinMaterialDark))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 16)
                        .shadow(color: Color.black.opacity(0.4), radius: 16, y: 8)
                        
                        // Verification Status Widgets
                        HStack(spacing: 12) {
                            StatusWidget(title: "NFC Chip BAC", status: data.isBACAuthenticated ? "PASSED" : "FAILED", systemName: "checkmark.shield.fill", color: .cyan)
                            StatusWidget(title: "Passive Auth", status: data.isPassiveAuthenticated ? "VERIFIED" : "UNVERIFIED", systemName: "signature", color: .purple)
                        }
                        .padding(.horizontal, 16)
                        
                        // Detailed Document Meta Properties List
                        VStack(spacing: 0) {
                            HStack {
                                Text("Document Properties")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.4))
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            
                            VStack(spacing: 16) {
                                InfoRow(label: "Issuing Country Code", value: data.issuingCountry)
                                InfoRow(label: "Nationality Code", value: data.nationality)
                                InfoRow(label: "Date of Birth", value: formatDate(data.dateOfBirth))
                                InfoRow(label: "Date of Expiry", value: formatDate(data.expiryDate))
                                if let personalNum = data.personalNumber {
                                    InfoRow(label: "Personal Identifier", value: personalNum)
                                }
                            }
                            .padding(.all, 20)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.02))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                                    )
                            )
                            .padding(.horizontal, 16)
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.vertical, 16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Scanned Credentials")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: onDismiss) {
                        Text("Done")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.cyan)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "N/A" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

private struct FieldItem: View {
    let label: String
    let value: String
    var isBold: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.4))
                .tracking(0.5)
            
            Text(value.isEmpty ? "N/A" : value)
                .font(.system(size: isBold ? 17 : 15, weight: isBold ? .bold : .medium, design: .rounded))
                .foregroundColor(.white)
        }
    }
}

private struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
        }
    }
}

private struct StatusWidget: View {
    let title: String
    let status: String
    let systemName: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 36, height: 36)
                
                Image(systemName: systemName)
                    .font(.system(size: 16))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                
                Text(status)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(color)
            }
            Spacer()
        }
        .padding(.all, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}
