# TestFlight Setup Instructions for NutriBase

Follow these steps to fix the Info.plist conflict and prepare your app for TestFlight submission:

## 1. Fix the Info.plist Conflict

Your project is configured to generate the Info.plist file automatically (`GENERATE_INFOPLIST_FILE = YES`), which is causing the conflict. Here's how to fix it:

1. Open your project in Xcode
2. Select the project in the Project Navigator (left sidebar)
3. Select the "nutribase" target
4. Go to the "Info" tab
5. Add the following keys and values:

| Key | Value |
|-----|-------|
| Privacy - Camera Usage Description | NutriBase needs camera access to scan food packaging for ingredients. |
| Privacy - Health Share Usage Description | NutriBase needs access to your health data to track your nutrition and activity. |
| Privacy - Health Update Usage Description | NutriBase needs permission to update your health data with nutrition information. |

## 2. Configure Version and Build Numbers

1. In the "General" tab of your target settings:
   - Set "Version" to "1.0" (or your desired version)
   - Set "Build" to "1" (increment this for each TestFlight submission)

## 3. Archive and Upload Your App

1. Select "Any iOS Device" (or a generic iOS device) as the build destination
2. Select Product > Archive from the menu
3. Once the archive is complete, the Organizer window will appear
4. Select your archive and click "Distribute App"
5. Select "App Store Connect" and click "Next"
6. Select "Upload" and click "Next"
7. Select options for distribution:
   - Include bitcode: Yes
   - Upload symbols: Yes
8. Click "Next" and then "Upload"

## 4. Submit for TestFlight Testing

1. Go to [App Store Connect](https://appstoreconnect.apple.com/)
2. Select your app and go to the "TestFlight" tab
3. Wait for the build to finish processing (can take 15-30 minutes)
4. Once processing is complete, add internal testers:
   - Go to "Internal Testing"
   - Click "Add Testers" or "Add Group"
   - Enter email addresses of your testers (must be associated with your team)
5. Enable the build for testing

## 5. Troubleshooting

If you encounter any issues during the submission process:

- **Processing Issues**: Check the issues in App Store Connect
- **Signing Issues**: Ensure your provisioning profiles and certificates are valid
- **Missing Compliance**: Complete the export compliance questions if prompted
- **TestFlight Rejection**: Address any issues mentioned in the rejection email

Remember that TestFlight builds expire after 90 days, so plan your testing schedule accordingly.
