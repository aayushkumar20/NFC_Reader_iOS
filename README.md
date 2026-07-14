# UniversalPassportReader iOS Framework

A premium, production-grade iOS framework built from scratch with **zero external dependencies** to read and verify NFC-enabled electronic passports (ePassports) and identity cards (eIDs) from all over the world. 

It implements the Machine Readable Travel Document (MRTD) standard defined by the **International Civil Aviation Organization (ICAO Doc 9303)**.

---

## 🏛️ Architecture Overview

The library employs a hybrid architecture, combining the portability, speed, and safety of C++ for core cryptographic and data parsing algorithms with modern Swift/SwiftUI for platform integration, camera OCR scanning, and premium haptic huds.

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
  * **BER-TLV Parsing**: Native Tag-Length-Value decoder capable of reading short and long form ASN.1 structures recursively.
  * **Biometric Extractor**: Scans files for standard magic image headers (`FF D8 FF` for JPEG, and JPEG 2000 headers) to isolate raw biometric face photos.
* **`UniversalPassportReaderCore` ([.h](UniversalPassportReader/Sources/UniversalPassportReader/UniversalPassportReaderCore.h) / [.cpp](UniversalPassportReader/Sources/UniversalPassportReader/UniversalPassportReaderCore.cpp))**:
  * Provides C-linkage APIs to bridge C++ objects directly to Swift without requiring complex Objective-C++ files.

### 2. Native Swift Platform Layer
* **`MRZ/MRZScanner` & `MRZParser`**: Camera session capturing (`AVCaptureSession`) feeding frames into Apple's `Vision` API to OCR read standard machine-readable lines:
  * **TD3**: 2 lines of 44 characters (Passports).
  * **TD1**: 3 lines of 30 characters (ID Cards).
  * **TD2**: 2 lines of 36 characters (Visas/Cards).
* **`NFC/PassportNFCReader`**: Coordinates `NFCTagReaderSession` from CoreNFC, triggers BAC mutual authentication via the C++ bridging APIs, and downloads `EF.DG1` and `EF.DG2` data groups recursively in 220-byte pages.
* **`UI Overlay`**: High-fidelity glassmorphic camera aligned boxes, haptic triggers, pulsing NFC circular loaders, and a premium presentation details card dashboard.

---

## 🛠️ Build & Compilation

To build a fresh multi-platform `.xcframework` that supports both physical devices and simulators, run the included build script:

```bash
./build_xcframework.sh
```

This script:
1. Cleans up previous build directories.
2. Compiles a physical device framework slice for iOS (`iphoneos` target).
3. Compiles a simulator slice supporting Intel/Apple Silicon (`iphonesimulator` target).
4. Merges the slices into a single bundle: `UniversalPassportReader.xcframework`.

---

## 📱 Client App Integration

An iOS Demo App (`PassportReaderDemo`) is included to demonstrate integration:
1. Copy `UniversalPassportReader.xcframework` into your Xcode project.
2. Select target settings -> **Frameworks, Libraries, and Embedded Content** -> set to **Embed & Sign**.
3. Enable **Near Field Communication Tag Reading** capability.
4. Setup your `Info.plist` with the following configuration keys (required by iOS CoreNFC to authenticate standard travel chips):

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

### Usage Example (SwiftUI)

```swift
import SwiftUI
import UniversalPassportReader

struct ContentView: View {
    @State private var showingScanner = false
    @State private var scannedDoc: DocumentData? = nil
    
    var body: some View {
        VStack {
            if let doc = scannedDoc {
                Text("Scanned: \(doc.firstName) \(doc.lastName)")
            } else {
                Button("Start Scan") {
                    showingScanner = true
                }
            }
        }
        .fullScreenCover(isPresented: $showingScanner) {
            PassportScannerView(onScanCompleted: { doc in
                self.scannedDoc = doc
            }, onDismiss: {
                showingScanner = false
            })
        }
    }
}
```

---

## 📜 Standard References

* **ICAO Doc 9303 Part 11**: Specifies security protocols, BAC mutual authentication handshake, KDF, and session keys derivation parameters.
* **ISO 7816-4**: Defines commands for smart card operations (`SELECT FILE`, `READ BINARY`) and standard secure messaging wrappers.
* **ISO 9797-1**: Specifies message authentication check calculations (Retail MAC / MAC Algorithm 3).
