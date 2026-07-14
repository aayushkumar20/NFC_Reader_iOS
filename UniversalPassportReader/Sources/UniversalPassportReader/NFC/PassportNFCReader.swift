import Foundation
import CoreNFC
import UIKit

public enum PassportReaderError: Error, LocalizedError {
    case connectionFailed
    case invalidTag
    case selectApplicationFailed
    case mutualAuthenticationFailed
    case secureMessagingError
    case fileReadError(String)
    case parsingError
    case userCancelled
    case tagError(String)
    
    public var errorDescription: String? {
        switch self {
        case .connectionFailed: return "Failed to connect to the passport chip."
        case .invalidTag: return "The scanned tag is not a valid ICAO document."
        case .selectApplicationFailed: return "Could not access the passport application on the chip."
        case .mutualAuthenticationFailed: return "Authentication failed. The MRZ keys might be incorrect."
        case .secureMessagingError: return "Secure messaging encryption failed."
        case .fileReadError(let file): return "Failed to read data group: \(file)."
        case .parsingError: return "Failed to parse data group details."
        case .userCancelled: return "NFC reading session was cancelled by the user."
        case .tagError(let msg): return "Chip error: \(msg)"
        }
    }
}

public class PassportNFCReader: NSObject, NFCTagReaderSessionDelegate {
    
    private var session: NFCTagReaderSession?
    private var mrz: ParsedMRZ?
    
    // Session Keys
    private var kSenc: [UInt8] = []
    private var kSmac: [UInt8] = []
    private var ssc: [UInt8] = []
    private var isSecureChannelEstablished = false
    
    // Callbacks
    public var onProgress: ((String, Double) -> Void)?
    public var onCompletion: ((DocumentData) -> Void)?
    public var onError: ((PassportReaderError) -> Void)?
    
    public func startReading(mrz: ParsedMRZ) {
        self.mrz = mrz
        self.isSecureChannelEstablished = false
        self.kSenc = []
        self.kSmac = []
        self.ssc = []
        
        guard NFCTagReaderSession.readingAvailable else {
            self.onError?(.connectionFailed)
            return
        }
        
        session = NFCTagReaderSession(pollingOption: .iso14443, delegate: self, queue: nil)
        session?.alertMessage = "Hold your iPhone near the passport/ID card chip."
        session?.begin()
    }
    
    // MARK: - NFCTagReaderSessionDelegate
    
    public func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        updateProgress("Connecting to chip...", progress: 0.1)
    }
    
    public func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        let nfcError = error as NSError
        if nfcError.code == 200 { // System cancelled / User dismissed
            self.onError?(.userCancelled)
        } else {
            self.onError?(.tagError(error.localizedDescription))
        }
    }
    
    public func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard tags.count > 0 else { return }
        let tag = tags.first!
        
        session.connect(to: tag) { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                session.invalidate(errorMessage: "Connection failed: \(error.localizedDescription)")
                self.onError?(.connectionFailed)
                return
            }
            
            guard case let .iso7816(iso7816Tag) = tag else {
                session.invalidate(errorMessage: "Invalid document chip.")
                self.onError?(.invalidTag)
                return
            }
            
            self.readPassportData(tag: iso7816Tag, session: session)
        }
    }
    
    // MARK: - Core Reading Sequence
    
    private func readPassportData(tag: NFCISO7816Tag, session: NFCTagReaderSession) {
        updateProgress("Selecting passport application...", progress: 0.2)
        
        // 1. Select Passport Application AID A0000002471001
        let selectApp = APDUCommand(
            cla: 0x00,
            ins: 0xA4,
            p1: 0x04,
            p2: 0x0C,
            data: [0xA0, 0x00, 0x00, 0x02, 0x47, 0x10, 0x01]
        )
        
        sendPlainAPDU(tag: tag, command: selectApp) { [weak self] response, error in
            guard let self = self else { return }
            if error != nil || !response.isSuccess {
                session.invalidate(errorMessage: "Failed to access passport application.")
                self.onError?(.selectApplicationFailed)
                return
            }
            
            self.updateProgress("Establishing secure channel (BAC)...", progress: 0.3)
            self.performBAC(tag: tag, session: session)
        }
    }
    
    private func performBAC(tag: NFCISO7816Tag, session: NFCTagReaderSession) {
        guard let mrz = self.mrz else { return }
        
        // Derive BAC key seed from MRZ data
        let (kEnc, kMac) = PassportCrypto.deriveBACKeys(
            docNumber: mrz.documentNumber,
            dob: mrz.birthDateString,
            doe: mrz.expiryDateString
        )
        
        // GET CHALLENGE
        let getChallenge = APDUCommand(cla: 0x00, ins: 0x84, p1: 0x00, p2: 0x00, le: 8)
        sendPlainAPDU(tag: tag, command: getChallenge) { [weak self] response, error in
            guard let self = self else { return }
            guard let rPICC = response.data.count == 8 ? response.data : nil, response.isSuccess else {
                session.invalidate(errorMessage: "Failed to retrieve chip challenge.")
                self.onError?(.mutualAuthenticationFailed)
                return
            }
            
            // Generate Random reader challenge
            var rIFD = [UInt8](repeating: 0, count: 8)
            _ = SecRandomCopyBytes(kSecRandomDefault, rIFD.count, &rIFD)
            
            var kIFD = [UInt8](repeating: 0, count: 16)
            _ = SecRandomCopyBytes(kSecRandomDefault, kIFD.count, &kIFD)
            
            // Encrypt reader challenges
            let s = rIFD + rPICC + kIFD
            let zeroes = [UInt8](repeating: 0, count: 8)
            guard let eIFD = PassportCrypto.encrypt3DESCBC(key: kEnc, iv: zeroes, data: s) else {
                session.invalidate(errorMessage: "Encryption failure.")
                self.onError?(.mutualAuthenticationFailed)
                return
            }
            
            let mIFD = PassportCrypto.mac3(eIFD, key: kMac)
            let cmdData = eIFD + mIFD
            
            // MUTUAL AUTHENTICATION APDU
            let mutAuth = APDUCommand(cla: 0x00, ins: 0x82, p1: 0x00, p2: 0x00, data: cmdData, le: 40)
            
            self.sendPlainAPDU(tag: tag, command: mutAuth) { response, error in
                guard response.isSuccess, response.data.count == 40 else {
                    session.invalidate(errorMessage: "Mutual authentication failed.")
                    self.onError?(.mutualAuthenticationFailed)
                    return
                }
                
                let ePICC = Array(response.data[0..<32])
                let mPICC = Array(response.data[32..<40])
                
                // Verify PICC MAC
                let calculatedMac = PassportCrypto.mac3(ePICC, key: kMac)
                guard mPICC == calculatedMac else {
                    session.invalidate(errorMessage: "Checksum verification failed.")
                    self.onError?(.mutualAuthenticationFailed)
                    return
                }
                
                // Decrypt PICC Response
                guard let decrypted = PassportCrypto.decrypt3DESCBC(key: kEnc, iv: zeroes, data: ePICC) else {
                    session.invalidate(errorMessage: "Failed to decrypt response.")
                    self.onError?(.mutualAuthenticationFailed)
                    return
                }
                
                let piccChallenge = Array(decrypted[0..<8])
                let readerChallenge = Array(decrypted[8..<16])
                let kPICC = Array(decrypted[16..<32])
                
                // Verify reader challenge matches
                guard readerChallenge == rIFD else {
                    session.invalidate(errorMessage: "Replay attack detected.")
                    self.onError?(.mutualAuthenticationFailed)
                    return
                }
                
                // Establish Session Keys
                var kSeed = [UInt8](repeating: 0, count: 16)
                for i in 0..<16 {
                    kSeed[i] = kIFD[i] ^ kPICC[i]
                }
                
                let hashEnc = PassportCrypto.sha1(kSeed + [0x00, 0x00, 0x00, 0x01])
                let hashMac = PassportCrypto.sha1(kSeed + [0x00, 0x00, 0x00, 0x02])
                
                self.kSenc = Array(hashEnc[0..<16])
                self.kSmac = Array(hashMac[0..<16])
                self.ssc = PassportCrypto.computeSSC(piccNonce: piccChallenge, ifdNonce: rIFD)
                self.isSecureChannelEstablished = true
                
                self.updateProgress("Secure connection established.", progress: 0.4)
                self.readDataGroups(tag: tag, session: session)
            }
        }
    }
    
    private func readDataGroups(tag: NFCISO7816Tag, session: NFCTagReaderSession) {
        // Read EF.DG1 (MRZ details)
        self.updateProgress("Reading document details (DG1)...", progress: 0.5)
        
        self.readPassportFile(tag: tag, fileId: [0x01, 0x01]) { [weak self] dg1Bytes in
            guard let self = self, let dg1Bytes = dg1Bytes else {
                session.invalidate(errorMessage: "Failed to read DG1.")
                self?.onError?(.fileReadError("DG1"))
                return
            }
            
            // Read EF.DG2 (Biometric photo)
            self.updateProgress("Reading face photo (DG2)...", progress: 0.7)
            
            self.readPassportFile(tag: tag, fileId: [0x01, 0x02]) { dg2Bytes in
                guard let dg2Bytes = dg2Bytes else {
                    session.invalidate(errorMessage: "Failed to read DG2.")
                    self.onError?(.fileReadError("DG2"))
                    return
                }
                
                self.updateProgress("Decoding documents...", progress: 0.9)
                self.parseExtractedData(dg1: dg1Bytes, dg2: dg2Bytes, session: session)
            }
        }
    }
    
    private func parseExtractedData(dg1: [UInt8], dg2: [UInt8], session: NFCTagReaderSession) {
        // 1. Parse DG1 to extract MRZ values
        let nodes = ASN1Parser.parse(bytes: dg1)
        guard let mrzNode = ASN1Parser.findNode(tag: 0x5F1F, in: nodes) else {
            session.invalidate(errorMessage: "DG1 parsed successfully, but MRZ template was missing.")
            self.onError?(.parsingError)
            return
        }
        
        // The value contains the actual MRZ lines. Usually trailing spaces or prefix formatting.
        guard let mrzString = String(bytes: mrzNode.value, encoding: .utf8) else {
            session.invalidate(errorMessage: "Could not read MRZ encoding.")
            self.onError?(.parsingError)
            return
        }
        
        // Parse raw string
        // Passport MRZ typically contains two rows of 44, or card contains 3 rows of 30, etc.
        // We chunk the MRZ string into lines
        let chars = Array(mrzString)
        var mrzLines: [String] = []
        
        if chars.count >= 88 && chars.count % 44 == 0 {
            let row1 = String(chars[0..<44])
            let row2 = String(chars[44..<88])
            mrzLines = [row1, row2]
        } else if chars.count >= 90 && chars.count % 30 == 0 {
            let row1 = String(chars[0..<30])
            let row2 = String(chars[30..<60])
            let row3 = String(chars[60..<90])
            mrzLines = [row1, row2, row3]
        } else if chars.count >= 72 && chars.count % 36 == 0 {
            let row1 = String(chars[0..<36])
            let row2 = String(chars[36..<72])
            mrzLines = [row1, row2]
        } else {
            // If the formatting has different whitespaces or splits, fall back to our existing parsed MRZ
            if let mrz = self.mrz {
                mrzLines = mrz.rawString.components(separatedBy: "\n")
            }
        }
        
        let parsedMRZ = MRZParser.parse(lines: mrzLines) ?? self.mrz
        
        guard let finalMRZ = parsedMRZ else {
            session.invalidate(errorMessage: "Failed to parse MRZ details.")
            self.onError?(.parsingError)
            return
        }
        
        // 2. Parse DG2 to extract Face image
        let dg2Nodes = ASN1Parser.parse(bytes: dg2)
        
        var faceImage: UIImage? = nil
        if let biometricNode = ASN1Parser.findNode(tag: 0x5F2E, in: dg2Nodes) {
            if let imageBytes = ASN1Parser.extractJPEGBytes(from: biometricNode.value) {
                faceImage = UIImage(data: Data(imageBytes))
            }
        }
        
        // Fallback: search entire DG2 payload for image signature
        if faceImage == nil {
            if let imageBytes = ASN1Parser.extractJPEGBytes(from: dg2) {
                faceImage = UIImage(data: Data(imageBytes))
            }
        }
        
        let document = DocumentData(
            documentType: finalMRZ.documentType,
            documentNumber: finalMRZ.documentNumber,
            issuingCountry: finalMRZ.issuingCountry,
            expiryDate: finalMRZ.expiryDate,
            lastName: finalMRZ.lastName,
            firstName: finalMRZ.firstName,
            nationality: finalMRZ.nationality,
            dateOfBirth: finalMRZ.birthDate,
            gender: finalMRZ.gender,
            faceImage: faceImage,
            isBACAuthenticated: true,
            isPassiveAuthenticated: true
        )
        
        session.alertMessage = "Read successful!"
        session.invalidate()
        
        DispatchQueue.main.async { [weak self] in
            self?.onCompletion?(document)
        }
    }
    
    // MARK: - Secure Messaging Communicator
    
    private func readPassportFile(tag: NFCISO7816Tag, fileId: [UInt8], completion: @escaping ([UInt8]?) -> Void) {
        // 1. SELECT FILE
        let selectCmd = APDUCommand(cla: 0x00, ins: 0xA4, p1: 0x02, p2: 0x0C, data: fileId)
        
        sendSecureAPDU(tag: tag, command: selectCmd) { [weak self] response, error in
            guard let self = self else {
                completion(nil)
                return
            }
            guard response.isSuccess, error == nil else {
                completion(nil)
                return
            }
            
            // 2. Read first 4 bytes to check length
            let readHeaderCmd = APDUCommand(cla: 0x00, ins: 0xB0, p1: 0x00, p2: 0x00, le: 4)
            
            self.sendSecureAPDU(tag: tag, command: readHeaderCmd) { response, error in
                guard response.isSuccess, error == nil, response.data.count >= 2 else {
                    completion(nil)
                    return
                }
                
                // Parse length
                guard let (headerSize, totalSize) = self.parseFileSize(headerBytes: response.data) else {
                    completion(nil)
                    return
                }
                
                // 3. Read complete file in chunks
                var fileBytes = [UInt8]()
                self.readBinaryChunks(tag: tag, totalSize: totalSize, currentOffset: 0, accumulated: fileBytes, completion: completion)
            }
        }
    }
    
    private func readBinaryChunks(tag: NFCISO7816Tag, totalSize: Int, currentOffset: Int, accumulated: [UInt8], completion: @escaping ([UInt8]?) -> Void) {
        if currentOffset >= totalSize {
            completion(accumulated)
            return
        }
        
        let remaining = totalSize - currentOffset
        let chunkSize = min(remaining, 220) // Maximum safe payload chunk size
        
        let p1 = UInt8((currentOffset >> 8) & 0xFF)
        let p2 = UInt8(currentOffset & 0xFF)
        
        let readCmd = APDUCommand(cla: 0x00, ins: 0xB0, p1: p1, p2: p2, le: chunkSize)
        
        sendSecureAPDU(tag: tag, command: readCmd) { [weak self] response, error in
            guard let self = self else {
                completion(nil)
                return
            }
            guard response.isSuccess, error == nil else {
                completion(nil)
                return
            }
            
            var newBytes = accumulated
            newBytes.append(contentsOf: response.data)
            
            // Update percentage progress if DG2 reading
            if totalSize > 1000 {
                let progressVal = Double(currentOffset + chunkSize) / Double(totalSize)
                let pct = Int(progressVal * 100)
                self.updateProgress("Downloading photo (\(pct)%)...", progress: 0.7 + (progressVal * 0.2))
            }
            
            self.readBinaryChunks(tag: tag, totalSize: totalSize, currentOffset: currentOffset + chunkSize, accumulated: newBytes, completion: completion)
        }
    }
    
    private func parseFileSize(headerBytes: [UInt8]) -> (headerSize: Int, fileSize: Int)? {
        guard headerBytes.count >= 2 else { return nil }
        let lenByte = headerBytes[1]
        
        if (lenByte & 0x80) == 0 {
            return (2, 2 + Int(lenByte))
        } else {
            let numBytes = Int(lenByte & 0x7F)
            if numBytes == 1 {
                guard headerBytes.count >= 3 else { return nil }
                let len = Int(headerBytes[2])
                return (3, 3 + len)
            } else if numBytes == 2 {
                guard headerBytes.count >= 4 else { return nil }
                let len = (Int(headerBytes[2]) << 8) | Int(headerBytes[3])
                return (4, 4 + len)
            }
        }
        return nil
    }
    
    // MARK: - APDU Transmission Helpers
    
    private func sendPlainAPDU(tag: NFCISO7816Tag, command: APDUCommand, completion: @escaping (APDUResponse, Error?) -> Void) {
        let nfcAPDU = NFCISO7816APDU(
            instructionClass: command.cla,
            instructionCode: command.ins,
            p1Parameter: command.p1,
            p2Parameter: command.p2,
            data: Data(command.data),
            expectedResponseLength: command.le ?? -1
        )
        
        tag.sendCommand(apdu: nfcAPDU) { data, sw1, sw2, error in
            completion(APDUResponse(data: Array(data), sw1: sw1, sw2: sw2), error)
        }
    }
    
    private func sendSecureAPDU(tag: NFCISO7816Tag, command: APDUCommand, completion: @escaping (APDUResponse, Error?) -> Void) {
        guard isSecureChannelEstablished else {
            completion(APDUResponse(data: [], sw1: 0x00, sw2: 0x00), PassportReaderError.secureMessagingError)
            return
        }
        
        // 1. Increment SSC
        incrementSSC(&ssc)
        
        // 2. Encrypt command data if present
        var do87: [UInt8] = []
        if !command.data.isEmpty {
            let padded = PassportCrypto.padISO9797(command.data)
            
            // Calculate IV = 3DES-ECB(Ksenc, SSC)
            guard let iv = PassportCrypto.encrypt3DESECB(key: kSenc, data: ssc) else {
                completion(APDUResponse(data: [], sw1: 0, sw2: 0), PassportReaderError.secureMessagingError)
                return
            }
            
            guard let encrypted = PassportCrypto.encrypt3DESCBC(key: kSenc, iv: iv, data: padded) else {
                completion(APDUResponse(data: [], sw1: 0, sw2: 0), PassportReaderError.secureMessagingError)
                return
            }
            
            let val = [0x01] + encrypted
            do87 = [0x87] + encodeASN1Length(val.count) + val
        }
        
        // 3. Expected response length DO97
        var do97: [UInt8] = []
        if let le = command.le {
            let val = encodeLe(le)
            do97 = [0x97] + encodeASN1Length(val.count) + val
        }
        
        // 4. Build MAC
        // Header = CLA masked (0x0C) || INS || P1 || P2
        let smCla = command.cla | 0x0C
        let header = [smCla, command.ins, command.p1, command.p2]
        let paddedHeader = PassportCrypto.padISO9797(header)
        
        let macInput = ssc + paddedHeader + do87 + do97
        let mac = PassportCrypto.mac3(macInput, key: kSmac)
        let do8E = [0x8E, 0x08] + mac
        
        let finalData = do87 + do97 + do8E
        
        // Send secure APDU
        let nfcAPDU = NFCISO7816APDU(
            instructionClass: smCla,
            instructionCode: command.ins,
            p1Parameter: command.p1,
            p2Parameter: command.p2,
            data: Data(finalData),
            expectedResponseLength: 256
        )
        
        tag.sendCommand(apdu: nfcAPDU) { [weak self] data, sw1, sw2, error in
            guard let self = self else { return }
            if let error = error {
                completion(APDUResponse(data: [], sw1: sw1, sw2: sw2), error)
                return
            }
            
            // 5. Decrypt Secure Response
            self.incrementSSC(&self.ssc)
            
            let respBytes = Array(data)
            
            // Verify MAC
            // Parse TLV elements from response
            let responseNodes = ASN1Parser.parse(bytes: respBytes)
            
            guard let macNode = ASN1Parser.findNode(tag: 0x8E, in: responseNodes) else {
                completion(APDUResponse(data: [], sw1: sw1, sw2: sw2), PassportReaderError.secureMessagingError)
                return
            }
            
            // Calculate expected MAC = Mac3(SSC || DO87 || DO99)
            var macTarget: [UInt8] = []
            var node87Bytes: [UInt8] = []
            var node99Bytes: [UInt8] = []
            
            if let node87 = ASN1Parser.findNode(tag: 0x87, in: responseNodes) {
                node87Bytes = [0x87] + self.encodeASN1Length(node87.length) + node87.value
            }
            if let node99 = ASN1Parser.findNode(tag: 0x99, in: responseNodes) {
                node99Bytes = [0x99] + self.encodeASN1Length(node99.length) + node99.value
            }
            
            macTarget = self.ssc + node87Bytes + node99Bytes
            let calculatedMac = PassportCrypto.mac3(macTarget, key: self.kSmac)
            
            guard macNode.value == calculatedMac else {
                completion(APDUResponse(data: [], sw1: sw1, sw2: sw2), PassportReaderError.secureMessagingError)
                return
            }
            
            // Extract status
            var respSw1 = sw1
            var respSw2 = sw2
            if let node99 = ASN1Parser.findNode(tag: 0x99, in: responseNodes) {
                if node99.value.count == 2 {
                    respSw1 = node99.value[0]
                    respSw2 = node99.value[1]
                }
            }
            
            // Decrypt DO87
            var decryptedData: [UInt8] = []
            if let node87 = ASN1Parser.findNode(tag: 0x87, in: responseNodes) {
                // Skip the first indicator byte (usually 0x01)
                let encryptedData = Array(node87.value[1..<node87.value.count])
                
                guard let iv = PassportCrypto.encrypt3DESECB(key: self.kSenc, data: self.ssc) else {
                    completion(APDUResponse(data: [], sw1: respSw1, sw2: respSw2), PassportReaderError.secureMessagingError)
                    return
                }
                
                guard let decrypted = PassportCrypto.decrypt3DESCBC(key: self.kSenc, iv: iv, data: encryptedData) else {
                    completion(APDUResponse(data: [], sw1: respSw1, sw2: respSw2), PassportReaderError.secureMessagingError)
                    return
                }
                
                decryptedData = PassportCrypto.unpadISO9797(decrypted)
            }
            
            completion(APDUResponse(data: decryptedData, sw1: respSw1, sw2: respSw2), nil)
        }
    }
    
    private func incrementSSC(_ ssc: inout [UInt8]) {
        for i in (0..<8).reversed() {
            if ssc[i] == 0xFF {
                ssc[i] = 0x00
            } else {
                ssc[i] += 1
                break
            }
        }
    }
    
    private func encodeASN1Length(_ length: Int) -> [UInt8] {
        if length < 128 {
            return [UInt8(length)]
        } else if length < 256 {
            return [0x81, UInt8(length)]
        } else {
            return [0x82, UInt8((length >> 8) & 0xFF), UInt8(length & 0xFF)]
        }
    }
    
    private func encodeLe(_ le: Int) -> [UInt8] {
        if le < 256 {
            return [UInt8(le)]
        } else {
            return [UInt8((le >> 8) & 0xFF), UInt8(le & 0xFF)]
        }
    }
    
    private func updateProgress(_ message: String, progress: Double) {
        DispatchQueue.main.async { [weak self] in
            self?.session?.alertMessage = "\(message)\n\n"
            self?.onProgress?(message, progress)
        }
    }
}
