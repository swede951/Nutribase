# Firebase Cloud Functions Setup for Food Flags

## Why Cloud Functions?

Instead of giving users direct write access to Firestore (security risk), we use Cloud Functions as a secure backend:

✅ **Secure**: Users can't write arbitrary data to your database  
✅ **Validated**: Server-side validation of all inputs  
✅ **Rate Limited**: Prevent abuse (max 10 flags per user per day)  
✅ **Auditable**: All submissions logged server-side  
✅ **Flexible**: Easy to add notifications, moderation, etc.

## Setup Steps

### 1. Install Firebase CLI

```bash
npm install -g firebase-tools
```

### 2. Login to Firebase

```bash
firebase login
```

### 3. Initialize Firebase in Your Project

Navigate to your project directory:

```bash
cd "/Users/alexsweet/Documents/Swift experiment/nutribase copy"
firebase init
```

Select:
- ✅ Functions
- ✅ Firestore (for security rules)

Choose:
- Use existing project: Select your Nutribase project
- Language: JavaScript
- ESLint: No (optional)
- Install dependencies: Yes

### 4. Copy the Cloud Function Code

The function code is already in `firebase-functions/index.js`. Move it to the Firebase functions directory:

```bash
# If Firebase created a 'functions' folder
cp firebase-functions/index.js functions/index.js
cp firebase-functions/package.json functions/package.json
```

### 5. Deploy Firestore Security Rules

```bash
firebase deploy --only firestore:rules
```

This deploys the secure rules that:
- ❌ Block direct writes to `food_flags` collection
- ✅ Allow Cloud Functions to write
- ✅ Allow users to read their own flags

### 6. Deploy Cloud Functions

```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

This will deploy:
- `submitFoodFlag` - Handles flag submissions
- `getFlagStatistics` - Returns flag stats (admin only)
- `sendDailyFlagDigest` - Scheduled function for daily reports

### 7. Verify Deployment

After deployment, you'll see URLs like:
```
✔  functions[submitFoodFlag(us-central1)] https://us-central1-your-project.cloudfunctions.net/submitFoodFlag
```

The iOS app will automatically use these functions.

## Testing

### Test from iOS App

1. Build and run the app
2. Open any food item
3. Tap "⋯" menu → "Report Issue"
4. Submit a flag
5. Check Firebase Console → Firestore → `food_flags` collection

### Test Locally (Optional)

```bash
cd functions
npm run serve
```

This starts the Firebase emulator for local testing.

## Security Rules Explained

```javascript
match /food_flags/{flagId} {
  // Users can read their own flags
  allow read: if request.auth.uid == resource.data.userId;
  
  // NO direct writes - Cloud Functions only
  allow write: if false;
}
```

This means:
- ✅ Users can see flags they submitted
- ❌ Users cannot create/edit/delete flags directly
- ✅ Only Cloud Functions can write to this collection

## Rate Limiting

The Cloud Function includes built-in rate limiting:
- **10 flags per user per 24 hours**
- Prevents spam and abuse
- Configurable in `index.js`

## Monitoring

### View Logs

```bash
firebase functions:log
```

### View in Firebase Console

1. Go to Firebase Console
2. Functions → Logs
3. See all function invocations and errors

## Cost Estimate

Firebase Cloud Functions pricing (Blaze plan required):
- **First 2 million invocations/month**: FREE
- **After that**: $0.40 per million invocations

For a food flagging system, you'll likely stay within the free tier unless you have thousands of daily users.

## Admin Dashboard Access

To view all flags, you can:

### Option 1: Firebase Console
1. Go to Firestore Database
2. Open `food_flags` collection
3. Filter by `status == "pending"`

### Option 2: Python Script (from FOOD_FLAG_ADMIN_GUIDE.md)
```python
# Uses Firebase Admin SDK to query flags
python review_food_flags.py
```

### Option 3: Web Dashboard (Future)
Build a simple admin web app that calls `getFlagStatistics` function.

## Troubleshooting

### Error: "Missing or insufficient permissions"
- ✅ **Solution**: Deploy Firestore rules: `firebase deploy --only firestore:rules`

### Error: "Function not found"
- ✅ **Solution**: Deploy functions: `firebase deploy --only functions`

### Error: "CORS error"
- ✅ **Solution**: Cloud Functions automatically handle CORS for callable functions

### Error: "Billing account required"
- ✅ **Solution**: Upgrade to Blaze plan (still free tier available)

## Optional Enhancements

### 1. Email Notifications

Add to `index.js`:
```javascript
const nodemailer = require('nodemailer');

async function sendAdminNotification(flagData) {
  const transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: {
      user: 'your-email@gmail.com',
      pass: 'your-app-password'
    }
  });

  await transporter.sendMail({
    from: 'nutribase@yourdomain.com',
    to: 'admin@yourdomain.com',
    subject: `New Food Flag: ${flagData.foodName}`,
    text: `
      Food: ${flagData.foodName}
      Issue: ${flagData.issueType}
      Details: ${flagData.details}
    `
  });
}
```

### 2. Slack Notifications

```javascript
const axios = require('axios');

async function sendSlackNotification(flagData) {
  await axios.post('YOUR_SLACK_WEBHOOK_URL', {
    text: `🚩 New food flag: ${flagData.foodName} - ${flagData.issueType}`
  });
}
```

### 3. Auto-moderation

Add logic to automatically resolve obvious duplicates or spam.

## Next Steps

1. ✅ Deploy Firestore rules
2. ✅ Deploy Cloud Functions
3. ✅ Test flag submission from app
4. ✅ Set up monitoring/notifications (optional)
5. ✅ Review flags regularly using admin tools

## Support

If you encounter issues:
1. Check Firebase Console logs
2. Run `firebase functions:log`
3. Verify Firestore rules are deployed
4. Ensure billing is enabled (Blaze plan)
