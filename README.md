# UniversalPassportReader iOS Framework

A premium, production-grade iOS framework built from scratch with **zero external dependencies** to read and verify NFC-enabled electronic passports (ePassports) and identity cards (eIDs) from all over the world. 

It implements the Machine Readable Travel Document (MRTD) standard defined by the **International Civil Aviation Organization (ICAO Doc 9303)**.

---

## 🏛️ Architecture Overview

The library employs a hybrid architecture, combining the portability, speed, and safety of C++ for core cryptographic and data parsing algorithms with modern Swift/SwiftUI for platform integration, camera OCR scanning, and premium haptic HUDs.

```
                  ┌──────────────────────────────┐
                  │      iOS Client App          │
                  └──────────────┬───────────────┘
                                 │ Links & Embeds
                  ┌──────────────▼───────────────┐
                  │ UniversalPassportReader.     │  SwiftUI HUD views, Camera OCR
                  │          xcframework         │  & CoreNFC tag handlers
                  └──────────────┬───────────────┘
                                 │ Swift-to-C Bridging Interface
                  ┌──────────────▼───────────────┐
                  │   UniversalPassportReader    │  High-performance C++ engine
                  │          C++ Core            │  handling BAC & ASN.1 / TLV
                  └──────────────────────────────┘
```

### 1. C++ Core Engine
Located under `UniversalPassportReader/Sources/UniversalPassportReader/`:
* **`Crypto/PassportCrypto` ([.hpp](UniversalPassportReader/Sources/UniversalPassportReader/Crypto/PassportCrypto.hpp) / [.cpp](UniversalPassportReader/Sources/UniversalPassportReader/Crypto/PassportCrypto.cpp))**:
  * **Basic Access Control (BAC)**: Key derivation function (KDF) using SHA-1 hashing of the document number, birth date, and expiry date.
  * **Mutual Authentication**: Handshake matching ICAO specifications. Uses Triple-DES CBC mode for challenge encryption and ISO 9797-1 MAC Algorithm 3 (Retail MAC) for checksum integrity.
  * **Secure Messaging**: ISO 7816-4 secure transmission wrapper keeping track of the 8-byte Send Sequence Counter (SSC).
* **`NFC/ASN1Parser` ([.hpp](UniversalPassportReader/Sources/UniversalPassportReader/NFC/ASN1Parser.hpp) / [.cpp](UniversalPassportReader/Sources/UniversalPassportReader/NFC/ASN1Parser.cpp))**:
  * **BER-TLV Parsing**: Tag-Length-Value decoder capable of reading short and long form ASN.1 structures recursively.
  * **Biometric Extractor**: Scans files for standard magic image headers (`FF D8 FF` for JPEG, and JPEG 2000 headers) to isolate raw biometric face photos.
* **`UniversalPassportReaderCore` ([.h](UniversalPassportReader/Sources/UniversalPassportReader/UniversalPassportReaderCore.h) / [.cpp](UniversalPassportReader/Sources/UniversalPassportReader/UniversalPassportReaderCore.cpp))**:
  * Provides C-linkage APIs to bridge C++ objects directly to Swift without requiring complex Objective-C++ files.

### 2. Native Swift Platform Layer
* **`MRZ/MRZScanner` & `MRZParser`**: Camera session capturing (`AVCaptureSession`) feeding frames into Apple's `Vision` API to OCR read standard machine-readable lines:
  * **TD3**: 2 lines of 44 characters (Passports & Large Cards).
  * **TD1**: 3 lines of 30 characters (Standard ID Cards).
  * **TD2**: 2 lines of 36 characters (Visas & Identity Cards).
  * *Note: The prefix check (such as strict "P" matching for TD3) has been removed to support any document prefix worldwide.*
* **`NFC/PassportNFCReader`**: Coordinates `NFCTagReaderSession` from CoreNFC, triggers BAC mutual authentication via C++ bridging, and downloads `EF.DG1` and `EF.DG2` data groups. Supports custom credentials via `PassportAuthKey`.
* **`UI Overlay`**: High-fidelity glassmorphic camera aligned boxes, haptic triggers, pulsing NFC circular loaders, and a details dashboard.

---

## 🛠️ Developer Guide & Making Changes

When updating or making modifications to the framework code, developers should follow these steps to ensure everything compiles and links correctly:

1. **Modify Source Files**: Change code in `UniversalPassportReader/Sources/UniversalPassportReader/`.
2. **Rebuild the XCFramework**: The demo app links to the packaged xcframework in the root directory. To compile your updates and refresh the xcframework, run the helper script:
   ```bash
   ./build_xcframework.sh
   ```
3. **Verify locally**: Build the client app target `PassportReaderDemo` inside Xcode.

---

## 🔐 Custom Authentication Credentials

Developers can feed custom authentication configurations using the `PassportAuthKey` enum in `PassportNFCReader`:

```swift
public enum PassportAuthKey: Hashable {
    case mrz(documentNumber: String, birthDateString: String, expiryDateString: String)
    case customHex(kEncHex: String, kMacHex: String)
    case can(String)
    case none
}
```

### Usage Options:
* **`mrz`**: Standard BAC key derivation using the document number, birth date, and expiry date strings.
* **`can`**: Derives keys from a 6-digit Card Access Number (CAN) printed on the front of ID cards.
* **`customHex`**: Supply arbitrary 16-byte raw session keys directly as hexadecimal strings (`kEnc` and `kMac`).
* **`none`**: Bypasses the mutual authentication handshake and initiates plain, unencrypted ISO-7816 file reads.

### Opening the Scanner view with Custom Keys:

```swift
import SwiftUI
import UniversalPassportReader

struct ContentView: View {
    @State private var showingScanner = false
    
    // Example: Initiate direct NFC scan with a custom CAN key
    let customKey = PassportAuthKey.can("123456")
    
    var body: some View {
        Button("Start Custom CAN Scan") {
            showingScanner = true
        }
        .fullScreenCover(isPresented: $showingScanner) {
            PassportScannerView(authKey: customKey, onScanCompleted: { doc in
                print("Document Scanned: \(doc.firstName)")
            }, onDismiss: {
                showingScanner = false
            })
        }
    }
}
```

---

## 🚀 GitHub Actions Continuous Integration (CI)

A build and code quality validation workflow is configured at `.github/workflows/ci.yml`. It triggers automatically on every push or pull request to `main` and `master`.

### Pipeline Stages:
1. **`lint` (Code Quality)**: Installs and runs `swiftlint` on macOS runners to scan the Swift source files for formatting, style conventions, and syntax mistakes.
2. **`build` (Compilation)**:
   - Builds the `UniversalPassportReader` Xcode project framework target.
   - Triggers `./build_xcframework.sh` to package simulator and device slices.
   - Cleans and builds the `PassportReaderDemo` client application against the generated xcframework to guarantee compilation integrity.

---

## 📱 Client App Setup & Integration

To embed the reader framework into your custom app:
1. Embed `UniversalPassportReader.xcframework` in your Xcode target.
2. Set target settings -> **Frameworks, Libraries, and Embedded Content** -> **Embed & Sign**.
3. Enable the **Near Field Communication Tag Reading** capability in signing settings.
4. Add the following keys to your project's `Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>We need camera access to OCR scan the document's MRZ details.</string>

<key>NFCReaderUsageDescription</key>
<string>We need NFC access to scan the identity chip inside the card.</string>

<key>com.apple.developer.nfc.readersession.iso7816.select-identifiers</key>
<array>
    <string>A0000002471001</string>
    <string>A0000002472001</string>
</array>
```

---

## 📜 Standard References

* **ICAO Doc 9303 Part 11**: Specifies security protocols, BAC mutual authentication handshake, KDF, and session keys derivation parameters.
* **ISO 7816-4**: Defines commands for smart card operations (`SELECT FILE`, `READ BINARY`) and standard secure messaging wrappers.
* **ISO 9797-1**: Specifies message authentication check calculations (Retail MAC / MAC Algorithm 3).
