import XCTest
@testable import UniversalPassportReader

final class MRZParserTests: XCTestCase {
    
    func testTD3PassportParsing() {
        let line1 = "P<INDSHARMA<<RAHUL<<<<<<<<<<<<<<<<<<<<<<<<<<"
        let line2 = "L898902C36IND9508272M2602237<<<<<<<<<<<<<<02"
        
        guard let parsed = MRZParser.parse(lines: [line1, line2]) else {
            XCTFail("Failed to parse TD3 Passport")
            return
        }
        
        XCTAssertEqual(parsed.documentType, "Passport")
        XCTAssertEqual(parsed.documentNumber, "L898902C3")
        XCTAssertEqual(parsed.lastName, "SHARMA")
        XCTAssertEqual(parsed.firstName, "RAHUL")
        XCTAssertEqual(parsed.issuingCountry, "IND")
        XCTAssertEqual(parsed.nationality, "IND")
        XCTAssertEqual(parsed.gender, "M")
    }
    
    func testTD1IDCardParsing() {
        let line1 = "I<UTOD2300000397<<<<<<<<<<<<<<"
        let line2 = "6502256M2111155UTO<<<<<<<<<<04"
        let line3 = "ERIKSSON<<ANNA<MARIA<<<<<<<<<<"
        
        guard let parsed = MRZParser.parse(lines: [line1, line2, line3]) else {
            XCTFail("Failed to parse TD1 ID Card")
            return
        }
        
        XCTAssertEqual(parsed.documentType, "ID Card")
        XCTAssertEqual(parsed.documentNumber, "D23000003")
        XCTAssertEqual(parsed.lastName, "ERIKSSON")
        XCTAssertEqual(parsed.firstName, "ANNA MARIA")
        XCTAssertEqual(parsed.issuingCountry, "UTO")
        XCTAssertEqual(parsed.nationality, "UTO")
        XCTAssertEqual(parsed.gender, "M")
    }
    
    func testLenientTD3PassportParsing() {
        // A TD3 format document (44 chars, 2 lines) starting with "I" (Resident Card) or "V" (Visa)
        let line1 = "IRUSAERIKSSON<<ANNA<<<<<<<<<<<<<<<<<<<<<<<<<"
        let line2 = "L898902C36USA9508272M2602237<<<<<<<<<<<<<<02"
        
        guard let parsed = MRZParser.parse(lines: [line1, line2]) else {
            XCTFail("Failed to parse lenient TD3 Card")
            return
        }
        
        XCTAssertEqual(parsed.documentType, "ID Card")
        XCTAssertEqual(parsed.documentNumber, "L898902C3")
        XCTAssertEqual(parsed.lastName, "ERIKSSON")
        XCTAssertEqual(parsed.firstName, "ANNA")
    }
    
    func testMRZCleaner() {
        let dirtyNumeric = "O1Z5S8G"
        let cleanedNumeric = MRZParser.cleanNumeric(dirtyNumeric)
        XCTAssertEqual(cleanedNumeric, "0125586")
        
        let dirtyAlpha = "01258"
        let cleanedAlpha = MRZParser.cleanAlpha(dirtyAlpha)
        XCTAssertEqual(cleanedAlpha, "OIZSB")
    }
}
