#!/usr/bin/env python3
"""
Apple Sign In JWT Generator for Nutribase
Generates the JWT secret key needed for Supabase Apple authentication
"""

import jwt
import time
from datetime import datetime, timedelta

# Your Apple Developer information
TEAM_ID = "37TLI6F9HL"
KEY_ID = "87KGVWFJ4J"
CLIENT_ID = "Nutribase"  # Your app bundle identifier

# Private key content from your AuthKey_87KGVWFJ4J.p8 file
PRIVATE_KEY = """-----BEGIN PRIVATE KEY-----
MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQgHLDKGHCTU
P5SXYqbTZQKTXmr7ZBPSqHYqgCPXmZZIrGQNANKAKXAR8fQF3PTqYE
9KQMYhYZQKmXmrRhZbIAM5RkLtCJlmEBKcNqJkrGS3rHUqKyIMLdBRKrZ
-----END PRIVATE KEY-----"""

def generate_apple_jwt():
    """Generate JWT for Apple Sign In"""
    
    # Current time
    now = datetime.utcnow()
    
    # JWT Header
    headers = {
        "alg": "ES256",
        "kid": KEY_ID
    }
    
    # JWT Payload
    payload = {
        "iss": TEAM_ID,
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(hours=1)).timestamp()),  # Expires in 1 hour
        "aud": "https://appleid.apple.com",
        "sub": CLIENT_ID
    }
    
    # Generate JWT
    try:
        token = jwt.encode(payload, PRIVATE_KEY, algorithm="ES256", headers=headers)
        return token
    except Exception as e:
        print(f"Error generating JWT: {e}")
        return None

if __name__ == "__main__":
    print("🍎 Apple Sign In JWT Generator for Nutribase")
    print("=" * 50)
    
    # Generate the JWT
    jwt_token = generate_apple_jwt()
    
    if jwt_token:
        print("✅ JWT Generated Successfully!")
        print("\n📋 Copy this JWT and paste it into Supabase 'Secret Key (for OAuth)' field:")
        print("-" * 80)
        print(jwt_token)
        print("-" * 80)
        print("\n💡 This token expires in 1 hour. If you need a new one, run this script again.")
        print("\n🔧 Next steps:")
        print("1. Copy the JWT token above")
        print("2. Go to your Supabase dashboard")
        print("3. Paste it in the 'Secret Key (for OAuth)' field")
        print("4. Save the Apple provider configuration")
        print("5. Test Apple Sign In on a physical iOS device")
    else:
        print("❌ Failed to generate JWT. Please check your private key format.")
