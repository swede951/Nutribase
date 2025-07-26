# NutriBase - TestFlight Submission Guide

This guide will help you submit your NutriBase app to TestFlight for internal testing.

## Prerequisites

1. An Apple Developer account ($99/year)
2. Access to App Store Connect
3. Xcode installed on your Mac
4. Your app code ready for submission

## Step 1: Configure Your App for Distribution

1. Open your project in Xcode by double-clicking the `.xcodeproj` file
2. Select the project in the Project Navigator (left sidebar)
3. Select the "nutribase" target
4. Go to the "Signing & Capabilities" tab
5. Ensure "Automatically manage signing" is checked
6. Select your Team from the dropdown
7. Verify that your Bundle Identifier is unique (e.g., com.yourcompany.nutribase)

## Step 2: Update Version and Build Numbers

1. In the "General" tab of your target settings
2. Set "Version" to "1.0" (or your desired version)
3. Set "Build" to "1" (increment this for each TestFlight submission)

## Step 3: Create an App Record in App Store Connect

1. Go to [App Store Connect](https://appstoreconnect.apple.com/)
2. Click on "My Apps"
3. Click the "+" button and select "New App"
4. Fill in the required information:
   - Platform: iOS
   - App name: NutriBase
   - Primary language: English
   - Bundle ID: Select your app's bundle ID
   - SKU: A unique identifier (e.g., com.yourcompany.nutribase)
   - User Access: Full Access

## Step 4: Archive and Upload Your App

1. In Xcode, select "Any iOS Device" (or a generic iOS device) as the build destination
2. Select Product > Archive from the menu
3. Once the archive is complete, the Organizer window will appear
4. Select your archive and click "Distribute App"
5. Select "App Store Connect" and click "Next"
6. Select "Upload" and click "Next"
7. Select options for distribution:
   - Include bitcode: Yes
   - Upload symbols: Yes
8. Click "Next" and then "Upload"

## Step 5: Submit for TestFlight Testing

1. Return to App Store Connect
2. Select your app and go to the "TestFlight" tab
3. Wait for the build to finish processing (can take 15-30 minutes)
4. Once processing is complete, add internal testers:
   - Go to "Internal Testing"
   - Click "Add Testers" or "Add Group"
   - Enter email addresses of your testers (must be associated with your team)
5. Enable the build for testing

## Step 6: Invite Testers

1. Once your build is approved for TestFlight, testers will receive an email
2. They need to:
   - Accept the invitation
   - Download the TestFlight app from the App Store
   - Sign in with their Apple ID
   - Install your app through TestFlight

## Troubleshooting

- **Processing Issues**: If your build fails processing, check the issues in App Store Connect
- **Signing Issues**: Ensure your provisioning profiles and certificates are valid
- **Missing Compliance**: Complete the export compliance questions if prompted
- **TestFlight Rejection**: Address any issues mentioned in the rejection email

## Important Notes

- TestFlight builds expire after 90 days
- You can have multiple builds available for testing
- Internal testing is limited to 100 members of your team
- External testing can include up to 10,000 testers (requires App Review)

## App-Specific Information

- NutriBase uses HealthKit, which requires proper entitlements and privacy descriptions
- The camera usage for scanning food packaging requires a privacy description
- All necessary privacy descriptions have been added to the Info.plist file

For more detailed information, refer to [Apple's TestFlight documentation](https://developer.apple.com/testflight/).
