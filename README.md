# 💪 CoreGym — Smart Fitness & Nutrition Tracker

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
    <img src="https://img.shields.io/badge/Language-EN%20%7C%20AR-orange?style=flat-square" alt="Languages">
  </p>
</div>

---

## 🗺️ Table of Contents

- [What is CoreGym?](#-what-is-coregym)
- [Key Features](#-key-features)
  - [1. AI Smart Trainer](#1--ai-smart-trainer)
  - [2. Workout Tracking](#2--workout-tracking)
  - [3. Nutrition Tracking](#3--nutrition-tracking)
  - [4. Health & Wearable Integration](#4--health--wearable-integration)
  - [5. Progress & Analytics](#5--progress--analytics)
  - [6. Coach Marketplace](#6--coach-marketplace)
  - [7. Chat & Notifications](#7--chat--notifications)
  - [8. Subscriptions & Payments](#8--subscriptions--payments)
  - [9. Profile & Goals](#9--profile--goals)
- [Tech Stack](#️-tech-stack)
- [Project Structure](#-project-structure)
- [Supabase Backend](#️-supabase-backend)
- [Getting Started](#-getting-started)
- [FAQ](#-faq)
- [Localization](#-localization)
- [Building for Production](#-building-for-production)
- [Additional Documentation](#-additional-documentation)

---

## 🤔 What is CoreGym?

<details open>
<summary><strong>New here? Click for a plain-English explanation 👇</strong></summary>

<br/>

Picture having all of this in your pocket:

- A **personal trainer** who builds you a workout plan based on your mood and how much time you have.
- A **nutrition coach** who can look at a photo of your meal — or just listen to you describe it — and instantly calculate the calories, protein, and carbs.
- A **smart watch companion** that tracks your steps, heart rate, and calories burned.
- A **marketplace of real human coaches** you can message and subscribe to.

CoreGym brings all of that together in one app. It's built with **Flutter** (so the same code runs on both Android and iPhone), uses **Supabase** as its backend (database, login, and file storage), and uses Google's **Gemini AI** to understand food photos and voice descriptions.

The whole app works fully in both English and Arabic, including automatic right-to-left (RTL) layout switching.

</details>

---

## ✨ Key Features

### 1. 🤖 AI Smart Trainer

Generates a personalized workout plan based on three things you choose:

| You pick | What it controls |
|---|---|
| **Mood / Energy level** | 5 levels, from "Tired" to "Full Power" — adjusts workout intensity |
| **Target muscles** | Multi-select from 8 groups (Chest, Back, Shoulders, Biceps, Triceps, Legs, Abs, Cardio) |
| **Duration** | 30, 45, 60, or 90 minutes |

The generator then pulls exercises from a library of **48+ exercises**, adjusts sets/reps/rest times based on your mood, includes a warm-up, and adds a motivational message.

### 2. 🏋️ Workout Tracking

- **Exercise Library** — Browse exercises by muscle group with YouTube video tutorials
- **My Program** — View and start your active workout program
- **Programs Library** — Preset training programs (Push Pull Legs, Upper/Lower, Full Body, Bro Split)
- **Detailed Logging** — Log sets, weights, reps, and durations during workouts
- **Rest Timer** — Built-in countdown timer between sets
- **Streaks** — Track workout streaks with badges

### 3. 🍽️ Nutrition Tracking

- **Daily Macros Dashboard** — Calories, protein, carbs, and fat vs. your goals, with animated rings
- **Food Search** — A seeded food database plus foods you add yourself
- **Meal Categorization** — Breakfast, Lunch, Dinner, Snacks
- **Weekly History** — Past 7 days of nutrition data with charts

#### 🧠 Smart Food Logging (AI)

| Method | How it works |
|--------|--------------|
| **📷 Photo Scan** | Snap a picture of your meal — Gemini vision analyzes it and estimates weight, calories, and macros |
| **🎙️ Voice Logging** | Describe your meal by voice — Gemini understands the audio directly (no separate speech-to-text step) |
| **📊 Barcode Scan** | Scan any product barcode for instant nutrition lookup |

All three flows save directly to Supabase via Edge Functions.

### 4. ⌚ Health & Wearable Integration

Syncs automatically with:
- **Apple HealthKit** (iOS / Apple Watch)
- **Google Health Connect** (Android / Galaxy Watch, Pixel Watch, Garmin, etc.)

It pulls in step count, active & total calories burned, heart rate, and workout minutes. See [HEALTH_INTEGRATION.md](HEALTH_INTEGRATION.md) for platform setup details.

### 5. 📈 Progress & Analytics

- **Body Measurements** — Track weight, body fat %, and key metrics over time
- **1RM / Personal Records** — Best weight per exercise, tracked automatically
- **Workout History** — Completed sessions with full set logs
- **Volume Tracking** — Total training volume per session
- **Weekly Charts** — Calories, steps, and workouts with goal percentages

### 6. 🧑‍🏫 Coach Marketplace

A two-sided marketplace connecting members with fitness coaches:

- Coaches create profiles, add media/certifications, and publish their services
- Members browse coach profiles and details
- A coach dashboard shows client management, client data, and earnings stats
- Coaches can view client progress data

### 7. 💬 Chat & Notifications

- Real-time messaging between members and coaches (Supabase Realtime)
- Per-conversation and global unread message counters
- In-app notification center

### 8. 💳 Subscriptions & Payments

Stripe-powered subscriptions for premium/coach services:

- Secure checkout via Stripe Checkout Sessions
- Webhook-driven subscription status updates
- A subscription status verification endpoint

### 9. 👤 Profile & Goals

- **Onboarding Flow** — Multi-step setup (personal info, body metrics with live BMI, goals, activity level, targets)
- **TDEE-based Targets** — Automatic calorie/macro calculation from BMR × activity level, adjusted for your goal
- **Profile Management** — Age, weight, height, gender, avatar, fitness goal
- **Authentication** — Email/password and Google Sign-In

---

## 🛠️ Tech Stack

| Component | Technology | In plain terms |
|---|---|---|
| **Frontend** | Flutter 3.8+ / Dart 3.8+ | What you see on screen — same code runs on Android and iPhone |
| **Backend** | Supabase | Database + login + file storage + small server functions |
| **Payments** | Stripe | A secure, global payment gateway |
| **AI** | Google Gemini | Understands food photos and voice, and turns them into nutrition numbers |
| **State Management** | Provider + Riverpod | How the app organizes and shares its data internally |
| **Charts** | fl_chart | The library behind all the graphs |
| **Health Data** | health package | Bridges to HealthKit and Health Connect |
| **Media** | youtube_player_flutter, image_picker, record, mobile_scanner, photo_view | Video playback, picking photos, recording audio, scanning barcodes |
| **Localization** | flutter_localizations + intl | English and Arabic support |
| **Fonts** | google_fonts | Google's font library |

---

## 📁 Project Structure

<details>
<summary><strong>Click to view the full file tree</strong></summary>

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

</details>

---

## 🗄️ Supabase Backend

<details>
<summary><strong>Click to view the main database tables</strong></summary>

| Table | What it stores |
|---|---|
| `profiles` | User profile data (weight, height, goals) |
| `onboarding` | Onboarding answers per user |
| `user_goals` | Daily targets (calories, protein, steps) |
| `daily_summary` | One row per user per day (auto-updated by triggers) |
| `nutrition_logs` | Food entries per meal per day |
| `foods` | Food database (seeded + custom) |
| `food_scans` | AI photo scan results |
| `voice_food_logs` / `voice_food_log_items` | Voice logging results |
| `workout_sessions` / `workout_sets` | Workout records |
| `body_measurements` | Body metric history |
| `daily_activity` | Health-synced steps/calories/heart rate |
| `weekly_activity`, `streaks` | Activity charting and streaks |
| `coach_profiles`, `coach_media`, `client_assignments` | Coach marketplace |
| `conversations`, `messages` | Chat |
| `subscriptions` | Stripe subscription state |
| `notifications` | In-app notifications |

**Views:** `weekly_progress`, `weight_progress`, `personal_records`

Migrations live in [`supabase/migrations/`](supabase/migrations/).

</details>

<details>
<summary><strong>Click to view the Edge Functions (small server-side functions)</strong></summary>

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

</details>

---

## 🚀 Getting Started

> Even if you're new to development, just follow these steps in order.

**Before you start, make sure you have:**
- ✅ Flutter SDK >= 3.8.0
- ✅ A Supabase project with migrations applied
- ✅ Deployed Edge Functions (needed for AI features and payments)

### Step 1 — Clone the repository
```bash
git clone <repository-url>
cd coregymali
```

### Step 2 — Install dependencies
```bash
flutter pub get
```

### Step 3 — Configure Supabase
1. Create a project at [supabase.com](https://supabase.com)
2. Apply the SQL migrations from `supabase/migrations/`
3. Set your credentials in `lib/supabase/supabase_config.dart`

### Step 4 — Configure Edge Function secrets
```bash
supabase secrets set GEMINI_API_KEY=<your-key>
```

### Step 5 — Run the app
```bash
flutter run
```

---

## ❓ FAQ

<details>
<summary><strong>Does the app need an internet connection all the time?</strong></summary>
<br/>
Most features (photo/voice food scanning, chat, and health sync) rely on Supabase and Gemini, which run online — so most of the app requires an internet connection.
</details>

<details>
<summary><strong>Do I need to be a developer to just use the app?</strong></summary>
<br/>
No — as an end user you don't. To build or modify the code, though, you'll need basic Flutter/Dart experience and familiarity with Supabase.
</details>

<details>
<summary><strong>What's the difference between the AI Smart Trainer and the Coach Marketplace?</strong></summary>
<br/>
The AI Smart Trainer instantly generates a workout plan with no human involved. The Coach Marketplace connects you with a real human coach you can message and get personalized (paid) guidance from.
</details>

---

## 🌐 Localization

The app is fully localized into **English** and **Arabic** (with RTL layout switching). To add a new language:

1. Create a new ARB file in `lib/l10n/` (e.g., `app_fr.arb`)
2. Add the locale to `supportedLocales` in `lib/main.dart`
3. Run `flutter gen-l10n` to regenerate localization files

---

## 📦 Building for Production

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

## 📚 Additional Documentation

- [HEALTH_INTEGRATION.md](HEALTH_INTEGRATION.md) — Wearable/health data sync architecture and platform permissions
- [VOICE_FOOD_LOG_SUPABASE_SETUP.md](VOICE_FOOD_LOG_SUPABASE_SETUP.md) — Voice food logging database schema and wiring guide
- [MIGRATE_TO_SUPABASE.md](MIGRATE_TO_SUPABASE.md) — Backend migration notes

---

## 📄 License

This project is proprietary and confidential. All rights reserved.
