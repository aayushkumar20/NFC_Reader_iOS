import Foundation
import CommonCrypto

public struct PassportCrypto {
    
    public static func sha1(_ data: [UInt8]) -> [UInt8] {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        _ = CC_SHA1(data, CC_LONG(data.count), &hash)
        return hash
    }
    
    public static func sha256(_ data: [UInt8]) -> [UInt8] {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        _ = CC_SHA256(data, CC_LONG(data.count), &hash)
        return hash
    }
    
    public static func padISO9797(_ data: [UInt8]) -> [UInt8] {
        var padded = data
        padded.append(0x80)
        while padded.count % 8 != 0 {
            padded.append(0x00)
        }
        return padded
    }
    
    public static func unpadISO9797(_ data: [UInt8]) -> [UInt8] {
        var index = data.count - 1
        while index >= 0 {
            if data[index] == 0x80 {
                return Array(data[0..<index])
            } else if data[index] == 0x00 {
                index -= 1
            } else {
                break
            }
        }
        return data
    }
    
    public static func padMRZString(_ input: String, length: Int) -> String {
        var str = input.uppercased().replacingOccurrences(of: " ", with: "<")
        if str.count > length {
            str = String(str.prefix(length))
        } else {
            str = str.padding(toLength: length, withPad: "<", startingAt: 0)
        }
        return str
    }
    
    // MARK: - Bridged C++ Core Cryptography Calls
    
    public static func mrzCheckDigit(_ input: String) -> String {
        var outDigit = [CChar](repeating: 0, count: 16)
        core_mrz_check_digit(input, &outDigit)
        return String(cString: outDigit)
    }
    
    public static func mac3(_ data: [UInt8], key: [UInt8]) -> [UInt8] {
        var mac = [UInt8](repeating: 0, count: 8)
        core_compute_retail_mac(data, Int32(data.count), key, Int32(key.count), &mac)
        return mac
    }
    
    public static func encrypt3DESCBC(key: [UInt8], iv: [UInt8], data: [UInt8]) -> [UInt8]? {
        var outLen: Int32 = 0
        var outData = [UInt8](repeating: 0, count: data.count + 1024)
        let ok = core_encrypt_3des_cbc(key, Int32(key.count), iv, Int32(iv.count), data, Int32(data.count), &outData, &outLen)
        guard ok else { return nil }
        return Array(outData[0..<Int(outLen)])
    }
    
    public static func decrypt3DESCBC(key: [UInt8], iv: [UInt8], data: [UInt8]) -> [UInt8]? {
        var outLen: Int32 = 0
        var outData = [UInt8](repeating: 0, count: data.count + 1024)
        let ok = core_decrypt_3des_cbc(key, Int32(key.count), iv, Int32(iv.count), data, Int32(data.count), &outData, &outLen)
        guard ok else { return nil }
        return Array(outData[0..<Int(outLen)])
    }
    
    public static func encrypt3DESECB(key: [UInt8], data: [UInt8]) -> [UInt8]? {
        var outLen: Int32 = 0
        var outData = [UInt8](repeating: 0, count: data.count + 1024)
        let ok = core_encrypt_3des_ecb(key, Int32(key.count), data, Int32(data.count), &outData, &outLen)
        guard ok else { return nil }
        return Array(outData[0..<Int(outLen)])
    }
    
    public static func deriveBACKeys(docNumber: String, dob: String, doe: String) -> (encKey: [UInt8], macKey: [UInt8]) {
        var enc = [UInt8](repeating: 0, count: 16)
        var mac = [UInt8](repeating: 0, count: 16)
        core_derive_bac_keys(docNumber, dob, doe, &enc, &mac)
        return (enc, mac)
    }
    
    public static func computeSSC(piccNonce: [UInt8], ifdNonce: [UInt8]) -> [UInt8] {
        let piccSuffix = Array(piccNonce.suffix(4))
        let ifdSuffix = Array(ifdNonce.suffix(4))
        return piccSuffix + ifdSuffix
    }
}
