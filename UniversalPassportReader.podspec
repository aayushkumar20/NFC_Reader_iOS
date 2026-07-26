Pod::Spec.new do |spec|
  spec.name         = "UniversalPassportReader"
  spec.version      = "1.0.0"
  spec.summary      = "ICAO Doc 9303 NFC Passport & Identity Card Reader for iOS."
  spec.description  = <<-DESC
                      A premium, production-grade iOS framework built from scratch with zero external dependencies
                      to read and verify NFC-enabled electronic passports (ePassports) and identity cards (eIDs).
                      Implements ICAO Doc 9303 Part 11 protocols, BAC, CAN derivation, and TLV parsing.
                      DESC
  spec.homepage     = "https://github.com/aayushkumar20/NFC_Reader_iOS"
  spec.license      = { :type => "MIT", :file => "LICENSE" }
  spec.author       = { "Aayush Kumar" => "aayushkumar20@users.noreply.github.com" }
  
  spec.platform     = :ios, "15.0"
  spec.source       = { :git => "https://github.com/aayushkumar20/NFC_Reader_iOS.git", :tag => "v#{spec.version}" }

  # Distribute via precompiled XCFramework slice
  spec.vendored_frameworks = "UniversalPassportReader.xcframework"
  
  spec.swift_version = "5.0"
  spec.frameworks    = "Foundation", "CoreNFC", "AVFoundation", "Vision", "UIKit"
  
  spec.pod_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  spec.user_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
end
