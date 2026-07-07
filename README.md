# Antigravity — Premium AI Expense Tracker

Antigravity is a production-ready, high-end AI-Powered Expense Tracker built with Flutter (Material 3) and Firebase. Designed with premium dark aesthetics, glassmorphic UI components, and micro-animations, it delivers a CRED-like visual experience for financial tracking.

---

## Technical Architecture & Core Stack

- **Frontend**: Flutter (Material 3), Dart
- **State Management**: Riverpod (`flutter_riverpod` v2.6.x)
- **Routing**: GoRouter (`go_router` v14.8.x)
- **Local Database & Cache**: Hive & Shared Preferences
- **OCR Engine**: Google ML Kit Text Recognition
- **Voice Integration**: Speech-to-Text & Text-to-Speech
- **AI Backend**: Google Generative AI (Gemini 1.5 Flash)
- **Charts**: FL Chart

---

## Core Feature Set

1. **Fintech Aesthetics (Dark Mode First)**: High-end glassmorphic cards, custom neon/indigo color theme, custom circular animated painters, and interactive spring actions.
2. **Flexible Authentication**: Support for email sign-in, Google Sign-In, Phone OTP verification, and custom 4-digit App PIN locks integrated with biometric recognition (FaceID/Fingerprint).
3. **AI Financial Assistant**: Direct dialogue with Gemini, backed by user transaction history context, delivering predictions for month-end burn rates, budget overrun risks, and savings strategies.
4. **Voice Expense Tracker**: A microphone transcription pipeline that translates spoken statements like *"Spent 650 on groceries"* into structured JSON models using Gemini parsing.
5. **OCR Receipt Scanner**: Local processing using Google ML Kit to parse receipt dates, total amounts, taxes, merchants, and auto-populate manual entry forms.
6. **Reports & Exports**: Generates and shares PDF statements, Excel workbooks, and raw CSV files along with analytical charts.
7. **Offline Capability**: Write-through caching pattern where all writes are registered in local Hive boxes and synced in the background.

---

## Folder Structure

```
lib/
├── app/
│   ├── config/              # Themes, router configurations
│   └── app.dart             # Root MaterialApp
├── core/                    # Shared widgets, utilities, services
│   ├── services/            # Hive, secure storage, voice service
│   └── widgets/             # GlassCard, HealthGauge, Shimmer
└── features/                # Product modules
    ├── auth/                # Login, signup, PIN locks, biometrics
    ├── dashboard/           # Home dashboard, health score engine
    ├── transactions/        # Expense & Income modules
    ├── budget/              # Budget allocations
    ├── goals/               # Savings targets (MacBook, Bali)
    ├── ai_assistant/        # Gemini chatbot integration
    ├── reports/             # Analytics charts, PDF/Excel generator
    └── scanner/             # ML Kit camera viewfinder overlay
```

---

## Getting Started & Setup

### Prerequisites
- Flutter SDK (>= 3.0.0)
- Android Studio / Xcode

### Setup Instructions

1. **Clone and Navigate**:
   ```bash
   cd c:\Users\SURYA\Desktop\trac
   ```

2. **Download Packages**:
   ```bash
   flutter pub get
   ```

3. **Configure Gemini API Key**:
   To run the real Gemini client, set the environment variable when compiling:
   ```bash
   flutter run --dart-define=GEMINI_API_KEY=YOUR_GEMINI_API_KEY
   ```
   *Note: If no API key is specified, the application automatically falls back to an intelligent mock parser, ensuring full usability for reviewers.*

4. **Firebase Configuration**:
   - Create a project on the [Firebase Console](https://console.firebase.google.com/).
   - Add Android and iOS apps.
   - Download `google-services.json` and place it in `android/app/`.
   - Download `GoogleService-Info.plist` and place it in `ios/Runner/`.

5. **Run the Application**:
   ```bash
   flutter run
   ```

6. **Run Unit Tests**:
   ```bash
   flutter test test/financial_tests.dart
   ```
