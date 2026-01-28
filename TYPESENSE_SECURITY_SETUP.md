# Typesense Security Setup - Firebase Functions

This guide explains how to deploy the secure Typesense proxy functions.

## Overview

API keys are now stored securely in Firebase Secret Manager, not in the app bundle.

| Before | After |
|--------|-------|
| API keys in Swift code | API keys in Firebase Secrets |
| Anyone can extract from IPA | Keys never leave server |
| Direct Typesense calls | Proxied through Firebase Functions |

## Step 1: Set Up Firebase Secret

Add the Typesense admin API key to Firebase Secret Manager:

```bash
cd firebase-functions

# Set the Typesense admin API key as a secret
firebase functions:secrets:set TYPESENSE_ADMIN_API_KEY
```

When prompted, enter: `iCrX1bLheI7cTr2USV764ElrD3dG3lL3`

## Step 2: Deploy Firebase Functions

```bash
cd firebase-functions

# Install dependencies
npm install

# Deploy all functions
firebase deploy --only functions
```

## Step 3: Verify Deployment

After deployment, you should see these new functions:
- `typesenseSearch` - Single collection search
- `typesenseMultiSearch` - Two-lane search (ingredients + products)
- `typesenseIncrementPopularity` - Flywheel popularity updates
- `typesenseBarcodeLookup` - Barcode-based food lookup

## Step 4: Test the Functions

You can test from the Firebase Console or using curl:

```bash
# Get your Firebase project ID
FIREBASE_PROJECT="your-project-id"

# Test search (requires auth token)
curl -X POST "https://us-central1-${FIREBASE_PROJECT}.cloudfunctions.net/typesenseSearch" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_AUTH_TOKEN" \
  -d '{"query": "chicken breast"}'
```

## Swift App Configuration

The app is already configured to use secure mode. Check `TypesenseDirectService.swift`:

```swift
private struct TypesenseConfig {
    // SECURITY: Set to true for production
    static let useSecureCloudMode = true
}
```

- `true` = All searches go through Firebase Functions (secure)
- `false` = Direct Typesense calls (for development only)

## Security Checklist

- [x] Typesense admin API key stored in Firebase Secrets
- [x] Search-only API key removed from app (no longer needed)
- [x] Firebase Functions require authentication
- [x] Rate limiting in place (100 searches/min/user)
- [x] All API calls proxied through Firebase

## Rollback

If you need to switch back to direct mode temporarily:

1. Set `useSecureCloudMode = false` in `TypesenseDirectService.swift`
2. The app will use the search-only key directly (less secure)

## Cost Considerations

Firebase Functions pricing:
- First 2M invocations/month: Free
- After: $0.40 per million invocations

Estimated usage:
- 1000 DAU × 10 searches/day = 10,000 searches/day
- 300,000 searches/month = Well within free tier
