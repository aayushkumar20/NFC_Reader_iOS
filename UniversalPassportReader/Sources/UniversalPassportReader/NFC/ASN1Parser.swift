import Foundation

public struct TLVNode {
    public let tag: [UInt8]
    public let length: Int
    public let value: [UInt8]
    
    public var tagValue: UInt32 {
        var val: UInt32 = 0
        for byte in tag {
            val = (val << 8) | UInt32(byte)
        }
        return val
    }
}

public class ASN1Parser {
    
    public static func parse(bytes: [UInt8]) -> [TLVNode] {
        var nodes: [TLVNode] = []
        var index = 0
        
        while index < bytes.count {
            // Skip padding bytes (filler 0x00 or 0xFF)
            while index < bytes.count && (bytes[index] == 0x00 || bytes[index] == 0xFF) {
                index += 1
            }
            if index >= bytes.count { break }
            
            // Read Tag
            let tagStartIndex = index
            let firstTagByte = bytes[index]
            index += 1
            
            // If bits 1-5 are 1, tag is multi-byte
            if (firstTagByte & 0x1F) == 0x1F {
                while index < bytes.count {
                    let nextByte = bytes[index]
                    index += 1
                    // If MSB is 0, this is the last byte of the tag
                    if (nextByte & 0x80) == 0 {
                        break
                    }
                }
            }
            let tag = Array(bytes[tagStartIndex..<index])
            
            // Read Length
            if index >= bytes.count { break }
            let firstLenByte = bytes[index]
            index += 1
            
            var length = 0
            if (firstLenByte & 0x80) == 0 {
                // Short form length (0-127)
                length = Int(firstLenByte)
            } else {
                // Long form length
                let numLenBytes = Int(firstLenByte & 0x7F)
                if index + numLenBytes <= bytes.count {
                    for _ in 0..<numLenBytes {
                        length = (length << 8) | Int(bytes[index])
                        index += 1
                    }
                } else {
                    break
                }
            }
            
            // Read Value
            if index + length <= bytes.count {
                let value = Array(bytes[index..<(index + length)])
                index += length
                nodes.append(TLVNode(tag: tag, length: length, value: value))
            } else {
                let value = Array(bytes[index..<bytes.count])
                index = bytes.count
                nodes.append(TLVNode(tag: tag, length: value.count, value: value))
                break
            }
        }
        
        return nodes
    }
    
    public static func findNode(tag: UInt32, in nodes: [TLVNode]) -> TLVNode? {
        for node in nodes {
            if node.tagValue == tag {
                return node
            }
            // Check if tag indicates a constructed TLV (bit 6 is 1)
            if node.tag.count > 0 && (node.tag[0] & 0x20) == 0x20 {
                let children = parse(bytes: node.value)
                if let found = findNode(tag: tag, in: children) {
                    return found
                }
            }
        }
        return nil
    }
    
    public static func extractJPEGBytes(from bytes: [UInt8]) -> [UInt8]? {
        // Look for JPEG start-of-image signature (FF D8 FF)
        let jpegSignature: [UInt8] = [0xFF, 0xD8, 0xFF]
        if let idx = findSignature(jpegSignature, in: bytes) {
            return Array(bytes[idx..<bytes.count])
        }
        
        // Look for JPEG 2000 start-of-image signature (00 00 00 0C 6A 50 20 20)
        let jp2Signature: [UInt8] = [0x00, 0x00, 0x00, 0x0C, 0x6A, 0x50, 0x20, 0x20]
        if let idx = findSignature(jp2Signature, in: bytes) {
            return Array(bytes[idx..<bytes.count])
        }
        
        return nil
    }
    
    private static func findSignature(_ signature: [UInt8], in bytes: [UInt8]) -> Int? {
        guard bytes.count >= signature.count else { return nil }
        for i in 0...(bytes.count - signature.count) {
            var found = true
            for j in 0..<signature.count {
                if bytes[i + j] != signature[j] {
                    found = false
                    break
                }
            }
            if found {
                return i
            }
        }
        return nil
    }
}
