import XCTest
@testable import UniversalPassportReader

final class CryptoTests: XCTestCase {
    
    func testCheckDigitCalculation() {
        // Document Number Check Digit test
        let docNum = "L898902C3"
        let expectedDocCheck = "6"
        XCTAssertEqual(PassportCrypto.mrzCheckDigit(docNum), expectedDocCheck)
        
        // Birth Date Check Digit test
        let dob = "690827"
        let expectedDobCheck = "8"
        XCTAssertEqual(PassportCrypto.mrzCheckDigit(dob), expectedDobCheck)
        
        // Expiry Date Check Digit test
        let doe = "190223"
        let expectedDoeCheck = "7"
        XCTAssertEqual(PassportCrypto.mrzCheckDigit(doe), expectedDoeCheck)
    }
    
    func testPadding() {
        let original: [UInt8] = [0x01, 0x02, 0x03]
        let padded = PassportCrypto.padISO9797(original)
        XCTAssertEqual(padded.count % 8, 0)
        XCTAssertEqual(padded[3], 0x80)
        
        let unpadded = PassportCrypto.unpadISO9797(padded)
        XCTAssertEqual(unpadded, original)
    }
    
    func testKeyDerivation() {
        // Test key derivation outputs
        let (kEnc, kMac) = PassportCrypto.deriveBACKeys(docNumber: "L898902C3", dob: "690827", doe: "190223")
        XCTAssertEqual(kEnc.count, 16)
        XCTAssertEqual(kMac.count, 16)
    }
}
