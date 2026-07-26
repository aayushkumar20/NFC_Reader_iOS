import Foundation
print("Starting main...")

// C++ Bridged Core Declarations
@_silgen_name("core_derive_bac_keys")
func core_derive_bac_keys(_ doc_num: UnsafePointer<CChar>, _ dob: UnsafePointer<CChar>, _ doe: UnsafePointer<CChar>, _ out_enc: UnsafeMutablePointer<UInt8>, _ out_mac: UnsafeMutablePointer<UInt8>)

@_silgen_name("core_mrz_check_digit")
func core_mrz_check_digit(_ input: UnsafePointer<CChar>, _ out_digit: UnsafeMutablePointer<CChar>)

@_silgen_name("core_compute_retail_mac")
func core_compute_retail_mac(_ data: UnsafePointer<UInt8>, _ data_len: Int32, _ key: UnsafePointer<UInt8>, _ key_len: Int32, _ out_mac: UnsafeMutablePointer<UInt8>)

@_silgen_name("core_encrypt_3des_cbc")
func core_encrypt_3des_cbc(_ key: UnsafePointer<UInt8>, _ key_len: Int32, _ iv: UnsafePointer<UInt8>, _ iv_len: Int32, _ data: UnsafePointer<UInt8>, _ data_len: Int32, _ out_data: UnsafeMutablePointer<UInt8>, _ out_len: UnsafeMutablePointer<Int32>) -> Bool

func benchmark(name: String, iterations: Int, block: () -> Void) {
    let start = DispatchTime.now()
    for _ in 0..<iterations {
        block()
    }
    let end = DispatchTime.now()
    let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds
    let timeInterval = Double(nanoTime) / 1_000_000_000
    let perIteration = timeInterval / Double(iterations) * 1000 // ms
    let paddedName = name.padding(toLength: 30, withPad: " ", startingAt: 0)
    print(String(format: "│ %@ │ %10d │ %13.4f s │ %15.6f ms │", paddedName, iterations, timeInterval, perIteration))
}

print("┌────────────────────────────────────────────────────────────────────────────────────────┐")
print("│                      UniversalPassportReader Core Engine Benchmark                     │")
print("├────────────────────────────────┬────────────┬────────────────┬─────────────────────────┤")
print("│ Benchmark Operation            │ Iterations │ Total Time     │ Time/Iteration          │")
print("├────────────────────────────────┼────────────┼────────────────┼─────────────────────────┤")

// 1. BAC Key Derivation
print("Running BAC...")
benchmark(name: "BAC Key Derivation (KDF)", iterations: 5000) {
    var enc = [UInt8](repeating: 0, count: 16)
    var mac = [UInt8](repeating: 0, count: 16)
    core_derive_bac_keys("L898902C3", "690827", "190223", &enc, &mac)
}

// 2. MRZ Check Digit Calculation
print("Running Check Digit...")
benchmark(name: "MRZ Check Digit Calculation", iterations: 20000) {
    var outDigit = [CChar](repeating: 0, count: 16)
    core_mrz_check_digit("L898902C3<<<<<<<<<<<<<<<<<<<<", &outDigit)
}

// 3. Retail MAC Computation (1KB payload)
print("Running MAC...")
let testData = [UInt8](repeating: 0x5A, count: 1024)
let testKey = [UInt8](repeating: 0x01, count: 16)
benchmark(name: "Retail MAC Computation (1KB)", iterations: 1000) {
    var outMac = [UInt8](repeating: 0, count: 8)
    core_compute_retail_mac(testData, Int32(testData.count), testKey, Int32(testKey.count), &outMac)
}

// 4. Triple-DES CBC Encryption (2KB payload)
print("Running Encryption...")
let encryptData = [UInt8](repeating: 0xAA, count: 2048)
let encryptKey = [UInt8](repeating: 0x05, count: 16)
let encryptIV = [UInt8](repeating: 0x00, count: 8)
benchmark(name: "3DES CBC Encryption (2KB)", iterations: 1000) {
    var outData = [UInt8](repeating: 0, count: 4096)
    var outLen: Int32 = 0
    _ = core_encrypt_3des_cbc(encryptKey, Int32(encryptKey.count), encryptIV, Int32(encryptIV.count), encryptData, Int32(encryptData.count), &outData, &outLen)
}

print("└────────────────────────────────┴────────────┴────────────────┴─────────────────────────┘")
