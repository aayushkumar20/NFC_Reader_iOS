import UIKit

public struct DocumentData: Identifiable {
    public var id: String { documentNumber }
    
    public let documentType: String // e.g. "Passport", "ID Card", "Visa"
    public let documentNumber: String
    public let issuingCountry: String
    public let expiryDate: Date?
    public let lastName: String
    public let firstName: String
    public let nationality: String
    public let dateOfBirth: Date?
    public let gender: String // "M", "F", "X" or "U"
    public let personalNumber: String?
    public let faceImage: UIImage?
    public let isBACAuthenticated: Bool
    public let isPassiveAuthenticated: Bool
    
    public init(
        documentType: String,
        documentNumber: String,
        issuingCountry: String,
        expiryDate: Date?,
        lastName: String,
        firstName: String,
        nationality: String,
        dateOfBirth: Date?,
        gender: String,
        personalNumber: String? = nil,
        faceImage: UIImage? = nil,
        isBACAuthenticated: Bool = false,
        isPassiveAuthenticated: Bool = false
    ) {
        self.documentType = documentType
        self.documentNumber = documentNumber
        self.issuingCountry = issuingCountry
        self.expiryDate = expiryDate
        self.lastName = lastName
        self.firstName = firstName
        self.nationality = nationality
        self.dateOfBirth = dateOfBirth
        self.gender = gender
        self.personalNumber = personalNumber
        self.faceImage = faceImage
        self.isBACAuthenticated = isBACAuthenticated
        self.isPassiveAuthenticated = isPassiveAuthenticated
    }
    
    public var age: Int? {
        guard let dateOfBirth = dateOfBirth else { return nil }
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: dateOfBirth, to: Date())
        return ageComponents.year
    }
}
