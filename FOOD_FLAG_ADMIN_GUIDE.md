# Food Flag Admin Guide

## Overview
Users can now report incorrect food information directly from the app. All reports are stored in Firebase Firestore under the `food_flags` collection.

## Accessing Flagged Foods

### Option 1: Firebase Console (Easiest)

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your Nutribase project
3. Navigate to **Firestore Database**
4. Open the `food_flags` collection
5. Filter by `status == "pending"` to see unreviewed flags

### Option 2: Python Script (Recommended)

Create a file `review_food_flags.py`:

```python
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime

# Initialize Firebase Admin SDK
cred = credentials.Certificate("path/to/serviceAccountKey.json")
firebase_admin.initialize_app(cred)

db = firestore.client()

def get_pending_flags():
    """Get all pending food flags"""
    flags_ref = db.collection('food_flags')
    query = flags_ref.where('status', '==', 'pending').order_by('createdAt', direction=firestore.Query.DESCENDING)
    
    flags = query.stream()
    
    print("\n" + "="*80)
    print("PENDING FOOD FLAGS")
    print("="*80 + "\n")
    
    flag_list = []
    for flag in flags:
        flag_data = flag.to_dict()
        flag_data['id'] = flag.id
        flag_list.append(flag_data)
        
        print(f"Flag ID: {flag.id}")
        print(f"Food: {flag_data.get('foodName')} ({flag_data.get('brand', 'No brand')})")
        print(f"Barcode: {flag_data.get('barcode', 'N/A')}")
        print(f"Issue: {flag_data.get('issueType')}")
        print(f"Details: {flag_data.get('details', 'No details provided')}")
        print(f"Reported: {flag_data.get('createdAt')}")
        print(f"Food ID (Typesense): {flag_data.get('foodId')}")
        print("-" * 80 + "\n")
    
    return flag_list

def resolve_flag(flag_id, resolution_notes=""):
    """Mark a flag as resolved"""
    db.collection('food_flags').document(flag_id).update({
        'status': 'resolved',
        'reviewedAt': firestore.SERVER_TIMESTAMP,
        'resolutionNotes': resolution_notes
    })
    print(f"✅ Flag {flag_id} marked as resolved")

def dismiss_flag(flag_id, reason=""):
    """Mark a flag as dismissed"""
    db.collection('food_flags').document(flag_id).update({
        'status': 'dismissed',
        'reviewedAt': firestore.SERVER_TIMESTAMP,
        'resolutionNotes': reason
    })
    print(f"❌ Flag {flag_id} dismissed")

def get_flag_statistics():
    """Get statistics about flags"""
    flags_ref = db.collection('food_flags')
    all_flags = flags_ref.stream()
    
    stats = {
        'total': 0,
        'pending': 0,
        'resolved': 0,
        'dismissed': 0
    }
    
    for flag in all_flags:
        stats['total'] += 1
        status = flag.to_dict().get('status', 'pending')
        stats[status] = stats.get(status, 0) + 1
    
    print("\n" + "="*50)
    print("FLAG STATISTICS")
    print("="*50)
    print(f"Total Flags: {stats['total']}")
    print(f"Pending: {stats['pending']}")
    print(f"Resolved: {stats['resolved']}")
    print(f"Dismissed: {stats['dismissed']}")
    print("="*50 + "\n")
    
    return stats

def get_most_flagged_foods():
    """Get foods with multiple flags"""
    flags_ref = db.collection('food_flags')
    pending_flags = flags_ref.where('status', '==', 'pending').stream()
    
    food_counts = {}
    for flag in pending_flags:
        data = flag.to_dict()
        food_id = data.get('foodId')
        food_name = data.get('foodName')
        
        if food_id in food_counts:
            food_counts[food_id]['count'] += 1
        else:
            food_counts[food_id] = {
                'name': food_name,
                'count': 1
            }
    
    # Sort by count
    sorted_foods = sorted(food_counts.items(), key=lambda x: x[1]['count'], reverse=True)
    
    print("\n" + "="*50)
    print("MOST FLAGGED FOODS")
    print("="*50)
    for food_id, data in sorted_foods[:10]:
        if data['count'] > 1:
            print(f"{data['name']}: {data['count']} flags")
    print("="*50 + "\n")

# Interactive review
if __name__ == "__main__":
    print("\n🚩 Food Flag Review System\n")
    
    while True:
        print("\nOptions:")
        print("1. View pending flags")
        print("2. View statistics")
        print("3. View most flagged foods")
        print("4. Resolve a flag")
        print("5. Dismiss a flag")
        print("6. Exit")
        
        choice = input("\nSelect option (1-6): ")
        
        if choice == "1":
            get_pending_flags()
        elif choice == "2":
            get_flag_statistics()
        elif choice == "3":
            get_most_flagged_foods()
        elif choice == "4":
            flag_id = input("Enter flag ID to resolve: ")
            notes = input("Resolution notes (optional): ")
            resolve_flag(flag_id, notes)
        elif choice == "5":
            flag_id = input("Enter flag ID to dismiss: ")
            reason = input("Reason for dismissal (optional): ")
            dismiss_flag(flag_id, reason)
        elif choice == "6":
            print("Goodbye!")
            break
        else:
            print("Invalid option")
```

### Option 3: Simple Query Script

For quick checks, create `check_flags.py`:

```python
import firebase_admin
from firebase_admin import credentials, firestore

cred = credentials.Certificate("path/to/serviceAccountKey.json")
firebase_admin.initialize_app(cred)

db = firestore.client()

# Get count of pending flags
pending_count = len(list(db.collection('food_flags').where('status', '==', 'pending').stream()))
print(f"📊 Pending flags: {pending_count}")

# Get recent flags
recent = db.collection('food_flags').order_by('createdAt', direction=firestore.Query.DESCENDING).limit(5).stream()

print("\n🔔 Recent flags:")
for flag in recent:
    data = flag.to_dict()
    print(f"  • {data['foodName']} - {data['issueType']}")
```

## Workflow

### 1. Daily Check
Run the script to see if there are new flags:
```bash
python check_flags.py
```

### 2. Weekly Review
Review all pending flags:
```bash
python review_food_flags.py
```

### 3. Fix in Typesense
When you find a legitimate issue:

1. Note the **Food ID** from the flag
2. Go to your Typesense dashboard or use the API
3. Update the food document with correct information
4. Mark the flag as resolved in Firebase

### 4. Update Food in Typesense

Using Typesense API:
```bash
curl -X PATCH \
  'https://your-typesense-server.net/collections/foods/documents/{food_id}' \
  -H 'X-TYPESENSE-API-KEY: your-api-key' \
  -H 'Content-Type: application/json' \
  -d '{
    "calories": 100,
    "protein": 5,
    "carbs": 20,
    "fat": 2
  }'
```

## Flag Categories

Users can report:
- **Incorrect nutrition information** - Wrong macros/calories
- **Wrong serving sizes** - Serving size options are incorrect
- **Duplicate entry** - Same food appears multiple times
- **Misleading name or brand** - Wrong product name/brand
- **Missing information** - Incomplete data
- **Other issue** - Anything else

## Email Notifications (Optional)

Set up Firebase Cloud Functions to email you when flags are submitted:

```javascript
// functions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

admin.initializeApp();

exports.notifyFoodFlag = functions.firestore
  .document('food_flags/{flagId}')
  .onCreate(async (snap, context) => {
    const flag = snap.data();
    
    // Configure your email service
    const transporter = nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: 'your-email@gmail.com',
        pass: 'your-app-password'
      }
    });
    
    const mailOptions = {
      from: 'nutribase@yourdomain.com',
      to: 'admin@yourdomain.com',
      subject: `New Food Flag: ${flag.foodName}`,
      text: `
        Food: ${flag.foodName}
        Brand: ${flag.brand || 'N/A'}
        Issue: ${flag.issueType}
        Details: ${flag.details || 'No details'}
        Food ID: ${flag.foodId}
      `
    };
    
    await transporter.sendMail(mailOptions);
  });
```

## Analytics

Track flag patterns in Firebase Analytics:
- Which issue types are most common?
- Which foods get flagged most?
- How many flags per week?

This helps prioritize data quality improvements.

## Best Practices

1. **Respond quickly** - Review flags within 48 hours
2. **Verify before fixing** - Check multiple sources for correct data
3. **Thank users** - Consider adding a "thank you" notification system
4. **Track patterns** - If many users flag the same food, prioritize it
5. **Document changes** - Keep notes on what was fixed
6. **Batch updates** - Fix multiple issues in one Typesense update session

## Security Notes

- Never expose your Firebase service account key in the app
- Keep the Python scripts on your local machine or secure server
- Use Firebase Security Rules to prevent abuse
- Consider rate limiting (max 5 flags per user per day)

## Future Enhancements

- Web dashboard for easier review
- Automatic notifications via email/Slack
- Bulk actions (resolve multiple flags at once)
- User reputation system (trusted reporters)
- Integration with Typesense admin panel
