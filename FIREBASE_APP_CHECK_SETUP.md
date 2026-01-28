# Firebase App Check Setup Guide

## Quick Setup Steps

### 1. Enable in Firebase Console
- Go to Firebase Console → App Check
- Register your iOS app with **App Attest** provider
- Enable enforcement for Firebase Authentication

### 2. Add SDK to Xcode
- Add Firebase iOS SDK package
- Include **FirebaseAppCheck** library

### 3. Initialize in Code
```swift
#if canImport(FirebaseAppCheck)
import FirebaseAppCheck

// In AppDelegate:
#if DEBUG
let providerFactory = AppCheckDebugProviderFactory()
#else
let providerFactory = AppAttestProviderFactory()
#endif
AppCheck.setAppCheckProviderFactory(providerFactory)
#endif
```

### 4. Test with Debug Token
- Run app, copy debug token from console
- Add token in Firebase Console → App Check → Manage debug tokens

### 5. Production
- Switch to `AppAttestProviderFactory()`
- Enable "Enforced" mode in Firebase Console

## Benefits
✅ Prevents bot account creation
✅ Blocks unauthorized API access
✅ Device attestation verification
