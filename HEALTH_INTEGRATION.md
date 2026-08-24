# CoreGym Smartwatch & Health Integration Guide

CoreGym connects seamlessly with **Apple HealthKit** (iOS / Apple Watch) and **Google Health Connect** (Android / Samsung Galaxy Watch, Pixel Watch, Huawei, Xiaomi, Garmin, etc.) through the unified `health` Dart package.

---

## 1. Data Types & Permissions

CoreGym requests **Read** permissions for the following health metrics:

| Metric | HealthKit (iOS) | Health Connect (Android) | Purpose in CoreGym |
|---|---|---|---|
| **Step Count** | `HKQuantityTypeIdentifierStepCount` | `READ_STEPS` | Track daily walking & running steps toward 10,000 goal |
| **Active Calories** | `HKQuantityTypeIdentifierActiveEnergyBurned` | `READ_ACTIVE_CALORIES_BURNED` | Measure calories burned through movement and exercise |
| **Total Calories** | `HKQuantityTypeIdentifierBasalEnergyBurned` | `READ_TOTAL_CALORIES_BURNED` | Calculate total daily caloric expenditure |
| **Heart Rate** | `HKQuantityTypeIdentifierHeartRate` | `READ_HEART_RATE` | Display real-time & resting average BPM |
| **Workout / Exercise** | `HKWorkoutTypeIdentifier` | `READ_EXERCISE` | Count active workout minutes & sports sessions |

---

## 2. Platform Setup Details

### iOS Configuration
- **Permissions defined in `ios/Runner/Info.plist`**:
  - `NSHealthShareUsageDescription`: Explains why CoreGym reads steps, calories, heart rate, and workouts.
  - `NSHealthUpdateUsageDescription`: Allows writing completed CoreGym workouts back to Apple Health.
- **Xcode Capability**:
  - `HealthKit` capability enabled in `Runner.xcodeproj`.
  - Supports Apple Watch background sync via Apple Health.

### Android Configuration
- **Permissions declared in `android/app/src/main/AndroidManifest.xml`**:
  - `android.permission.health.READ_STEPS`
  - `android.permission.health.READ_ACTIVE_CALORIES_BURNED`
  - `android.permission.health.READ_TOTAL_CALORIES_BURNED`
  - `android.permission.health.READ_HEART_RATE`
  - `android.permission.health.READ_EXERCISE`
  - `android.permission.ACTIVITY_RECOGNITION`
- **Health Connect Declarations**:
  - Added `<activity-alias android:name="ViewPermissionUsageActivity" ...>` for Android 14+ permission rationale.
  - Added package visibility query for `com.google.android.apps.healthdata`.
- **Minimum SDK**: Set to `minSdk = 26` (Android 8.0+ Oreo) in `android/app/build.gradle.kts`.

---

## 3. Architecture & Data Flow

```
[Smartwatch (Apple / Samsung / Garmin)]
                  │
                  ▼
[Apple HealthKit (iOS) / Health Connect (Android)]
                  │ (health package)
                  ▼
     [HealthService (Data Layer)]
                  │
        ┌─────────┴─────────┐
        ▼                   ▼
[Riverpod State]    [Supabase (Backend)]
(todayActivity)     (daily_activity table)
        │                   │
        ▼                   ▼
[TodayActivityCard] [Progress & History]
 (Home Dashboard)     (Analytics Views)
```

---

## 4. Supabase Database Schema

Activity is synced to the `daily_activity` table:

```sql
daily_activity (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  activity_date date not null default current_date,
  steps integer not null default 0,
  active_calories_burned numeric not null default 0,
  heart_rate_avg numeric,
  exercise_minutes numeric,
  source text default 'health_connect', -- 'healthkit' on iOS, 'health_connect' on Android
  synced_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (user_id, activity_date)
)
```

---

## 5. Testing & Verification

1. **Testing on iOS**:
   - Must run on a physical iPhone / Apple Watch.
   - Open Apple Health app > Sharing > Apps > CoreGym > Turn All Categories On.
2. **Testing on Android**:
   - Install **Google Health Connect** from Play Store (built into Settings on Android 14+).
   - Link your smartwatch companion app (Samsung Health, Google Fit, Zepp, etc.) to Health Connect.
   - Grant CoreGym read permissions when prompted in the app.
