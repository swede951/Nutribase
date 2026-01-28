# Sign in with Apple Setup Guide

This guide explains how to configure Sign in with Apple for the Nutribase app.

## Sign in with Apple Setup

Sign in with Apple is automatically available for iOS apps and requires minimal setup:

### 1. Enable Sign in with Apple in Xcode
1. Open your project in Xcode
2. Select your app target
3. Go to "Signing & Capabilities"
4. Click the "+" button and add "Sign in with Apple"

### 2. Configure Supabase
1. Go to your Supabase dashboard
2. Navigate to Authentication → Providers
3. Enable "Apple" provider
4. Configure the redirect URL (if needed for web)

## AuthenticationServices Framework

The AuthenticationServices framework is automatically available on iOS 13+ and doesn't require any additional dependencies.

## Testing

### Sign in with Apple
- Test on a physical device (Simulator may have limitations)
- Ensure you're signed into iCloud on the test device
- Test both first-time sign-in and returning user scenarios

## Troubleshooting

### Common Issues

1. **Apple Sign-In not working**
   - Check that "Sign in with Apple" capability is enabled in Xcode
   - Test on a physical device with iCloud account (Simulator may have limitations)
   - Verify Supabase Apple provider is enabled in your dashboard

2. **Supabase authentication fails**
   - Check that Apple provider is enabled in Supabase dashboard
   - Verify API keys and configuration are correct
   - Check network connectivity and HTTP client implementation

3. **Identity token issues**
   - Ensure proper token extraction from Apple ID credential
   - Verify token is being sent correctly to Supabase
   - Check for proper error handling in authentication flow

## Security Considerations

1. **Token validation**
   - Supabase handles Apple ID token validation automatically
   - Ensure proper error handling for invalid tokens
   - Handle expired token scenarios gracefully

2. **User privacy**
   - Apple Sign-In respects user privacy preferences
   - Users can choose to hide their email address
   - Handle cases where email is not provided

## Implementation Status

✅ Sign in with Apple UI button added
✅ Apple authentication logic implemented
✅ Supabase integration for Apple auth
✅ Error handling and analytics tracking
✅ Clean, focused implementation without external dependencies

## Supabase Configuration

Based on your current setup, complete these final steps in your Supabase dashboard:

### 1. Apple Provider Settings
```
Client ID: Nutribase
Secret Key: [Generate from Apple Developer Console]
Callback URL: https://owmwxzkzqpbhlofqmm.supabase.co/auth/v1/callback
```

### 2. Generate Apple OAuth Secret Key

1. **Go to Apple Developer Console**:
   - Navigate to Certificates, Identifiers & Profiles
   - Go to Keys section
   - Create a new key for "Sign in with Apple"

2. **Download the .p8 file** and note:
   - Key ID (from the key details)
   - Team ID (from your Apple Developer account)

3. **Generate the secret** using:
   - The .p8 private key file
   - Your Team ID
   - The Key ID
   - Client ID (Nutribase)

### 3. Final Configuration Steps

1. **In Supabase Dashboard**:
   - Paste the generated secret key in the "Secret Key (for OAuth)" field
   - Save the Apple provider configuration

2. **Test the integration**:
   - Use a physical iOS device (not simulator)
   - Ensure device is signed into iCloud
   - Test both new user and returning user flows

## Current Status

✅ Sign in with Apple UI implemented
✅ Apple authentication service logic complete
✅ Entitlements configured (com.apple.developer.applesignin)
✅ Supabase Apple provider enabled
🔄 **IN PROGRESS**: OAuth secret key configuration
⏳ **PENDING**: Final testing on device
