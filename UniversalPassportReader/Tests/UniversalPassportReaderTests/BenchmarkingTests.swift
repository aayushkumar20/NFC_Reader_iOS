import XCTest
@testable import UniversalPassportReader

final class BenchmarkingTests: XCTestCase {
    
    // Benchmark the time it takes to derive BAC session keys (kEnc & kMac) from document parameters
    func testBACKeyDerivationPerformance() {
        let docNumber = "L898902C3"
        let birthDate = "690827"
        let expiryDate = "190223"
        
        measure {
            for _ in 0..<1000 {
                _ = PassportCrypto.deriveBACKeys(docNumber: docNumber, dob: birthDate, doe: expiryDate)
            }
        }
    }
    
    // Benchmark check digit generation algorithm performance
    func testCheckDigitCalculationPerformance() {
        let inputString = "L898902C3<<<<<<<<<<<<<<<<<<<<"
        
        measure {
            for _ in 0..<5000 {
                _ = PassportCrypto.mrzCheckDigit(inputString)
            }
        }
    }
    
    // Benchmark Retail MAC (MAC Algorithm 3) performance which is computed on each secure message payload
    func testRetailMACPerformance() {
        let testData = [UInt8](repeating: 0x5A, count: 1024) // 1KB test data
        let testKey = [UInt8](repeating: 0x01, count: 16)
        
        measure {
            for _ in 0..<100 {
                _ = PassportCrypto.mac3(testData, key: testKey)
            }
        }
    }
    
    // Benchmark Triple-DES CBC encryption performance
    func testTripleDESEncryptionPerformance() {
        let testData = [UInt8](repeating: 0xAA, count: 2048) // 2KB test data
        let testKey = [UInt8](repeating: 0x05, count: 16)
        let testIV = [UInt8](repeating: 0x00, count: 8)
        
        measure {
            for _ in 0..<100 {
                _ = PassportCrypto.encrypt3DESCBC(key: testKey, iv: testIV, data: testData)
            }
        }
    }
}
