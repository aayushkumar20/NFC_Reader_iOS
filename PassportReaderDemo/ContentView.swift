import SwiftUI
import UniversalPassportReader

struct ContentView: View {
    @State private var showingScanner = false
    @State private var showingAuthOptions = false
    @State private var selectedAuthKey: PassportAuthKey? = nil
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
                            Label(doc.isBACAuthenticated ? "BAC Verified" : "Direct Mode", systemImage: doc.isBACAuthenticated ? "shield.fill" : "shield.slash.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(doc.isBACAuthenticated ? .cyan : .orange)
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
                
                // Call to Action buttons
                VStack(spacing: 12) {
                    Button(action: {
                        selectedAuthKey = nil
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
                    
                    Button(action: {
                        showingAuthOptions = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "key.fill")
                                .font(.system(size: 14, weight: .bold))
                            
                            Text("Manual Keys / Custom Auth")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.cyan)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .fullScreenCover(isPresented: $showingScanner) {
            PassportScannerView(authKey: selectedAuthKey, onScanCompleted: { doc in
                withAnimation(.spring()) {
                    self.lastScannedDoc = doc
                }
            }, onDismiss: {
                showingScanner = false
            })
        }
        .sheet(isPresented: $showingAuthOptions) {
            AuthOptionsView(isPresented: $showingAuthOptions, selectedKey: $selectedAuthKey, startScanTrigger: $showingScanner)
        }
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("--auto-scan-mrz") {
                let docNum = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--doc-num=") })?.replacingOccurrences(of: "--doc-num=", with: "") ?? "A12345678"
                let birthDate = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--birth-date=") })?.replacingOccurrences(of: "--birth-date=", with: "") ?? "931012"
                let expiryDate = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--expiry-date=") })?.replacingOccurrences(of: "--expiry-date=", with: "") ?? "281012"
                
                self.selectedAuthKey = .mrz(documentNumber: docNum, birthDateString: birthDate, expiryDateString: expiryDate)
                self.showingScanner = true
            } else if ProcessInfo.processInfo.arguments.contains("--auto-show-sheet") {
                self.showingAuthOptions = true
            } else if ProcessInfo.processInfo.arguments.contains("--auto-show-success") {
                let docType = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--doc-type=") })?.replacingOccurrences(of: "--doc-type=", with: "") ?? "Passport"
                let docNum = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--doc-num=") })?.replacingOccurrences(of: "--doc-num=", with: "") ?? "A12345678"
                let country = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--country=") })?.replacingOccurrences(of: "--country=", with: "") ?? "USA"
                let lastName = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--last-name=") })?.replacingOccurrences(of: "--last-name=", with: "") ?? "DOE"
                let firstName = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--first-name=") })?.replacingOccurrences(of: "--first-name=", with: "") ?? "JOHN"
                let nationality = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--nationality=") })?.replacingOccurrences(of: "--nationality=", with: "") ?? "USA"
                let gender = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--gender=") })?.replacingOccurrences(of: "--gender=", with: "") ?? "M"
                
                self.lastScannedDoc = DocumentData(
                    documentType: docType,
                    documentNumber: docNum,
                    issuingCountry: country,
                    expiryDate: Date(),
                    lastName: lastName,
                    firstName: firstName,
                    nationality: nationality,
                    dateOfBirth: Date(),
                    gender: gender,
                    personalNumber: nil,
                    faceImage: nil,
                    isBACAuthenticated: true,
                    isPassiveAuthenticated: false
                )
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct AuthOptionsView: View {
    @Binding var isPresented: Bool
    @Binding var selectedKey: PassportAuthKey?
    @Binding var startScanTrigger: Bool
    
    @State private var authMode = 0 // 0: Manual MRZ, 1: CAN, 2: Custom Hex, 3: None/Plain
    
    // Manual MRZ fields
    @State private var documentNumber = ""
    @State private var birthDate = ""     // YYMMDD
    @State private var expiryDate = ""    // YYMMDD
    
    // CAN field
    @State private var canValue = ""
    
    // Custom Hex fields
    @State private var kEncHex = ""
    @State private var kMacHex = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                // background glow
                Circle()
                    .fill(Color.purple.opacity(0.1))
                    .frame(width: 300, height: 300)
                    .blur(radius: 60)
                    .offset(x: -100, y: -100)
                
                VStack(spacing: 20) {
                    Picker("Auth Mode", selection: $authMode) {
                        Text("Manual MRZ").tag(0)
                        Text("CAN").tag(1)
                        Text("Hex Keys").tag(2)
                        Text("No Auth").tag(3)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    .padding(.top, 16)
                    
                    ScrollView {
                        VStack(spacing: 18) {
                            if authMode == 0 {
                                // Manual MRZ Input Form
                                formSection(title: "Document MRZ parameters") {
                                    VStack(spacing: 12) {
                                        customTextField(placeholder: "Document Number", text: $documentNumber)
                                        customTextField(placeholder: "Birth Date (YYMMDD)", text: $birthDate)
                                        customTextField(placeholder: "Expiry Date (YYMMDD)", text: $expiryDate)
                                    }
                                }
                            } else if authMode == 1 {
                                // CAN Form
                                formSection(title: "Card Access Number") {
                                    customTextField(placeholder: "6-digit CAN (e.g. 123456)", text: $canValue)
                                }
                            } else if authMode == 2 {
                                // Custom Hex Form
                                formSection(title: "Custom Session Keys (Hex)") {
                                    VStack(spacing: 12) {
                                        customTextField(placeholder: "Encryption Key (kEnc, 16 bytes)", text: $kEncHex)
                                        customTextField(placeholder: "MAC Key (kMac, 16 bytes)", text: $kMacHex)
                                    }
                                }
                            } else {
                                // Plain Read Explanation
                                formSection(title: "Direct Reading") {
                                    Text("This mode bypasses Basic Access Control (BAC) and attempts to read matching document records in plain format. Some unencrypted standard identity cards allow this.")
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.6))
                                        .padding(.vertical, 8)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                    
                    // Submit button
                    Button(action: {
                        let finalKey: PassportAuthKey
                        switch authMode {
                        case 0:
                            finalKey = .mrz(documentNumber: documentNumber, birthDateString: birthDate, expiryDateString: expiryDate)
                        case 1:
                            finalKey = .can(canValue)
                        case 2:
                            finalKey = .customHex(kEncHex: kEncHex, kMacHex: kMacHex)
                        default:
                            finalKey = .none
                        }
                        
                        selectedKey = finalKey
                        isPresented = false
                        // Delay slightly to allow sheet to dismiss before opening scanner fullScreenCover
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            startScanTrigger = true
                        }
                    }) {
                        Text("Start NFC Reader")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [Color.cyan, Color.purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("NFC Credentials")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func formSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.cyan)
                .padding(.leading, 4)
            
            content()
                .padding(.all, 14)
                .background(Color.white.opacity(0.04))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        }
        .padding(.top, 10)
    }
    
    private func customTextField(placeholder: String, text: Binding<String>) -> some View {
        TextField("", text: text)
            .placeholder(when: text.wrappedValue.isEmpty) {
                Text(placeholder).foregroundColor(.white.opacity(0.35))
            }
            .font(.system(size: 14, design: .monospaced))
            .foregroundColor(.white)
            .padding(.all, 12)
            .background(Color.black.opacity(0.3))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .disableAutocorrection(true)
            .autocapitalization(.none)
    }
}

// Helper for placeholder in standard TextField
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {

        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}
