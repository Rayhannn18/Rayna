# Rayna

Rayna is a private Flutter application for couples in long-distance relationships.

## Current MVP

- Firebase Authentication
- Unique case-insensitive usernames
- Username search and connection requests
- Accept/reject pairing requests
- Private pair documents and access rules
- Photo upload from camera or gallery
- Captions and upload status
- Private Moments timeline
- Mood check-in with optional notes
- Local random sharing reminders
- Firestore and Storage security rules

Server push notifications and Firebase Cloud Functions are intentionally deferred because this project is being developed without the Firebase Blaze plan. Local reminders do not require Blaze.

## Development

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
```

Enable Email/Password Authentication, Firestore, and Storage in Firebase Console. Then deploy only the rules while remaining on Spark:

```powershell
firebase use closer-3e8d7
firebase deploy --only firestore:rules
firebase deploy --only storage
```

Do not deploy `functions` unless the project is intentionally upgraded to Blaze and the Functions runtime has been reviewed.

## Release warning

The Android release build currently uses debug signing. Configure a private release keystore and signing properties before distributing an APK or publishing to Google Play.
