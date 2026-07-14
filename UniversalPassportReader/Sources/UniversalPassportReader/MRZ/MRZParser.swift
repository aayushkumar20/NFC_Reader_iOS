import Foundation

public struct ParsedMRZ {
    public let documentType: String // "Passport", "ID Card", "Visa", or "Unknown"
    public let documentNumber: String
    public let birthDate: Date?
    public let birthDateString: String // YYMMDD
    public let expiryDate: Date?
    public let expiryDateString: String // YYMMDD
    public let firstName: String
    public let lastName: String
    public let nationality: String
    public let issuingCountry: String
    public let gender: String
    public let personalNumber: String?
    public let rawString: String
}

public class MRZParser {
    
    public static func cleanNumeric(_ input: String) -> String {
        var result = ""
        for char in input.uppercased() {
            switch char {
            case "O", "D": result.append("0")
            case "I", "L", "J": result.append("1")
            case "Z": result.append("2")
            case "S": result.append("5")
            case "B": result.append("8")
            case "G": result.append("6")
            case "T": result.append("7")
            case let c where c.isNumber: result.append(c)
            default: break // ignore or skip
            }
        }
        return result
    }
    
    public static func cleanAlpha(_ input: String) -> String {
        return input.uppercased().map { char -> String in
            switch char {
            case "0": return "O"
            case "1": return "I"
            case "2": return "Z"
            case "5": return "S"
            case "8": return "B"
            default: return String(char)
            }
        }.joined()
    }
    
    private static func parseNames(_ nameField: String) -> (lastName: String, firstName: String) {
        let components = nameField.components(separatedBy: "<<")
        let lastName = components.first?.replacingOccurrences(of: "<", with: " ").trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var firstName = ""
        if components.count > 1 {
            firstName = components[1].replacingOccurrences(of: "<", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return (lastName, firstName)
    }
    
    private static func parseDate(yyyymmdd: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.date(from: yyyymmdd)
    }
    
    public static func parseBirthDate(_ yy: String, mm: String, dd: String) -> Date? {
        guard let yearVal = Int(cleanNumeric(yy)) else { return nil }
        let currentYear = Calendar.current.component(.year, from: Date()) % 100
        let century = yearVal > currentYear ? 1900 : 2000
        let yyyy = String(format: "%04d", century + yearVal)
        return parseDate(yyyymmdd: yyyy + cleanNumeric(mm) + cleanNumeric(dd))
    }
    
    public static func parseExpiryDate(_ yy: String, mm: String, dd: String) -> Date? {
        guard let yearVal = Int(cleanNumeric(yy)) else { return nil }
        let century = yearVal < 80 ? 2000 : 1900
        let yyyy = String(format: "%04d", century + yearVal)
        return parseDate(yyyymmdd: yyyy + cleanNumeric(mm) + cleanNumeric(dd))
    }
    
    public static func parse(lines: [String]) -> ParsedMRZ? {
        let cleanLines = lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: " ", with: "") }
        
        // Try to identify format based on lines count and line lengths
        if cleanLines.count == 2 {
            let line1 = cleanLines[0]
            let line2 = cleanLines[1]
            
            if line1.count == 44 && line2.count == 44 {
                return parseTD3(line1: line1, line2: line2)
            } else if line1.count == 36 && line2.count == 36 {
                return parseTD2(line1: line1, line2: line2)
            }
        } else if cleanLines.count == 3 {
            let line1 = cleanLines[0]
            let line2 = cleanLines[1]
            let line3 = cleanLines[2]
            
            if line1.count == 30 && line2.count == 30 && line3.count == 30 {
                return parseTD1(line1: line1, line2: line2, line3: line3)
            }
        }
        
        // Fallback: try to see if we can join them or if there was a line split
        return nil
    }
    
    // TD3 Format - 2 lines, 44 characters (Standard Passport)
    private static func parseTD3(line1: String, line2: String) -> ParsedMRZ? {
        guard line1.hasPrefix("P") else { return nil }
        
        // Line 1: Type (2) + Issuing Country (3) + Names (39)
        let issuingCountry = cleanAlpha(String(line1.prefix(5).suffix(3)))
        let namesField = String(line1.suffix(39))
        let (lastName, firstName) = parseNames(namesField)
        
        // Line 2: DocNum (9) + CheckDigit (1) + Nationality (3) + BirthDate (6) + CheckDigit (1) + Gender (1) + ExpiryDate (6) + CheckDigit (1) + Optional (14) + CheckDigit (1) + OverallCheckDigit (1)
        guard line2.count >= 44 else { return nil }
        let docNum = String(line2.prefix(9)).replacingOccurrences(of: "<", with: "")
        let nationality = cleanAlpha(String(line2.prefix(13).suffix(3)))
        
        let dobStr = String(line2.prefix(19).suffix(6))
        let dobYY = String(dobStr.prefix(2))
        let dobMM = String(dobStr.suffix(4).prefix(2))
        let dobDD = String(dobStr.suffix(2))
        let birthDate = parseBirthDate(dobYY, mm: dobMM, dd: dobDD)
        
        let gender = String(line2.prefix(21).suffix(1)).uppercased()
        
        let doeStr = String(line2.prefix(27).suffix(6))
        let doeYY = String(doeStr.prefix(2))
        let doeMM = String(doeStr.suffix(4).prefix(2))
        let doeDD = String(doeStr.suffix(2))
        let expiryDate = parseExpiryDate(doeYY, mm: doeMM, dd: doeDD)
        
        let personalNum = String(line2.suffix(16).prefix(14)).replacingOccurrences(of: "<", with: "")
        
        return ParsedMRZ(
            documentType: "Passport",
            documentNumber: docNum,
            birthDate: birthDate,
            birthDateString: dobStr,
            expiryDate: expiryDate,
            expiryDateString: doeStr,
            firstName: firstName,
            lastName: lastName,
            nationality: nationality,
            issuingCountry: issuingCountry,
            gender: gender == "M" || gender == "F" ? gender : "X",
            personalNumber: personalNum.isEmpty ? nil : personalNum,
            rawString: line1 + "\n" + line2
        )
    }
    
    // TD1 Format - 3 lines, 30 characters (Standard ID Card)
    private static func parseTD1(line1: String, line2: String, line3: String) -> ParsedMRZ? {
        // Line 1: Type (2) + Issuing Country (3) + DocNum (9) + Check (1) + Optional (15)
        let docType = String(line1.prefix(2))
        let issuingCountry = cleanAlpha(String(line1.prefix(5).suffix(3)))
        let docNum = String(line1.prefix(14).suffix(9)).replacingOccurrences(of: "<", with: "")
        
        // Line 2: BirthDate (6) + Check (1) + Gender (1) + ExpiryDate (6) + Check (1) + Nationality (3) + Optional (11) + OverallCheck (1)
        let dobStr = String(line2.prefix(6))
        let dobYY = String(dobStr.prefix(2))
        let dobMM = String(dobStr.suffix(4).prefix(2))
        let dobDD = String(dobStr.suffix(2))
        let birthDate = parseBirthDate(dobYY, mm: dobMM, dd: dobDD)
        
        let gender = String(line2.prefix(8).suffix(1)).uppercased()
        
        let doeStr = String(line2.prefix(14).suffix(6))
        let doeYY = String(doeStr.prefix(2))
        let doeMM = String(doeStr.suffix(4).prefix(2))
        let doeDD = String(doeStr.suffix(2))
        let expiryDate = parseExpiryDate(doeYY, mm: doeMM, dd: doeDD)
        
        let nationality = cleanAlpha(String(line2.prefix(18).suffix(3)))
        
        // Line 3: Name (30)
        let (lastName, firstName) = parseNames(line3)
        
        let typeStr: String
        if docType.hasPrefix("I") || docType.hasPrefix("A") || docType.hasPrefix("C") {
            typeStr = "ID Card"
        } else {
            typeStr = "Document"
        }
        
        return ParsedMRZ(
            documentType: typeStr,
            documentNumber: docNum,
            birthDate: birthDate,
            birthDateString: dobStr,
            expiryDate: expiryDate,
            expiryDateString: doeStr,
            firstName: firstName,
            lastName: lastName,
            nationality: nationality,
            issuingCountry: issuingCountry,
            gender: gender == "M" || gender == "F" ? gender : "X",
            personalNumber: nil,
            rawString: line1 + "\n" + line2 + "\n" + line3
        )
    }
    
    // TD2 Format - 2 lines, 36 characters (older ID Card / Visas)
    private static func parseTD2(line1: String, line2: String) -> ParsedMRZ? {
        let docType = String(line1.prefix(2))
        let issuingCountry = cleanAlpha(String(line1.prefix(5).suffix(3)))
        let namesField = String(line1.suffix(31))
        let (lastName, firstName) = parseNames(namesField)
        
        // Line 2: DocNum (9) + CheckDigit (1) + Nationality (3) + BirthDate (6) + Check (1) + Gender (1) + ExpiryDate (6) + Check (1) + Optional (7) + Check (1)
        let docNum = String(line2.prefix(9)).replacingOccurrences(of: "<", with: "")
        let nationality = cleanAlpha(String(line2.prefix(13).suffix(3)))
        
        let dobStr = String(line2.prefix(19).suffix(6))
        let dobYY = String(dobStr.prefix(2))
        let dobMM = String(dobStr.suffix(4).prefix(2))
        let dobDD = String(dobStr.suffix(2))
        let birthDate = parseBirthDate(dobYY, mm: dobMM, dd: dobDD)
        
        let gender = String(line2.prefix(21).suffix(1)).uppercased()
        
        let doeStr = String(line2.prefix(27).suffix(6))
        let doeYY = String(doeStr.prefix(2))
        let doeMM = String(doeStr.suffix(4).prefix(2))
        let doeDD = String(doeStr.suffix(2))
        let expiryDate = parseExpiryDate(doeYY, mm: doeMM, dd: doeDD)
        
        let typeStr: String
        if docType.hasPrefix("V") {
            typeStr = "Visa"
        } else if docType.hasPrefix("I") || docType.hasPrefix("A") || docType.hasPrefix("C") {
            typeStr = "ID Card"
        } else {
            typeStr = "Document"
        }
        
        return ParsedMRZ(
            documentType: typeStr,
            documentNumber: docNum,
            birthDate: birthDate,
            birthDateString: dobStr,
            expiryDate: expiryDate,
            expiryDateString: doeStr,
            firstName: firstName,
            lastName: lastName,
            nationality: nationality,
            issuingCountry: issuingCountry,
            gender: gender == "M" || gender == "F" ? gender : "X",
            personalNumber: nil,
            rawString: line1 + "\n" + line2
        )
    }
}
