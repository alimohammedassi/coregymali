# CoreGym UI/UX Audit — Session Handoff

> Purpose: continue this multi-part audit/fix job in a fresh chat without losing context.
> Project: `C:\Users\mabou\coregymali` (Flutter, Windows / Git Bash, branch `main`).
> Design system (canonical, do NOT reinvent): **Kinetic Obsidian & Electric Volt** —
> surfaces `#000000 → #2C2C2C`, primary Electric Volt `#D1FC00`, secondary cyan `#00EEFC`,
> tertiary gold `#FCDC43`, error coral `#FF7351`, per-muscle gradients (chest red / arms teal /
> legs purple / core pink), premium dark glass aesthetic.

---

## 1. State of the working tree (IMPORTANT)

Session 1 changes are **applied but NOT committed** (17 modified files + 2 new files):

- Modified: `lib/theme/app_colors.dart`, `lib/theme/app_text.dart`, `lib/theme/auth_app_text.dart`,
  `lib/main.dart`, `lib/widgets/app_background.dart`, `lib/widgets/food_logging_modal.dart`,
  `lib/fitness_home_pages.dart`, `lib/gender.dart`, `lib/login_sign_up.dart`, `lib/profile.dart`,
  `lib/screens/nutrition_screen.dart`, `lib/screens/text_food_log_screen.dart`,
  `lib/screens/voice_food_log_screen.dart`, `lib/screens/workout_tabs/log_workout_tab.dart`,
  `lib/screens/workout_tabs/my_program_tab.dart`, `lib/screens/workout_tabs/programs_library_tab.dart`,
  `lib/features/coach/presentation/screens/coach_dashboard_screen.dart`,
  `lib/features/coach/presentation/widgets/coach_shared.dart`,
  `lib/features/health/presentation/widgets/today_activity_card.dart`
- New: `lib/theme/app_semantic_colors.dart`, `lib/widgets/app_state_views.dart`

**Recommendation: commit this as a checkpoint before starting Part 3/4 work.**

### Verification status
- `flutter analyze` → **0 errors** (~220 pre-existing infos: `withOpacity` deprecations, `print` in services).
- `flutter test` → 1 failing smoke test (`test/widget_test.dart`) — **fails identically on the untouched
  baseline** (verified via `git stash`), pre-existing, not caused by the audit work.

---

## 2. What session 1 already fixed (do not redo)

1. **Root cause found:** the original Kinetic Obsidian token values in `lib/theme/app_colors.dart`
   were overwritten in commit `814d622` with a light-green "Kalee" palette while token *names* stayed.
   **Fixed:** restored canonical obsidian/volt values, keeping every legacy token name as an alias
   (`primaryGreen` → volt, `lightGreen` → 10% volt glass `0x1AD1FC00`, `onPrimary` → `#0A0A0A`,
   `onPrimaryContainer` → volt, etc.). `AppColors` is the single source of truth; ~37 files consume it.
2. `lib/main.dart`: dark `ColorScheme.fromSeed(seedColor: volt)`, `brightness: Brightness.dark`,
   plus pinned component themes (elevated/filled/outlined buttons ≥48px touch height, input decoration
   with volt focus border, dialog/bottomSheet/snackBar/chip/tabBar/divider/appBar themes).
3. `lib/theme/auth_app_text.dart`: Epilogue/Inter were referenced but never bundled → now loaded via
   `google_fonts` (getters, not const).
4. `lib/widgets/app_background.dart`: obsidian canvas + volt/cyan glow orbs; `PlayfulCard` = shared
   glass card (`surfaceContainer` + `glassBorder`).
5. New `lib/theme/app_semantic_colors.dart`: `AppSemanticColors.muscle/.level/.goal` + safe lookups —
   replaced duplicated hex maps in all three workout tabs.
6. New `lib/widgets/app_state_views.dart`: `AppStateViews.loading/empty/error` in design language;
   `CoachEmptyState`/`CoachErrorState` in `coach_shared.dart` now delegate to it.
7. Contrast fixes (white-on-volt ~1.5–2.4:1 → `AppColors.onPrimary` ink): auth CTA (`login_sign_up.dart`),
   gender check chip, Add-Meal CTA + dark shimmer (`fitness_home_pages.dart`), save CTAs in
   text/voice food log screens, nutrition "Today" chip + Save Goals button, profile avatar badge,
   coach dashboard sign-out, `today_activity_card` buttons (`#F57F17` → `AppColors.tertiary`).
8. Swept hardcoded hexes: `#F7F9F8` fills → `surfaceContainerHigh`, nutrition `#10B981`/`#EC4899`
   → tokens, workout tab color maps → `AppSemanticColors`.

---

## 3. PART 2 — the "card cal" bug hunt (IN PROGRESS — evidence collected)

Symptom reported by user: a calendar/nutrition card ("card cal") where a **date button** opens one
food-log list and **tapping the card** opens a *different* list; one of the two is **hardcoded in
widget code** (wrong) and the other is the real Supabase-backed list (~319 seeded Egyptian foods).

### What was traced so far
- **Home Hero Fuel Card** — `_HeroFuelCard` at `lib/fitness_home_pages.dart:1679`:
  - Card tap (`_InteractiveScaleDetector.onTap`, line ~1727) → `onOpenNutrition` →
    `_openFoodLogger()` (line ~721) → `FoodLoggingModal.show(...)` (`lib/widgets/food_logging_modal.dart`).
  - `_HeroDateStepper` (line ~2016): chevron buttons only change `_selectedDate` and reload that
    day's data — they do **not** open a list.
- **`lib/widgets/food_logging_modal.dart`** has TWO food sources inside:
  - DB-backed search tab: `_performSearch` (line ~181) → `NutritionService.searchFoods` (Supabase). ✔ correct
  - **HARDCODED `_quickFoods` list (lines ~40–144)** — 8 literal items (eggs, oatmeal & milk, white
    rice, whey shake, greek yogurt, avocado, banana & PB) with static calories and a hardcoded Arabic
    name at line 136. This is the only hardcoded food list found in the app. ✘ THIS IS THE PRIME SUSPECT.
- **Nutrition screen** (`lib/screens/nutrition_screen.dart`):
  - `_todayLogs` starts **empty** (line 39) and is filled from `getTodayLogs()` (DB) — lines 96/104/129/134. ✔
  - Add-food path: `AddFoodSheet.show` (`lib/widgets/add_food_sheet.dart`) — fully DB-backed search with
    category chips (Arabic/Protein/Carbs/... querying Supabase `foods`). ✔
  - History tab (`_buildHistoryTab`, line 2189): weekly chart + Daily Breakdown from DB `weekly_progress`. ✔
  - Quick Calories dialog (line 240): manual entry, no list. ✔
- **Conclusion / next steps for the fixer:**
  1. Confirm with the user's build that the mismatch is: **home card → `FoodLoggingModal` (with its
     hardcoded `_quickFoods` quick-add tab)** vs **nutrition tab → `AddFoodSheet` (DB search)** —
     i.e., two *different add-food UIs* reached from two entries, one showing static foods.
  2. Fix = delete the hardcoded `_quickFoods` list from `food_logging_modal.dart` and make its
     quick-add tab query the DB instead (e.g. `NutritionService.searchFoods('')` or a
     "popular foods" query on the seeded `foods` table — check `supabase/` seed for the 319 items
     and `lib/services/nutrition_service.dart` for available queries).
  3. Longer-term (flagged): unify `FoodLoggingModal` and `AddFoodSheet` into ONE shared food-picker
     widget so home and nutrition tab can never drift again. If asked for minimal change, just swap
     the quick-add data source; if allowed, converge both screens on a single sheet.
  4. Also verify on-device: nutrition screen date strip (`_selectedHistoryIndex`) and the home date
     stepper both only *change date* — if any other build shows a list on date tap, re-grep for
     `showModalBottomSheet` near date widgets.

---

## 4. PART 3 — bottom nav redesign (NOT STARTED — plan only)

Current state (`lib/fitness_home_pages.dart`):
- `enum _TabId { home, nutrition, dashboard, workout, coaches, profile }` (line 159).
- `_tabsFor(isCoach, l10n)` (line ~172): members get 5 tabs (home, nutrition, workout, coaches,
  profile); **coaches get 6** (adds dashboard) — overloaded.
- `_PlayfulNavBar` (line ~318): floating rounded bar, 68px, `AppColors.surface` bg, `borderSubtle`
  border, per-tab accent (gold for dashboard, volt otherwise).

**Agreed direction:** max 5 visible tabs, role-aware:
- Member: Home, Nutrition, Workout, Coaches, Profile (5 — keep, but visually upgrade).
- Coach: Home, Dashboard, Nutrition, Workout, More-sheet (Coaches marketplace + Profile move into a
  premium "More" action sheet), OR swap Coaches→Dashboard and move marketplace to home quick actions.
  Decide after checking what home screen already surfaces for coaches (see `_HomeScreenCore`).
- Visual upgrade to implement: volt pill/glow active indicator, `Kinetic` glass bar
  (`glass2` + `glassBorderActive` when active), haptics already present (`HapticFeedback.selectionClick`).

---

## 5. PART 4 — dark & light theme support (NOT STARTED — architecture decided)

Current state: only dark exists (`main.dart` ThemeData `brightness: Brightness.dark`). All colors
flow through static `AppColors` tokens (mostly `static const Color`) consumed directly by widgets —
NOT via `Theme.of(context)`.

**Chosen pragmatic architecture** (given ~41k lines / thousands of `const` usages of `AppColors`):
1. Make `AppColors` **mode-aware**: convert `static const Color x` → `static Color x` fields set by
   `AppColors.apply(Brightness)`. Call sites stay source-compatible EXCEPT `const` contexts.
2. Run a **de-const sweep**: for every `const SomeWidget(...)` / `const TextStyle(` etc. whose body
   references `AppColors.`, drop the `const` keyword. Verify with `flutter analyze` after
   (expect a wave of errors pointing at any missed const).
3. Define the **light sibling palette** in `AppColors.apply(Brightness.light)`: same identity —
   volt `#D1FC00` still used for button fills (black ink `onPrimary` works in both modes), but
   `primary` as icon/text accent must darken for contrast on white (≈`#556A00`); background ≈
   `#F6F7F2`, surface `#FFFFFF`, text `#14150F`, borders `#E2E4DA`, glass tokens flip to
   black-alpha (`0x0A000000` etc.), tertiary gold darkens for text use (≈`#B78900`).
4. `main.dart`: `theme:` (light) + `darkTheme:` (dark) + `themeMode:` from a new
   `ThemeModeController` (ChangeNotifier via the existing `provider` setup, persisted with
   `SharedPreferences`; default = follow system). Force full-tree rebuild on switch by keying the
   builder child: `KeyedSubtree(key: ValueKey(effectiveBrightness), child: ...)` and calling
   `AppColors.apply(...)` in the builder before painting.
5. Toggle UI: segmented control (System / Light / Dark) in `lib/profile.dart` settings section.
6. After sweep: grep for remaining hardcoded hexes that break light mode (known offenders:
   `Color(0xFFFFF3E0)` fire badge bg and `Color(0xFFFCA5A5)` in `_HeroFuelCard`, chart dot
   `Colors.white` in `nutrition_screen.dart:2389`, `Colors.white` overlays in scan screens are OK —
   they sit on camera feeds).

---

## 6. PART 1/5 — audit & polish status

- Session 1 covered the token/theme/contrast layer app-wide (see §2).
- Still to do: feature-discoverability pass (home already has `_QuickFoodLogHub` at line ~2505 with
  AI Scan / Voice / Text / Barcode quick chips — good; verify coach marketplace discoverability for
  members), spacing/typography consistency pass on `profile.dart`, `progrems.dart`, chat screens,
  onboarding; verify every remaining screen has loading/empty/error via `AppStateViews`.
- Functional audit so far (home): all main handlers traced OK — chat list (lines 1029/1169),
  barcode → `BarcodeScanScreen`, AI → `FoodScanScreen`, voice → `VoiceFoodLogScreen`,
  text → `TextFoodLogScreen`, meals → `FoodLoggingModal`. Still to trace: `profile.dart`,
  workout tabs, coach screens, `progrems.dart`, chat room internals. Useful technique:
  `grep -n "onPressed\|onTap" <file>` and follow each to its target.

---

## 7. Handy facts for the next session

- Run checks: `flutter analyze 2>&1 | grep -cE "^\s*error"` and `flutter test`.
- `pubspec.yaml`: `provider` + `flutter_riverpod` BOTH present (main state uses `provider` +
  ChangeNotifiers; Riverpod exists but is barely used). `google_fonts`, `shimmer`, `fl_chart`,
  `supabase_flutter`, `mobile_scanner`, `record` are available.
- Key files by size: `nutrition_screen.dart` (3141), `fitness_home_pages.dart` (3006), `profile.dart`
  (2483), `login_sign_up.dart` (1859), coach feature under `lib/features/coach/`, chat under `lib/chat/`.
- `lib/widgets/pixel_art_icons.dart` contains an intentional pixel-art illustration palette —
  do NOT tokenize those hexes.
- Session 1's full per-fix rationale lives in the prior chat; this file is the source of truth going forward.
