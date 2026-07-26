import SwiftUI
import AVFoundation

public struct PassportScannerView: View {
    @StateObject private var scanner = MRZScanner()
    private let nfcReader = PassportNFCReader()
    
    @State private var instruction = "Align document's MRZ strip inside target area"
    @State private var isNFCActive = false
    @State private var nfcProgress: Double = 0.0
    @State private var nfcStatus = ""
    
    @State private var scannedDocument: DocumentData? = nil
    @State private var readerError: PassportReaderError? = nil
    
    public var onScanCompleted: (DocumentData) -> Void
    public var onDismiss: () -> Void
    private let initialAuthKey: PassportAuthKey?
    
    public init(authKey: PassportAuthKey? = nil, onScanCompleted: @escaping (DocumentData) -> Void, onDismiss: @escaping () -> Void) {
        self.initialAuthKey = authKey
        self.onScanCompleted = onScanCompleted
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        ZStack {
            if initialAuthKey == nil {
                // Camera feed preview
                CameraPreview(session: scanner.captureSession)
                    .edgesIgnoringSafeArea(.all)
            } else {
                // Pulse styling background for manual scan
                Color.black.edgesIgnoringSafeArea(.all)
                RadialGradient(
                    colors: [Color.cyan.opacity(0.15), Color.black],
                    center: .center,
                    startRadius: 20,
                    endRadius: 300
                )
                .edgesIgnoringSafeArea(.all)
            }
            
            // HUD Overlay for camera aligner & NFC reading stages
            ScanningHUDView(
                instruction: initialAuthKey == nil ? instruction : "Hold device close to chip...",
                isNFCActive: isNFCActive,
                nfcProgress: nfcProgress,
                nfcStatus: nfcStatus
            )
            
            // Header action bar
            VStack {
                HStack {
                    Button(action: {
                        scanner.stopScanning()
                        onDismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.all, 12)
                            .background(Circle().fill(Color.black.opacity(0.45)))
                    }
                    .padding(.top, 16)
                    .padding(.leading, 16)
                    
                    Spacer()
                }
                Spacer()
            }
        }
        .onAppear {
            setupScannerCallbacks()
            if let authKey = initialAuthKey {
                isNFCActive = true
                nfcProgress = 0.0
                nfcStatus = "Hold device close to passport chip..."
                #if targetEnvironment(simulator)
                mockNFCProgress()
                #else
                nfcReader.startReading(mrz: nil, authKey: authKey)
                #endif
            } else {
                scanner.startScanning()
            }
        }
        .onDisappear {
            scanner.stopScanning()
        }
        .sheet(item: Binding<DocumentData?>(
            get: { scannedDocument },
            set: { scannedDocument = $0 }
        )) { doc in
            ResultPresentationView(data: doc) {
                scannedDocument = nil
                onScanCompleted(doc)
                onDismiss()
            }
        }
        .alert(item: Binding<PassportReaderError?>(
            get: { readerError },
            set: { readerError = $0 }
        )) { err in
            Alert(
                title: Text("Scan Failed"),
                message: Text(err.localizedDescription),
                primaryButton: .default(Text("Try Again")) {
                    readerError = nil
                    isNFCActive = false
                    if let authKey = initialAuthKey {
                        isNFCActive = true
                        nfcProgress = 0.0
                        nfcStatus = "Hold device close to passport chip..."
                        nfcReader.startReading(mrz: nil, authKey: authKey)
                    } else {
                        scanner.startScanning()
                    }
                },
                secondaryButton: .cancel(Text("Cancel")) {
                    readerError = nil
                    onDismiss()
                }
            )
        }
    }
    
    private func setupScannerCallbacks() {
        nfcReader.onProgress = { status, progress in
            self.nfcStatus = status
            self.nfcProgress = progress
        }
        
        nfcReader.onCompletion = { document in
            triggerHapticFeedback(.success)
            self.scannedDocument = document
        }
        
        nfcReader.onError = { error in
            triggerHapticFeedback(.error)
            self.readerError = error
        }
        
        scanner.onMRZFound = { parsedMRZ in
            triggerHapticFeedback(.success)
            
            isNFCActive = true
            nfcProgress = 0.0
            nfcStatus = "Hold device close to passport chip..."
            
            let authKey = PassportAuthKey.mrz(
                documentNumber: parsedMRZ.documentNumber,
                birthDateString: parsedMRZ.birthDateString,
                expiryDateString: parsedMRZ.expiryDateString
            )
            nfcReader.startReading(mrz: parsedMRZ, authKey: authKey)
        }
    }
    
    private func triggerHapticFeedback(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
    
    #if targetEnvironment(simulator)
    private func mockNFCProgress() {
        var progress = 0.0
        nfcStatus = "Reading Data Group 1 (MRZ)..."
        Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { timer in
            progress += 0.08
            if progress <= 0.4 {
                self.nfcProgress = progress
                self.nfcStatus = "Reading Data Group 1 (MRZ)... \(Int(progress * 100))%"
            } else if progress <= 0.8 {
                self.nfcProgress = progress
                self.nfcStatus = "Reading Data Group 2 (Biometrics)... \(Int(progress * 100))%"
            } else if progress < 1.0 {
                self.nfcProgress = progress
                self.nfcStatus = "Verifying Passive Authentication... \(Int(progress * 100))%"
            } else {
                timer.invalidate()
                self.nfcProgress = 1.0
                self.nfcStatus = "Decryption successful!"
                
                // Show result after a brief delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    triggerHapticFeedback(.success)
                    self.scannedDocument = DocumentData(
                        documentType: "Passport",
                        documentNumber: "L898902C3",
                        issuingCountry: "IND",
                        expiryDate: Date(),
                        lastName: "SHARMA",
                        firstName: "RAHUL",
                        nationality: "IND",
                        dateOfBirth: Date(),
                        gender: "M",
                        personalNumber: nil,
                        faceImage: nil,
                        isBACAuthenticated: true,
                        isPassiveAuthenticated: true
                    )
                }
            }
        }
    }
    #endif
}
extension PassportReaderError: Identifiable {
    public var id: String {
        return self.localizedDescription
    }
}
