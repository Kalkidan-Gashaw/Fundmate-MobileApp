# FundMate

FundMate is a Flutter application that helps entrepreneurs connect with investors and mentors. It uses Firebase for authentication, Cloud Firestore for app data.

# Demo that is uploaded on youtube
https://youtu.be/TG7s19TbI7U

## Repository highlights
- `lib/` — main application source
	- `main.dart` — app entry and basic routing
	- authentication pages (login, signup, role selection)
	- Screens: individual screen files live in `lib/` root (for example: `entrepreneur_screen.dart`, `investor_screen.dart`, `mentor_screen.dart`, `chat_screen.dart`, `startup_detail_screen.dart`, `nda_sign_screen.dart`)
	- `services/` — backend helpers and business logic (chat_service, nda_service, storage_upload_service)
	- `widgets/` — reusable widgets and UI pieces
	- `theme/` — app theme and color extensions
- `android/`, `ios/`, `web/`, `windows/`, `linux/`, `macos/` — platform folders

## Prerequisites

- Flutter (stable) — follow https://flutter.dev/docs/get-started/install
- A Firebase project (for Auth, Firestore, Storage)

## Setup

1. Clone the repo and open it in your editor.
2. Install dependencies:

```bash
flutter pub get
```

3. Firebase configuration

- Follow `lib/FIREBASE_SETUP.md` for platform-specific Firebase setup steps.
- Ensure `lib/firebase_options.dart` is present (generated via `flutterfire` or populated with your Firebase options).

4. Add platform files (example):

- Android: place `google-services.json` in `android/app/`
- iOS: place `GoogleService-Info.plist` in `ios/Runner/`

> Do not commit private credentials to a public repository.

## Run

- Android emulator/device:

```bash
flutter run -d android
```

- iOS (macOS host):

```bash
flutter run -d ios
```

- Desktop (Windows/macOS/Linux):

```bash
flutter run -d windows
```

- Web (Chrome):

```bash
flutter run -d chrome
```

## Notes

- Firestore collections and expected document structure used by the app:

- `users`
	- fields: `name`, `email`, `role` (entrepreneur|investor|mentor), `createdAt`

- `startups`
	- fields: `name`, `sector`, `description`, `fundingNeeded` (int), `entrepreneurId`, `entrepreneurName` (optional), `interestedInvestors` (array), `createdAt`

- `mentorship_requests`
	- fields: `startupId`, `startupName`, `entrepreneurId`, `entrepreneurName`, `mentorId`, `mentorName`, `message`, `status` (pending|accepted|rejected), `createdAt`

- `nda_signatures`
	- fields: `investorId`, `investorName`, `investorEmail`, `signed` (bool), `signedAt`

- `chats` (each chat may have a `messages` subcollection)
	- chat doc fields: `chatType` (mentorship|investment), `participantIds`, `lastMessage`, `lastMessageAt`, `createdAt`, `unreadCounts`, etc.
	- messages subcollection fields: `type` (text|file), `text`, `fileUrl`, `fileName`, `senderId`, `senderName`, `createdAt`, `readBy`

- See `lib/services/chat_service.dart` and `lib/services/nda_service.dart` for exact usage patterns.

- There is a `lib/FIREBASE_SETUP.md` file with additional Firebase-specific instructions — consult it when configuring your project.


