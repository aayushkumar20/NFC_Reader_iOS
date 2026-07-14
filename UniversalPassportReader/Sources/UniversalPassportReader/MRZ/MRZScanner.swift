import Foundation
import AVFoundation
import Vision
import Combine

public class MRZScanner: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published public var isSessionRunning = false
    @Published public var cameraPermissionStatus: AVAuthorizationStatus = .notDetermined
    
    public let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.universalpassportreader.sessionqueue")
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private var textRequest: VNRecognizeTextRequest?
    
    public var onMRZFound: ((ParsedMRZ) -> Void)?
    private var isProcessingFrame = false
    
    public override init() {
        super.init()
        self.cameraPermissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
        setupVisionRequest()
    }
    
    public func startScanning() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            guard !self.captureSession.isRunning else { return }
            self.setupCaptureSession()
            self.captureSession.startRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = true
            }
        }
    }
    
    public func stopScanning() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            guard self.captureSession.isRunning else { return }
            self.captureSession.stopRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = false
            }
        }
    }
    
    private func setupCaptureSession() {
        guard captureSession.inputs.isEmpty else { return }
        
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .hd1920x1080
        
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            captureSession.commitConfiguration()
            return
        }
        
        if captureSession.canAddInput(videoDeviceInput) {
            captureSession.addInput(videoDeviceInput)
        }
        
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "com.universalpassportreader.videoqueue"))
        
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
        }
        
        captureSession.commitConfiguration()
    }
    
    private func setupVisionRequest() {
        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let self = self else { return }
            defer { self.isProcessingFrame = false }
            
            if let results = request.results as? [VNRecognizedTextObservation] {
                self.processTextObservations(results)
            }
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        self.textRequest = request
    }
    
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard !isProcessingFrame else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        isProcessingFrame = true
        
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
        if let request = textRequest {
            try? requestHandler.perform([request])
        } else {
            isProcessingFrame = false
        }
    }
    
    private func processTextObservations(_ observations: [VNRecognizedTextObservation]) {
        var lines: [String] = []
        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            // Normalize spaces and basic formatting
            let text = candidate.string.replacingOccurrences(of: " ", with: "")
            lines.append(text)
        }
        
        // Filter elements that match ICAO length guidelines (30, 36, or 44 characters)
        let mrzCandidates = lines.filter { line in
            let len = line.count
            return (len == 44 || len == 30 || len == 36) && line.contains("<")
        }
        
        if mrzCandidates.isEmpty { return }
        
        // 1. Try TD3 Passport (2 lines of 44 chars)
        let td3Lines = mrzCandidates.filter { $0.count == 44 }
        if td3Lines.count >= 2 {
            for i in 0..<(td3Lines.count - 1) {
                let line1 = td3Lines[i]
                let line2 = td3Lines[i+1]
                if line1.hasPrefix("P") {
                    if let parsed = MRZParser.parse(lines: [line1, line2]) {
                        triggerMRZFound(parsed)
                        return
                    }
                }
            }
        }
        
        // 2. Try TD1 ID Card (3 lines of 30 chars)
        let td1Lines = mrzCandidates.filter { $0.count == 30 }
        if td1Lines.count >= 3 {
            for i in 0..<(td1Lines.count - 2) {
                let line1 = td1Lines[i]
                let line2 = td1Lines[i+1]
                let line3 = td1Lines[i+2]
                let prefix = String(line1.prefix(1))
                if prefix == "I" || prefix == "A" || prefix == "C" {
                    if let parsed = MRZParser.parse(lines: [line1, line2, line3]) {
                        triggerMRZFound(parsed)
                        return
                    }
                }
            }
        }
        
        // 3. Try TD2 Card/Visa (2 lines of 36 chars)
        let td2Lines = mrzCandidates.filter { $0.count == 36 }
        if td2Lines.count >= 2 {
            for i in 0..<(td2Lines.count - 1) {
                let line1 = td2Lines[i]
                let line2 = td2Lines[i+1]
                let prefix = String(line1.prefix(1))
                if prefix == "V" || prefix == "I" || prefix == "A" || prefix == "C" {
                    if let parsed = MRZParser.parse(lines: [line1, line2]) {
                        triggerMRZFound(parsed)
                        return
                    }
                }
            }
        }
    }
    
    private func triggerMRZFound(_ parsed: ParsedMRZ) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.stopScanning()
            self.onMRZFound?(parsed)
        }
    }
}
