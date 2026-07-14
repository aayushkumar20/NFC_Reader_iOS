#!/bin/bash

# Exit on any error
set -e

echo "Cleaning previous builds..."
rm -rf archives
rm -rf UniversalPassportReader.xcframework

echo "Archiving for physical iOS Device..."
xcodebuild archive \
  -project UniversalPassportReader/UniversalPassportReader.xcodeproj \
  -scheme UniversalPassportReader \
  -destination "generic/platform=iOS" \
  -archivePath archives/UniversalPassportReader-iOS.xcarchive \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES

echo "Archiving for iOS Simulator..."
xcodebuild archive \
  -project UniversalPassportReader/UniversalPassportReader.xcodeproj \
  -scheme UniversalPassportReader \
  -destination "generic/platform=iOS Simulator" \
  -archivePath archives/UniversalPassportReader-Sim.xcarchive \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES

echo "Packaging XCFramework..."
xcodebuild -create-xcframework \
  -framework archives/UniversalPassportReader-iOS.xcarchive/Products/Library/Frameworks/UniversalPassportReader.framework \
  -framework archives/UniversalPassportReader-Sim.xcarchive/Products/Library/Frameworks/UniversalPassportReader.framework \
  -output UniversalPassportReader.xcframework

echo "XCFramework created successfully!"
ls -la UniversalPassportReader.xcframework
