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
    
    public init(onScanCompleted: @escaping (DocumentData) -> Void, onDismiss: @escaping () -> Void) {
        self.onScanCompleted = onScanCompleted
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        ZStack {
            // Camera feed preview
            CameraPreview(session: scanner.captureSession)
                .edgesIgnoringSafeArea(.all)
            
            // HUD Overlay for camera aligner & NFC reading stages
            ScanningHUDView(
                instruction: instruction,
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
            scanner.startScanning()
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
                    scanner.startScanning()
                },
                secondaryButton: .cancel(Text("Cancel")) {
                    readerError = nil
                    onDismiss()
                }
            )
        }
    }
    
    private func setupScannerCallbacks() {
        scanner.onMRZFound = { parsedMRZ in
            triggerHapticFeedback(.success)
            
            isNFCActive = true
            nfcProgress = 0.0
            nfcStatus = "Hold device close to passport chip..."
            
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
            
            nfcReader.startReading(mrz: parsedMRZ)
        }
    }
    
    private func triggerHapticFeedback(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
}
extension PassportReaderError: Identifiable {
    public var id: String {
        return self.localizedDescription
    }
}
