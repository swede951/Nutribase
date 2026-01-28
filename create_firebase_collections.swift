#!/usr/bin/env swift

// Test script to create Firebase collections for debugging
// This will help identify why only weight_logs collection exists

import Foundation

print("🔥 Firebase Collections Test Script")
print("===================================")

// Simulate the data structures that should be created

print("\n📋 Expected Firebase Collections:")
print("1. users/{userId}/profile/settings - User profile data")
print("2. users/{userId}/weight_logs/{entryId} - Weight log entries") 
print("3. users/{userId}/weight_phases/{phaseId} - Weight phases")

print("\n🔍 Current Status:")
print("✅ weight_logs collection exists (visible in Firebase console)")
print("❌ profile collection missing")
print("❌ weight_phases collection missing")

print("\n🛠️ Troubleshooting Steps:")
print("1. Check if user is properly authenticated")
print("2. Verify Firebase services are being called")
print("3. Check if profile/phase data is being saved")
print("4. Look for Firebase console errors")

print("\n📝 Sample Data Structures:")

print("\n--- Profile Data ---")
let profileData = [
    "height_cm": 175.0,
    "weight_kg": 70.0,
    "age": 30,
    "gender": "male",
    "activity_level": "moderate",
    "calorie_target": 2000,
    "protein_percentage": 25.0,
    "carb_percentage": 45.0,
    "fat_percentage": 30.0
]
print(profileData)

print("\n--- Weight Phase Data ---")
let phaseData = [
    "name": "Cut Phase",
    "description": "Losing weight for summer",
    "start_date": "2025-01-01T00:00:00Z",
    "end_date": "2025-06-01T00:00:00Z", 
    "target_weekly_rate": -0.5,
    "color": "#FF5722",
    "notes": "Focus on cardio"
]
print(phaseData)

print("\n🎯 Next Actions:")
print("1. Sign in to the app to trigger profile creation")
print("2. Add some weight data to trigger weight_logs")
print("3. Create a weight phase to trigger weight_phases collection")
print("4. Check Firebase console for all three collections")

print("\n✅ Script completed")
