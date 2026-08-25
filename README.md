# CoreGym - Smart Fitness & Nutrition Tracker

<div align="center">
  <img src="assets/images/coregym_logo.png" alt="CoreGym Logo" width="120"/>
  <p>
    <strong>CoreGym</strong> — Your intelligent fitness companion with AI-powered workout generation and nutrition tracking
  </p>
  <p>
    <img src="https://img.shields.io/badge/Flutter-02569B?style=flat-square&logo=flutter" alt="Flutter">
    <img src="https://img.shields.io/badge/Supabase-3ECF8E?style=flat-square&logo=supabase" alt="Supabase">
    <img src="https://img.shields.io/badge/Platform-Android-green?style=flat-square" alt="Android">
    <img src="https://img.shields.io/badge/Platform-iOS-blue?style=flat-square" alt="iOS">
  </p>
</div>

---

## Overview

**CoreGym** is a comprehensive fitness and nutrition application built with Flutter and Supabase. It combines AI-powered workout generation, smart food logging (photo, voice, and barcode), wearable health-data sync, and a built-in coach marketplace with chat and subscriptions into one all-in-one platform.

The app supports **English and Arabic** out of the box with full RTL support.

---

## Features

### 1. AI Smart Trainer

Generates personalized workout plans based on:

- **Mood Selection** — Choose from 5 energy levels (Tired → Full Power) to adjust workout intensity
- **Target Muscles** — Multi-select from 8 muscle groups (Chest, Back, Shoulders, Biceps, Triceps, Legs, Abs, Cardio)
- **Duration** — Select workout length (30, 45, 60, or 90 minutes)

The generator automatically selects exercises from a library of 48+ exercises, adjusts sets/reps/rest times based on mood, includes warm-ups, and provides motivational messages.

### 2. Workout Tracking

- **Exercise Library** — Browse exercises by muscle group with YouTube video tutorials
- **My Program** — View and start your active workout program
- **Programs Library** — Preset training programs (Push Pull Legs, Upper/Lower, Full Body, Bro Split)
- **Detailed Logging** — Log sets, weights, reps, and durations during workouts
- **Rest Timer** — Built-in countdown timer between sets
- **Streaks** — Track workout streaks with badges

### 3. Nutrition Tracking

- **Daily Macros Dashboard** — Track calories, protein, carbs, and fat against your goals with animated rings
- **Food Search** — Search a seeded food database plus user-created custom foods
- **Meal Categorization** — Breakfast, Lunch, Dinner, Snacks
- **Weekly History** — Past 7 days of nutrition data with charts

#### Smart Food Logging (AI)

| Method | How it works |
|--------|--------------|
| **Photo Scan** | Snap a picture of your meal — Gemini vision analyzes it and estimates weight, calories, and macros |
| **Voice Logging** | Describe your meal by voice — Gemini understands the audio directly (no separate speech-to-text step) and extracts food items with nutrition |
| **Barcode Scan** | Scan any product barcode for instant nutrition lookup |

All three flows save directly to Supabase via Edge Functions.

### 4. Health & Wearable Integration

Syncs automatically with **Apple HealthKit** (iOS / Apple Watch) and **Google Health Connect** (Android / Galaxy Watch, Pixel Watch, Garmin, etc.) through the unified `health` package:

- Step count toward daily goals
- Active & total calories burned
- Heart rate (real-time and resting average)
- Workout minutes and exercise sessions

Activity is synced to the `daily_activity` table and surfaced on the home dashboard and progress analytics. See [HEALTH_INTEGRATION.md](HEALTH_INTEGRATION.md) for platform setup details.

### 5. Progress & Analytics

- **Body Measurements** — Track weight, body fat %, and key metrics over time
- **1RM / Personal Records** — Best weight per exercise, tracked automatically
- **Workout History** — Completed sessions with full set logs
- **Volume Tracking** — Total training volume per session
- **Weekly Charts** — Calories, steps, and workouts with goal percentages

### 6. Coach Marketplace

A two-sided marketplace connecting members with fitness coaches:

- **Coach Registration & Onboarding** — Coaches create profiles, add media/certifications, and publish their services
- **Coach Marketplace** — Members browse coach profiles and details
- **Coach Dashboard** — Client management, client data views, and earnings stats
- **Client Assignment** — Coaches can view client progress data

### 7. Chat & Notifications

- **Real-time Chat** — Messaging between members and coaches (Supabase Realtime)
- **Unread Counters** — Per-conversation and global unread message counts
- **Notification Center** — In-app notifications list

### 8. Subscriptions & Payments

Stripe-powered subscriptions for premium/coach services:

- Secure checkout via Stripe Checkout Sessions
- Webhook-driven subscription status updates
- Subscription status verification endpoint

### 9. Profile & Goals

- **Onboarding Flow** — Multi-step setup (personal info, body metrics with live BMI, goals, activity level, targets)
- **TDEE-based Targets** — Automatic calorie/macro calculation from BMR × activity level, adjusted for goal
- **Profile Management** — Age, weight, height, gender, avatar, fitness goal
- **Authentication** — Email/password and Google Sign-In

---

## Tech Stack

| Component | Technology |
|-----------|------------|
| **Framework** | Flutter 3.8+ / Dart 3.8+ |
| **Backend** | Supabase (PostgreSQL, Auth, Storage, Realtime, Edge Functions) |
| **Payments** | Stripe (Checkout + webhooks) |
| **AI** | Google Gemini (vision + audio food analysis) |
| **State Management** | Provider + Riverpod |
| **Charts** | fl_chart |
| **Health Data** | health (HealthKit / Health Connect) |
| **Media** | youtube_player_flutter, image_picker, record, mobile_scanner, photo_view |
| **Localization** | flutter_localizations + intl (EN / AR) |
| **Fonts** | google_fonts |

---

## Project Structure

```
lib/
├── main.dart                        # App entry point (Supabase init, providers)
├── fitness_home_pages.dart          # Home screen with daily summary
├── login_sign_up.dart               # Authentication screens
├── profile.dart                     # User profile & settings
├── progrems.dart                    # Programs browsing
├── splashscreen.dart                # Splash screen + auth/onboarding routing
├── gender.dart                      # Gender selection
├── forgetpassword.dart              # Password recovery
│
├── l10n/                            # Localization (ARB files: EN, AR)
├── theme/                           # Colors & typography
├── providers/                       # Locale + profile state (Provider)
│
├── screens/                         # Main app screens
│   ├── onboarding_flow.dart         # New user onboarding
│   ├── nutrition_screen.dart        # Nutrition tracking
│   ├── food_scan_screen.dart        # AI photo food scanner
│   ├── voice_food_log_screen.dart   # AI voice food logging
│   ├── barcode_scan_screen.dart     # Barcode scanner
│   ├── workout_screen.dart          # Workout tab container
│   ├── workout_tabs/                # Log workout / my program / programs library
│   ├── active_workout_sheet.dart    # Live workout session sheet
│   ├── exercise_detail_sheet.dart   # Exercise details + set logging
│   ├── progress_screen.dart         # Progress & analytics
│   └── fitness_coach_screen.dart    # AI workout generator
│
├── features/
│   ├── coach/                       # Coach marketplace (Clean Architecture)
│   │   ├── domain/                  # Entities + repository interfaces
│   │   ├── data/                    # Repository implementations
│   │   └── presentation/            # Screens, providers (Riverpod)
│   ├── health/                      # HealthKit / Health Connect integration
│   └── notifications/               # Notification center UI
│
├── chat/                            # Real-time chat (Clean Architecture)
│   ├── domain/                      # Entities + repositories
│   ├── data/                        # Models + repositories (Supabase Realtime)
│   └── presentation/                # Chat list, chat room, providers
│
├── models/                          # Food scan / barcode / voice log results
├── services/                        # Business logic (auth, workouts, nutrition,
│                                    # stats, measurements, onboarding, health,
│                                    # food scan, barcode, voice log, plan gen)
├── supabase/                        # Supabase config + legacy services
└── widgets/                         # Reusable components (navbar, charts, sheets)
```

---

## Supabase Backend

### Database Schema (main tables)

- `profiles` — User profile data (weight, height, goals)
- `onboarding` — Onboarding answers per user
- `user_goals` — Daily targets (calories, protein, steps)
- `daily_summary` — One row per user per day (auto-updated by triggers)
- `nutrition_logs` — Food entries per meal per day
- `foods` — Food database (seeded + custom)
- `food_scans` — AI photo scan results
- `voice_food_logs` / `voice_food_log_items` — Voice logging results
- `workout_sessions` / `workout_sets` — Workout records
- `body_measurements` — Body metric history
- `daily_activity` — Health-synced steps/calories/heart rate
- `weekly_activity`, `streaks` — Activity charting and streaks
- `coach_profiles`, `coach_media`, `client_assignments` — Coach marketplace
- `conversations`, `messages` — Chat
- `subscriptions` — Stripe subscription state
- `notifications` — In-app notifications

Views: `weekly_progress`, `weight_progress`, `personal_records`

Migrations live in [`supabase/migrations/`](supabase/migrations/).

### Edge Functions ([`supabase/functions/`](supabase/functions/))

| Function | Purpose |
|----------|---------|
| `analyze-food` | Gemini vision analysis of meal photos |
| `log-food-voice` | Gemini audio analysis; uploads audio + saves logs server-side |
| `lookup-barcode` | Product lookup by barcode |
| `create-checkout-session` | Create Stripe Checkout session |
| `stripe-webhook` | Sync subscription state from Stripe events |
| `get-subscription-status` | Verify current subscription |

Deploy functions:

```bash
supabase functions deploy analyze-food
supabase functions deploy log-food-voice
# ...etc
```

Required secrets include `GEMINI_API_KEY` and Stripe keys.

---

## Installation

### Prerequisites

- Flutter SDK >= 3.8.0
- A Supabase project with migrations applied
- Deployed Edge Functions (for AI features and payments)

### Setup

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd coregymali
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Supabase**
   - Create a project at [supabase.com](https://supabase.com)
   - Apply the SQL migrations from `supabase/migrations/`
   - Set credentials in `lib/supabase/supabase_config.dart`

4. **Configure Edge Function secrets**
   ```bash
   supabase secrets set GEMINI_API_KEY=<your-key>
   ```

5. **Run the app**
   ```bash
   flutter run
   ```

---

## Localization

The app is fully localized into **English** and **Arabic** (with RTL layout switching). To add a new language:

1. Create a new ARB file in `lib/l10n/` (e.g., `app_fr.arb`)
2. Add the locale to `supportedLocales` in `lib/main.dart`
3. Run `flutter gen-l10n` to regenerate localization files

---

## Building for Production

### Android
```bash
flutter build apk --release
```

### iOS
```bash
flutter build ios --release
```

> **Note:** Health integration requires the HealthKit capability (iOS) and Health Connect permissions declared in `AndroidManifest.xml` (Android). See [HEALTH_INTEGRATION.md](HEALTH_INTEGRATION.md).

---

## Additional Documentation

- [HEALTH_INTEGRATION.md](HEALTH_INTEGRATION.md) — Wearable/health data sync architecture and platform permissions
- [VOICE_FOOD_LOG_SUPABASE_SETUP.md](VOICE_FOOD_LOG_SUPABASE_SETUP.md) — Voice food logging database schema and wiring guide
- [MIGRATE_TO_SUPABASE.md](MIGRATE_TO_SUPABASE.md) — Backend migration notes

---

## License

This project is proprietary and confidential. All rights reserved.
