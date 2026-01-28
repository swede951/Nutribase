# App Store Compliance Checklist

## ✅ COMPLETED

1. **Privacy Policy** - Created and accessible
2. **Terms of Service** - Created with medical disclaimer
3. **User Consent** - Collected during onboarding (step 2)
4. **Data Consents View** - Users control analytics/crash reporting
5. **No Health Data for Ads** - Stated in privacy policy
6. **HTTPS/Encryption** - Firebase handles this
7. **User Rights** - Data export & account deletion options
8. **Contact Info** - support@nutribase.app

## ⚠️ STILL NEEDED

### 1. Privacy Manifest File (REQUIRED)
Create `PrivacyInfo.xcprivacy` in Xcode:
- File → New → App Privacy
- Declare: Email, Health Data, User ID, Analytics
- Add API usage reasons

### 2. Host Privacy Policy Online
Upload to website before App Store submission

### 3. App Store Connect
- Complete Privacy Nutrition Label questionnaire
- Declare: Contact Info (email), Health & Fitness (weight/nutrition)
- Set age rating: 12+
- Export compliance: Standard encryption only

## 📝 Key Apple Requirements Met

- **5.1.1** Privacy policy + user consent ✅
- **5.1.3** No health data for advertising ✅
- **1.4.1** Medical disclaimer included ✅
- **ATS** HTTPS required ✅

## Next Steps

1. Create Privacy Manifest file in Xcode
2. Host privacy policy at nutribase.app/privacy
3. Complete App Store Connect privacy questionnaire
