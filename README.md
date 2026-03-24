# CoreGym

CoreGym is a comprehensive fitness and nutrition tracking app built with Flutter and Supabase. It provides advanced features for logging workouts, tracking calories and macros, exploring training programs, and monitoring your body progress over time.

## 🚀 Key Features

### 🏋️ Workout Tracking
* **Extensive Exercise Library:** A comprehensive list of exercises, organized by muscle groups (Chest, Back, Shoulders, Arms, Legs, Core, Full Body).
* **Rich Workout Programs:** Choose from preset programs tailored for different goals (Push Pull Legs, Upper/Lower, Full Body).
* **Detailed Logging:** Add sets, weight, and reps during your workouts. Calculates workout volume and dynamically updates muscle charts.
* **YouTube Integrations:** Direct links to exercise tutorials to learn perfect form.

### 🍽️ Nutrition & Diet
* **Daily Macros & Calories:** Track calories against your daily goals and view protein, carbs, and fat breakdown.
* **Food Database Search:** Quickly search our integrated database to find and log foods.
* **Meal Categorization:** Log your meals into distinct sections (Breakfast, Lunch, Dinner, Snacks) and track meal-specific macros.
* **Weekly History:** Beautifully animated progress rings and bar charts summarizing the past 7 days of consumption.

### 📈 Progress & Analytics
* **Muscle Engagement Heatmap:** Visualizes which muscle groups you've trained recently.
* **Body Measurements:** Keep a history of your weight, body fat %, and other key metrics.
* **Personal Bests:** Automatically updates and tracks your One Rep Max (1RM) and total training volume.

### 🎨 Premium UI/UX Design
* **Glassmorphic Navigation:** Beautifully blurred and modern Bottom Navigation Bar.
* **Dark Theme First:** Optimized for a sleek dark mode with high-contrast accent colors like Neon Green (#D4FF57).
* **Fluid Animations:** Snappy interactive cards, animated statistics, and satisfying haptic feedback entirely drive user engagement.

## 🛠️ Technology Stack

* **Frontend:** Flutter (Dart)
* **Backend:** Supabase (Database, Auth)
* **State Management & UI:** `fl_chart`, `youtube_player_flutter`, custom animations using `AnimationController`.

## 📦 Getting Started

### Prerequisites
* Flutter SDK (`>=3.8.0`)
* A valid [Supabase](https://supabase.com/) project configured with the correct tables (`users`, `exercises`, `workout_sessions`, `workout_sets`, `client_profiles`, `nutrition_logs`, etc.).

### Installation & Setup
1. Clone the repository.
2. Ensure you have your `assets/` and `assets/images/` set up.
3. Configure your API keys in the Supabase connect configuration inside `lib/services/supabase_client.dart`.
4. Run:
   ```bash
   flutter pub get
   ```
5. Run the app:
   ```bash
   flutter run
   ```

## 📱 App Icons

To generate the customized application icons included for Android and iOS builds, run the following:

```bash
flutter pub run flutter_launcher_icons
```
*(Ensure `assets/app_icon.png` is placed in the `assets/` directory before running.)*
