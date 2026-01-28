# Firebase Analytics HTTP/1.1 Setup Guide

This guide explains how to complete the Firebase Analytics setup using the HTTP/1.1 client to bypass iOS HTTP/3 protocol issues.

## What We've Implemented

✅ **FirebaseHTTP1Client.swift** - Custom HTTP/1.1 client that bypasses iOS URLSession HTTP/3 issues
✅ **Enhanced AnalyticsService.swift** - Modified to use HTTP/1.1 client instead of Firebase SDK
✅ **FirebaseConfig.swift** - Configuration file for Firebase credentials
✅ **Privacy-first approach** - User consent required, PII filtering, debug logging

## Required Setup Steps

### 1. Get Firebase Credentials

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project (or create a new one)
3. Go to **Project Settings** → **General** tab
4. Copy your **Web API Key** from the "Web API Key" field
5. Note your **Project ID** from the project overview

### 2. Update Configuration

Edit `/nutribase/Config/FirebaseConfig.swift`:

```swift
struct FirebaseConfig {
    static let apiKey = "YOUR_ACTUAL_WEB_API_KEY_HERE"  // Replace this
    static let projectId = "your-project-id"            // Replace this
    
    // These are already configured correctly
    static let batchLogUrl = "https://firebaselogging-pa.googleapis.com/v1/firelog/legacy/batchlog"
    static let bundleId = Bundle.main.bundleIdentifier ?? "com.nutribase.app"
    static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
}
```

### 3. Test the Implementation

1. Build and run the app
2. Enable analytics in Settings → Privacy → Analytics
3. Perform some actions (sign in, search for food, etc.)
4. Check Xcode console for HTTP/1.1 debug logs:
   - `🔥 Firebase HTTP/1.1 Request to firebaselogging-pa.googleapis.com`
   - `✅ Event 'event_name' sent via HTTP/1.1`

## Benefits of This Approach

- **Bypasses HTTP/3 issues**: Uses raw TCP/TLS connections via Network framework
- **No Firebase SDK dependency**: Eliminates the source of protocol violations
- **Same functionality**: All analytics events still reach Firebase Analytics
- **Better debugging**: Clear HTTP/1.1 request/response logging
- **Privacy compliant**: Maintains all existing PII filtering and user consent

## Troubleshooting

### If events aren't appearing in Firebase Analytics:

1. **Check API Key**: Ensure you're using the Web API Key, not other keys
2. **Verify Project ID**: Must match your Firebase project exactly
3. **Check Console Logs**: Look for HTTP status codes in debug output
4. **Firebase Processing**: Analytics data can take 24-48 hours to appear in dashboard

### Common Error Codes:

- **HTTP 400**: Invalid API key or malformed request
- **HTTP 403**: API key doesn't have Analytics permissions
- **HTTP 429**: Rate limiting (too many requests)

## Migration Notes

This implementation replaces the standard Firebase Analytics SDK calls with direct HTTP/1.1 requests. The AnalyticsService API remains identical, so no changes are needed in your UI code.

The solution maintains all existing features:
- User consent management
- PII filtering
- Event parameter validation
- Debug logging
- Privacy compliance

## Next Steps

Once configured, you can:
1. Monitor analytics in Firebase Console
2. Add more event tracking throughout the app
3. Set up conversion funnels and user segments
4. Configure custom audiences for marketing

The HTTP/1.1 approach should eliminate the network connection errors you were seeing in the Xcode console.
