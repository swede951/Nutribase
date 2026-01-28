# NutriBase App Store Readiness Checklist

## ✅ COMPLETED ITEMS

### App Icons & Assets
- ✅ **App icons generated** - All required sizes (40x40, 60x60, 120x120, 180x180, 1024x1024)
- ✅ **Asset catalog fixed** - Removed incorrect ChatGPT placeholder images
- ✅ **App logo fixed** - Resolved unassigned child warning

### Project Configuration
- ✅ **Bundle ID**: `Swedeapps.nutribase`
- ✅ **Team ID**: `37TJL6F9HL`
- ✅ **Version**: 1.0
- ✅ **Build**: 1
- ✅ **Display Name**: NutriBase
- ✅ **Deployment Target**: iOS 18.4

### Privacy & Permissions
- ✅ **HealthKit entitlements** configured
- ✅ **Apple Sign In** entitlement configured
- ✅ **Camera usage description**: "NutriBase needs camera access to scan food labels and barcodes"
- ✅ **HealthKit share description**: "NutriBase needs access to your health data to track your steps and activity"
- ✅ **HealthKit update description**: "NutriBase needs permission to update your health data"

### Core Features
- ✅ **Food logging** with barcode scanning
- ✅ **Weight tracking** with HealthKit integration
- ✅ **Nutrition goals** and macro tracking
- ✅ **User authentication** (email/password, Apple Sign In)
- ✅ **Cloud sync** via Supabase
- ✅ **Modern UI** with card-based design
- ✅ **Data isolation** per user account

### Dependencies
- ✅ **Firebase** (Analytics, Auth, Firestore, Crashlytics, Performance)
- ✅ **Typesense** for food search
- ✅ **Supabase** for backend (custom HTTP client)

---

## ⚠️ NEEDS ATTENTION BEFORE SUBMISSION

### 1. Testing & Quality Assurance
- ❌ **Physical device testing** - Test on multiple iPhone models
- ❌ **iOS version testing** - Test on iOS 16, 17, 18
- ❌ **Memory testing** - Check for memory leaks with Instruments
- ❌ **Crash testing** - Verify no crashes in critical flows
- ❌ **HealthKit authorization** - Thoroughly test the authorization flow (recent issues noted)
- ❌ **Onboarding flow** - Verify compilation and functionality (compilation errors mentioned in memories)
- ❌ **Network error handling** - Test offline scenarios

### 2. App Store Connect Setup
- ❌ **Create App Store Connect record**
- ❌ **App description** (4000 char max)
- ❌ **Keywords** (100 char max)
- ❌ **Screenshots** required:
  - 6.7" iPhone (1290x2796) - 3-10 screenshots
  - 6.5" iPhone (1242x2688) - 3-10 screenshots
  - 5.5" iPhone (1242x2208) - 3-10 screenshots
- ❌ **App preview videos** (optional but recommended)
- ❌ **Promotional text** (170 char)
- ❌ **Support URL**
- ❌ **Marketing URL** (optional)
- ❌ **Privacy policy URL** (REQUIRED for health apps)

### 3. Legal Requirements
- ❌ **Privacy Policy** - CRITICAL for health data apps
  - Must explain what health data is collected
  - How it's used and stored
  - User rights and data deletion
  - Third-party services (Firebase, Supabase, Typesense)
- ❌ **Terms of Service** - Recommended
- ❌ **Export Compliance** - Determine if app uses encryption

### 4. App Review Information
- ❌ **Demo account** - Provide test credentials for reviewers
- ❌ **Review notes** - Explain HealthKit usage, barcode scanning
- ❌ **Contact information** - Phone and email for App Review

### 5. Age Rating
- ❌ **Complete questionnaire** in App Store Connect
  - Medical/Treatment Information: YES (nutrition tracking)
  - Unrestricted Web Access: NO
  - Gambling: NO
  - Contests: NO

### 6. Code Quality & Performance
- ⚠️ **Remove debug logging** - Clean up console.log statements
- ⚠️ **API key security** - Verify no hardcoded sensitive keys
- ⚠️ **Error messages** - User-friendly, not technical
- ⚠️ **Loading states** - All async operations show loading UI
- ⚠️ **Empty states** - Handled gracefully (weight logbook has this ✅)

### 7. Analytics & Monitoring
- ⚠️ **Firebase Analytics** - Verify setup is complete
- ⚠️ **Crashlytics** - Test crash reporting
- ⚠️ **Performance monitoring** - Verify Firebase Performance is working

### 8. Localization (Optional for v1.0)
- ❌ **Multiple languages** - Currently English only
- ❌ **Region-specific content** - Food database is international

---

## 🔧 RECOMMENDED IMPROVEMENTS (Post-Launch)

### User Experience
- 📝 **Onboarding tutorial** - Guide new users through features
- 📝 **Tooltips** - Explain NOVA score, Nutri-Score
- 📝 **Haptic feedback** - Add tactile feedback for key actions
- 📝 **Dark mode optimization** - Verify all screens look good

### Features
- 📝 **Meal templates** - Save common meals
- 📝 **Recipe builder** - Create custom recipes
- 📝 **Progress photos** - Visual weight tracking
- 📝 **Export data** - CSV/PDF reports
- 📝 **Widgets** - Home screen widgets for quick logging

### Performance
- 📝 **Image caching** - Cache food images
- 📝 **Offline mode** - Better offline functionality
- 📝 **Background sync** - Sync when app is backgrounded

---

## 📋 PRE-SUBMISSION CHECKLIST

Before clicking "Submit for Review":

1. [ ] Test on physical device (not just simulator)
2. [ ] Verify all privacy descriptions are accurate
3. [ ] Test HealthKit authorization flow thoroughly
4. [ ] Create privacy policy and host it online
5. [ ] Take all required screenshots
6. [ ] Write compelling app description
7. [ ] Set up demo account for reviewers
8. [ ] Test barcode scanning with various products
9. [ ] Verify food search returns relevant results
10. [ ] Test weight tracking and chart display
11. [ ] Verify user authentication (sign up, sign in, sign out)
12. [ ] Test data sync across devices (if possible)
13. [ ] Remove all debug/test code
14. [ ] Archive and upload to App Store Connect
15. [ ] Complete all App Store Connect metadata
16. [ ] Submit for review

---

## 🚨 CRITICAL ISSUES TO FIX

Based on memories, these issues need verification/fixing:

1. **HealthKit Authorization** - Recent memory shows persistent authorization issues even after granting permissions
2. **Onboarding Compilation** - Memory mentions compilation errors in OnboardingView.swift
3. **JWT Token Refresh** - Memory mentions expired JWT tokens need automatic refresh
4. **Weight Chart Gridlines** - Memory mentions persistent gridlines below floating X-axis

---

## 📊 ESTIMATED TIME TO LAUNCH

- **If focusing on MVP**: 2-3 days
  - 1 day: Testing, bug fixes, screenshots
  - 1 day: Privacy policy, App Store Connect setup
  - 0.5 day: Final review and submission
  
- **If including improvements**: 1-2 weeks
  - Additional features, polish, comprehensive testing

---

## 💡 RECOMMENDATIONS

### Priority 1 (Must Fix)
1. Fix HealthKit authorization issues
2. Create privacy policy
3. Test on physical device
4. Take screenshots
5. Fix any compilation errors

### Priority 2 (Should Fix)
1. Improve error handling
2. Add better loading states
3. Clean up debug logging
4. Test offline scenarios

### Priority 3 (Nice to Have)
1. Add onboarding tutorial
2. Improve empty states
3. Add haptic feedback
4. Optimize performance

---

## 📞 NEXT STEPS

1. **Run the app on a physical device** and test all features
2. **Fix critical bugs** (HealthKit, onboarding, etc.)
3. **Create privacy policy** (can use templates online)
4. **Take screenshots** on required device sizes
5. **Set up App Store Connect** record
6. **Archive and upload** build
7. **Submit for TestFlight** internal testing first
8. **Get feedback** from testers
9. **Fix issues** found in testing
10. **Submit for App Review**

---

## 🎯 VERDICT

**You're approximately 2-3 days away from TestFlight submission** if you focus on the critical items.

**You're approximately 1-2 weeks away from public App Store submission** if you want to polish everything.

The app has solid core functionality, but needs:
- Bug fixes (HealthKit, onboarding)
- Legal requirements (privacy policy)
- App Store assets (screenshots, descriptions)
- Thorough testing on physical devices

Good luck with your launch! 🚀
