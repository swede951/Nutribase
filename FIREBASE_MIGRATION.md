# Firebase Migration Guide

## Overview
This document outlines the migration from Supabase to Firebase for the Nutribase app.

## Firebase Setup Steps

### 1. Firebase Console Setup
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create a new project or use existing project
3. Add iOS app with bundle identifier: `Swedeapps.nutribase`
4. Download `GoogleService-Info.plist` and add to Xcode project

### 2. Firebase SDK Installation
Add Firebase SDK via Swift Package Manager:
- URL: `https://github.com/firebase/firebase-ios-sdk`
- Products to add:
  - FirebaseAuth
  - FirebaseFirestore
  - FirebaseAnalytics
  - FirebaseCrashlytics
  - FirebasePerformance

### 3. Firebase Services Configuration

#### Authentication
- Enable Email/Password authentication in Firebase Console
- Configure sign-in methods as needed

#### Firestore Database
- Create Firestore database in production mode
- Set up security rules for user data isolation

#### Analytics
- Enable Google Analytics
- Configure data retention and privacy settings

## Data Structure Migration

### User Profiles
**Supabase Table: `user_settings`**
```sql
user_id, height_cm, weight_kg, age, gender, activity_level, calorie_target, etc.
```

**Firebase Firestore: `users/{userId}/profile`**
```json
{
  "height_cm": 175,
  "weight_kg": 70,
  "age": 30,
  "gender": "male",
  "activity_level": "moderate",
  "calorie_target": 2000,
  "updated_at": "2025-01-01T00:00:00Z"
}
```

### Weight Logs
**Supabase Table: `weight_logs`**
```sql
id, user_id, date, weight, moving_average, weekly_rate, notes, created_at
```

**Firebase Firestore: `users/{userId}/weight_logs/{entryId}`**
```json
{
  "date": "2025-01-01T00:00:00Z",
  "weight": 70.5,
  "moving_average": 70.2,
  "weekly_rate": -0.3,
  "notes": "Morning weight",
  "created_at": "2025-01-01T00:00:00Z"
}
```

### Weight Phases
**Supabase Table: `weight_phases`**
```sql
id, user_id, name, description, start_date, end_date, target_weekly_rate, color, notes
```

**Firebase Firestore: `users/{userId}/weight_phases/{phaseId}`**
```json
{
  "name": "Cut Phase",
  "description": "Losing weight for summer",
  "start_date": "2025-01-01T00:00:00Z",
  "end_date": "2025-06-01T00:00:00Z",
  "target_weekly_rate": -0.5,
  "color": "#FF5722",
  "notes": "Focus on cardio",
  "created_at": "2025-01-01T00:00:00Z"
}
```

## Migration Benefits

### Cost Efficiency
- Firebase Firestore: Pay per read/write operation
- Firebase Auth: Free up to 50,000 MAU
- Firebase Analytics: Free tier with generous limits
- No server maintenance costs

### Reliability
- Google's infrastructure with 99.95% uptime SLA
- Automatic scaling and load balancing
- Built-in offline support with local caching

### Monitoring & Analytics
- Firebase Analytics with BigQuery export
- Crashlytics for crash reporting
- Performance Monitoring for app performance
- Remote Config for feature flags

### Developer Experience
- Mature iOS SDK with excellent documentation
- Real-time listeners for data synchronization
- Automatic token refresh and session management
- Strong TypeScript/Swift type safety

## Implementation Plan

1. ✅ Add Firebase SDK and configuration
2. ✅ Create FirebaseAuthService
3. ✅ Create FirebaseProfileService  
4. ✅ Create FirebaseWeightService
5. ✅ Create FirebasePhaseService
6. ✅ Update managers to use Firebase services
7. ✅ Remove Supabase dependencies
8. ✅ Test and validate migration

## Security Rules

### Firestore Security Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only access their own data
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## Rollback Plan
- Keep Supabase services temporarily disabled but not deleted
- Maintain data export capabilities
- Test Firebase services thoroughly before full migration
