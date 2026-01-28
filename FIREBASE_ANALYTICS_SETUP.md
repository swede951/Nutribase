# Firebase Analytics Setup

## Overview
Firebase Analytics has been configured to track key metrics for your Nutribase app. The analytics will automatically collect data once users grant consent in the app settings.

## Metrics Being Tracked

### 1. **Total Sessions Per Day (Across All Users)**
- **Event:** `session_start`
- **Automatically tracked by:** Firebase Analytics
- **Where to view:** Firebase Console → Analytics → Events → session_start
- **Aggregation:** Firebase automatically aggregates this across all users per day

### 2. **Page Views for Main 4 Pages**
Firebase tracks page views for the following main screens:

#### Dashboard
- **Event:** `page_view_dashboard`
- **Screen Name:** "Dashboard"
- **Triggered:** Every time user opens the Dashboard tab

#### Food Log
- **Event:** `page_view_food_log`
- **Screen Name:** "Food Log"
- **Triggered:** Every time user opens the Food Log tab

#### Phases
- **Event:** `page_view_phases`
- **Screen Name:** "Phases"
- **Triggered:** Every time user opens the Phases tab

#### Weight Logbook
- **Event:** `page_view_weight_logbook`
- **Screen Name:** "Weight Logbook"
- **Triggered:** Every time user opens the Weight Logbook tab

### 3. **Monthly Active Users (MAU)**
- **Metric:** Automatically tracked by Firebase
- **Where to view:** Firebase Console → Analytics → Dashboard → Active Users
- **Definition:** Unique users who have used the app in the last 30 days

### 4. **Average Page Views Per User Per Day**
- **Calculation:** Total page views / Total active users per day
- **Events used:** 
  - `page_view_dashboard`
  - `page_view_food_log`
  - `page_view_phases`
  - `page_view_weight_logbook`
- **Where to view:** Firebase Console → Analytics → Custom Reports (you'll need to create a custom report)

## How to View These Metrics in Firebase Console

### Step 1: Access Firebase Console
1. Go to https://console.firebase.google.com
2. Select your Nutribase project
3. Click on "Analytics" in the left sidebar

### Step 2: View Total Sessions Per Day
1. Go to **Analytics → Events**
2. Search for `session_start`
3. View the graph showing sessions over time
4. You can export this data or create custom reports

### Step 3: View Page Views
1. Go to **Analytics → Events**
2. Search for:
   - `page_view_dashboard`
   - `page_view_food_log`
   - `page_view_phases`
   - `page_view_weight_logbook`
3. Each event shows total count and trend over time

### Step 4: View MAU (Monthly Active Users)
1. Go to **Analytics → Dashboard**
2. Look for the "Active Users" card
3. Select "Last 30 days" to see MAU
4. You can also see DAU (Daily Active Users) and WAU (Weekly Active Users)

### Step 5: Calculate Average Page Views Per User Per Day
1. Go to **Analytics → Custom Reports**
2. Click "Create Custom Report"
3. Set up the report:
   - **Metric:** Count of events (page_view_*)
   - **Dimension:** Date
   - **Segment:** Active users
4. Or use BigQuery export for more complex calculations

## Privacy & Consent

The app respects user privacy:
- Analytics is **enabled by default** to collect usage metrics
- Users can disable analytics in **Settings → Privacy → Data Consents**
- No personally identifiable information (PII) is collected
- Health data (weight, calories) is filtered out from analytics
- Users can revoke consent at any time
- All data collection complies with privacy best practices

## Implementation Details

### Files Modified
1. **AnalyticsService.swift** - Re-enabled Firebase Analytics SDK
2. **DashboardView.swift** - Added `trackDashboardView()` call
3. **FoodLogView.swift** - Added `trackFoodLogView()` call
4. **TestPhasesView.swift** - Added `trackPhasesView()` call
5. **WeightLogView.swift** - Added `trackWeightLogbookView()` call

### Code Example
```swift
// Track page view when view appears
.onAppear {
    AnalyticsService.shared.trackDashboardView()
}
```

## Testing Analytics

### Debug Mode (Development)
1. All events are logged to Xcode console with 🔍 prefix
2. You can verify events are being sent correctly
3. Events appear in Firebase Console within 24 hours (or use DebugView for real-time)

### Enable DebugView in Firebase
1. In Xcode, edit your scheme
2. Add argument: `-FIRDebugEnabled`
3. Run the app
4. Go to Firebase Console → Analytics → DebugView
5. See events in real-time

## Next Steps

1. **Rebuild and run the app:** Analytics is now enabled by default
2. **Use the app:** Open different pages to generate events
3. **Wait 24 hours:** Firebase processes data in batches (or use DebugView for real-time)
4. **Check Firebase Console:** View your metrics in the Analytics dashboard
5. **Create Custom Reports:** Set up custom reports for specific insights
6. **Export to BigQuery (Optional):** For advanced analysis and custom calculations

## Support

If you need help:
- Firebase Analytics Documentation: https://firebase.google.com/docs/analytics
- Firebase Console: https://console.firebase.google.com
- Check Xcode console for debug logs (look for 🔍 AnalyticsService messages)
