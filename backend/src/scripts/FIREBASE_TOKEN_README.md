# Generate Firebase Token for Postman Testing

This script generates a Firebase ID token that you can use to test Google login in Postman.

## Prerequisites

1. **Firebase Admin credentials** in your `.env` file:
   ```
   FIREBASE_PROJECT_ID=your-project-id
   FIREBASE_CLIENT_EMAIL=your-service-account@project.iam.gserviceaccount.com
   FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
   ```

2. **Firebase Web API Key** (optional but recommended):
   ```
   FIREBASE_API_KEY=your-web-api-key
   ```
   
   You can find this in Firebase Console → Project Settings → General → Web API Key

## Usage

### Basic Usage

```bash
npm run generate:firebase-token <email> [role]
```

Or directly:
```bash
node src/scripts/generateFirebaseToken.js <email> [role]
```

### Examples

**Generate token for owner:**
```bash
npm run generate:firebase-token test@example.com owner
```

**Generate token for sitter:**
```bash
npm run generate:firebase-token test@example.com sitter
```

**Without role (defaults to owner):**
```bash
npm run generate:firebase-token test@example.com
```

## What the Script Does

1. ✅ Initializes Firebase Admin SDK
2. ✅ Creates or gets a Firebase user with the specified email
3. ✅ Generates a custom token
4. ✅ Exchanges it for an ID token (if FIREBASE_API_KEY is set)
5. ✅ Displays the token and Postman request details

## Output

The script will display:
- ✅ Firebase ID token (copy this for Postman)
- 📝 Complete Postman request details (method, URL, headers, body)
- ⏰ Token expiration reminder (tokens expire in 1 hour)

## Using in Postman

1. **Copy the Firebase ID token** from the script output

2. **Create a new POST request:**
   - **Method:** `POST`
   - **URL:** `http://localhost:5000/auth/google`
   - **Headers:**
     ```
     Content-Type: application/json
     ```
   - **Body (raw JSON):**
     ```json
     {
       "idToken": "PASTE_TOKEN_HERE",
       "role": "owner"
     }
     ```

3. **Send the request** - You'll get back a JWT token and user data

## Notes

- ⏰ **Token expires in 1 hour** - Generate a new one when needed
- 🔄 **Role parameter**: Only required for new users. If user exists, role is ignored
- 📧 **Email**: The script will create the user in Firebase if it doesn't exist
- 🔑 **API Key**: If `FIREBASE_API_KEY` is not set, the script will show a custom token instead. You'll need to exchange it manually using Firebase client SDK.

## Troubleshooting

**Error: Firebase Admin environment variables are not configured**
- Make sure your `.env` file has `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, and `FIREBASE_PRIVATE_KEY`

**Error: Failed to exchange token**
- Make sure `FIREBASE_API_KEY` is set in your `.env` file
- Verify the API key is correct in Firebase Console

**Token doesn't work in Postman**
- Check that the token hasn't expired (1 hour limit)
- Make sure you're using the ID token (not the custom token)
- Verify your backend server is running

## Alternative: Manual Token Exchange

If you don't have `FIREBASE_API_KEY` set, you can:

1. Use the custom token shown by the script
2. In a browser console or React Native app, use Firebase client SDK:
   ```javascript
   import { signInWithCustomToken, getIdToken } from 'firebase/auth';
   
   signInWithCustomToken(auth, customToken)
     .then((userCredential) => {
       return getIdToken(userCredential.user);
     })
     .then((idToken) => {
       console.log('ID Token:', idToken);
       // Use this in Postman
     });
   ```
