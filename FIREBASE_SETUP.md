# Firebase Setup Instructions

## 1. Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project" or "Add project"
3. Enter project name: `nutribase-analytics`
4. Enable Google Analytics for this project (recommended)
5. Choose or create a Google Analytics account
6. Click "Create project"

## 2. Add iOS App to Firebase Project

1. In the Firebase console, click "Add app" and select iOS
2. Enter your iOS bundle ID: `com.alexsweet.nutribase` (or your actual bundle ID)
3. Enter App nickname: `Nutribase`
4. Leave App Store ID empty for now
5. Click "Register app"

## 3. Download Configuration File

1. Download the `GoogleService-Info.plist` file
2. Add it to your Xcode project:
   - Drag the file into Xcode
   - Make sure "Copy items if needed" is checked
   - Select your app target
   - Make sure it's added to the main bundle (not test targets)

## 4. Add Firebase SDK via Swift Package Manager

1. In Xcode, go to File → Add Package Dependencies
2. Enter the repository URL: `https://github.com/firebase/firebase-ios-sdk`
3. Choose "Up to Next Major Version" and click "Add Package"
4. Select these products:
   - `FirebaseAnalytics`
   - `FirebaseCore`
5. Click "Add Package"

## 5. Verify Setup

After completing these steps, the app will automatically initialize Firebase Analytics when launched. You can verify it's working by:

1. Running the app in debug mode
2. Checking the Xcode console for Firebase initialization logs
3. Going to Settings → Privacy and enabling "Share Anonymous Analytics"
4. Using the app features - events should appear in Firebase Analytics within 24 hours

## Privacy Compliance

The implementation includes:
- ✅ Analytics disabled by default
- ✅ User consent required via Settings toggle
- ✅ No PII or health data in events
- ✅ GDPR-compliant design
- ✅ Ability to disable analytics at any time

## Event Taxonomy

The following events are tracked:
- Authentication: sign_in_started, sign_in_succeeded, sign_in_failed, sign_out
- Search: food_search_started, food_search_result_tapped
- Barcode: barcode_scan_started, barcode_scan_succeeded, barcode_scan_failed
- Food Logging: food_entry_added, food_entry_deleted
- Weight: weight_entry_added, weight_health_import_*, csv_import_*, weight_chart_timeframe_selected
- Phases: phase_created, phase_updated, phase_deleted
- Engagement: screen_view, feature_tapped
