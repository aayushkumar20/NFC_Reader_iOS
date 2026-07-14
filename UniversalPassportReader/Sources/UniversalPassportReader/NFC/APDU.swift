import Foundation

public struct APDUCommand {
    public let cla: UInt8
    public let ins: UInt8
    public let p1: UInt8
    public let p2: UInt8
    public let data: [UInt8]
    public let le: Int?
    
    public init(cla: UInt8, ins: UInt8, p1: UInt8, p2: UInt8, data: [UInt8] = [], le: Int? = nil) {
        self.cla = cla
        self.ins = ins
        self.p1 = p1
        self.p2 = p2
        self.data = data
        self.le = le
    }
    
    public var bytes: [UInt8] {
        var result = [cla, ins, p1, p2]
        if !data.isEmpty {
            let lc = data.count
            if lc < 256 {
                result.append(UInt8(lc))
            } else {
                result.append(0x00) // Extended length indicator
                result.append(UInt8((lc >> 8) & 0xFF))
                result.append(UInt8(lc & 0xFF))
            }
            result.append(contentsOf: data)
        }
        if let le = le {
            if le < 256 {
                result.append(UInt8(le))
            } else {
                if data.isEmpty {
                    result.append(0x00) // Extended length indicator
                }
                result.append(UInt8((le >> 8) & 0xFF))
                result.append(UInt8(le & 0xFF))
            }
        }
        return result
    }
}

public struct APDUResponse {
    public let data: [UInt8]
    public let sw1: UInt8
    public let sw2: UInt8
    
    public init(data: [UInt8], sw1: UInt8, sw2: UInt8) {
        self.data = data
        self.sw1 = sw1
        self.sw2 = sw2
    }
    
    public var isSuccess: Bool {
        return sw1 == 0x90 && sw2 == 0x00
    }
    
    public var sw: UInt16 {
        return (UInt16(sw1) << 8) | UInt16(sw2)
    }
}
