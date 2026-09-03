# CoreGym UI/UX Audit — Chat Log & Current State

> Full record of this chat's work (continuing session 1, documented in `UI_UX_AUDIT_HANDOFF.md`).
> Project: `C:\Users\mabou\coregymali` (Flutter, Windows / Git Bash, branch `main`).
> Design system (canonical, do NOT reinvent): **Kinetic Obsidian & Electric Volt** —
> surfaces `#000000 → #2C2C2C`, primary Electric Volt `#D1FC00`, secondary cyan `#00EEFC`,
> tertiary gold `#FCDC43`, error coral `#FF7351`, per-muscle gradients, premium dark glass aesthetic.
> A light sibling palette now exists (Part 4, in progress).

---

## 0. Git history created in this chat

| Commit | Content |
|---|---|
| `b618576` | checkpoint: session-1 audit fixes (token restore, semantic maps, state views, contrast) |
| `c346c2f` | fix(functional): DB-backed food browse in modal; dead-handler fixes (profile banner, today-workout card, chat TODO menus) |
| *(nav commit)* | feat(nav): role-aware bottom bar — coaches get 5 tabs + premium More sheet, volt glow active states |
| *(uncommitted)* | Part 4 in progress: mode-aware `AppColors` + `app_text` const-safety — de-const sweep pending (~210 analyzer errors expected) |

Verification: `flutter analyze` → 0 errors before Part 4 started. `flutter test` → 1 pre-existing failing smoke test (`test/widget_test.dart`), fails identically on untouched baseline.

---

## 1. Session-1 fixes already in the codebase (do not redo)

1. **Palette root cause:** old commit `814d622` had overwritten the Obsidian token values with a light "Kalee" palette; values restored, all legacy token names kept as aliases (`primaryGreen` → volt, `onPrimary` → `#0A0A0A` ink…). `AppColors` = single source of truth (~2,000+ refs).
2. `main.dart`: dark `ColorScheme.fromSeed(volt)`, pinned component themes (buttons ≥48px, volt focus inputs, dialog/sheet/snack/chip/tab/divider/appBar themes).
3. `auth_app_text.dart`: Epilogue/Inter actually loaded via `google_fonts`.
4. `app_background.dart`: obsidian canvas + glow orbs; `PlayfulCard` shared glass card.
5. New `lib/theme/app_semantic_colors.dart` (muscle/level/goal maps — kept const data-viz in Part 4).
6. New `lib/widgets/app_state_views.dart` (shared loading/empty/error; coach states delegate to it).
7. Contrast fixes app-wide: white-on-volt → `onPrimary` ink (auth CTA, gender chip, Add-Meal CTA, food-log save CTAs, nutrition chips, profile badge, coach sign-out, activity-card buttons).
8. Swept hardcoded hexes (`#F7F9F8`, nutrition pinks/greens, workout color maps → tokens).

---

## 2. PART 2 — "card cal" hardcoded food list — FIXED ✔

**Diagnosis:** two different add-food UIs from two entry points:
- Home hero fuel card → `FoodLoggingModal` showed a **hardcoded `_popularFoods` list** (8 static items, static macros, hardcoded Arabic names) when the search box was empty.
- Nutrition tab / Add Meal → `AddFoodSheet` — real Supabase `foods` (the ~319 seeded Egyptian foods).

**Fix (commit `c346c2f`):**
- New `NutritionService.getFoods({category})` — browses seeded `foods` (order by name, limit 40). Single DB accessor for browse.
- `food_logging_modal.dart` fully rewritten: **hardcoded list deleted**; on open it loads the real DB list ("From the food database 🇪🇬" header); searching swaps to `searchFoods()` from the same table; one shared `_buildDbFoodTile()` for both states (real `foodId` logging); loading + empty/error states added; leftover Kalee hexes removed (`0xFFF3F6F4/F1F5F3/F9FAFB/DC2626` → tokens); white-on-volt → `onPrimary`.
- `AddFoodSheet`'s 9 hardcoded strings are search **suggestion chips** (trigger real DB searches) — intentionally kept.
- Flagged (product decision): optional full convergence of `FoodLoggingModal` + `AddFoodSheet` into one widget (modal has quick-custom-add + AI/voice prefill; AddFoodSheet has smart serving units).

## 3. PART 2 — dead/misleading buttons — FIXED ✔

Full tap-handler audit (sub-agent) over profile, workout tabs, coach feature, chat, progrems, auth.

| Location | Problem | Fix |
|---|---|---|
| `profile.dart` Active-program banner (~:1005) | Tap only fired a haptic despite "Tap to view" + chevron | New `ProfilePage.onOpenWorkout` callback wired to jump to Workouts tab; standalone fallback pushes `WorkoutScreen` |
| `my_program_tab.dart` "Today's Workout" card | `onTap: () {}` dead + fake content "Day 1 — Full Body / 5 exercises ~45 min" | Real data (`current_day`, program name, `days_per_week`, week X of Y); tap opens the same muscle-picker flow as the START CTA |
| same file week row | Hardcoded Mon/Wed/Fri; "today" always Monday | Days derived from `days_per_week`; today = real weekday; `current_day` drives done-state |
| `chat_room_screen.dart` | 8 dead TODO no-ops (view profile / notification settings / delete conversation / photo / document / camera) | Removed the ⋮ options button + `_ChatOptionsSheet` + `_OptionTile` + attach button + `_AttachButton` + `_AttachOption` (chat layer has no delete API; `sendMessage` is text-only) — fake menus removed until features exist |
| `login_sign_up.dart` Apple sign-in ×2 | "Coming soon" snackbars (communicated) | Left; flagged for product decision |

Confirmed OK: coach feature (~120 handlers), chat list, `progrems.dart`, programs library, log-workout tab, main.dart (no named routes by design). Flagged: profile edit sheets swallow DB errors (`catch (_) {}`) — silent failure.

## 4. PART 3 — bottom nav redesign — DONE ✔

**Was:** members 5 tabs; **coaches 6** — overloaded.

**Now (`fitness_home_pages.dart`):**
- All destinations still exist as IndexedStack children (`_tabsFor`), so home quick-action indices keep working.
- `_visibleTabsFor` decides what the bar SHOWS:
  - **Member (5):** Home · Nutrition · Workout · Coaches · Profile
  - **Coach (5):** Home · Dashboard · Nutrition · Workout · **More**
- `_TabId.more` added; `_screenFor` maps it to `SizedBox.expand()` (never painted).
- `_showMoreSheet`: premium glass sheet ("Explore CoreGym") with rich tiles for **Coach Marketplace** + **Profile** (icon chip, label, subtitle, chevron).
- While Marketplace/Profile is active, the bar keeps highlighting **More** (`isMoreActive` + `currentIndex` mapper) — context never lost.
- Nav bar visual upgrade: active item gets volt pill + volt border + **volt glow shadow**; gold accent for coach Dashboard; haptics kept.
- l10n added: `navMore`, `moreMenuTitle`, `moreMarketplaceSubtitle`, `moreProfileSubtitle` (en + ar), `flutter gen-l10n` run (generated files checked in).

## 5. PART 4 — dark & light themes — WIRED & COMMITTED (polish sweep remains)

**Architecture:** `AppColors.apply(Brightness)` re-resolves every surface/text token; widgets keep static `AppColors.x` access; MaterialApp builder calls `apply()` with effective brightness and keys the tree (`KeyedSubtree(key: ValueKey(brightness))`).

**Done (this commit):**
- `app_colors.dart` fully rewritten mode-aware:
  - All surface/text/border/glass/glow tokens = `static Color` fields assigned in `apply()` (dark defaults preserved).
  - **Light palette:** background `#F4F5EF`, surface `#FFFFFF`, text `#17180F`/`#5D5E54`/`#8B8C82`, borders `#DFE1D4`, glass flips to black-alpha, softer `cardShadow`.
  - **Accent/fill split for contrast:** `primary` = volt on dark, **`#556A00` on light** (icons/text/accents); `primaryFixed`/`primaryGreen` stay volt in BOTH modes (fills, paired with `onPrimary` ink). Likewise `secondary`→`#00808A`, `tertiary`→`#A87E00`, `error`→`#C63D1B` in light.
  - Muscle gradients, `accent*` data-viz, `primaryActionGradient`, `dark*` aliases stay `const` (mode-safe).
- `app_text.dart`: 14 `Color color = AppColors.x` default params → `Color? color` + `??` fallbacks; `buttonPrimary` white → `AppColors.onPrimary` (root-cause Bucket B fix).
- De-const sweep complete (`tool/fix_consts.py` looped on `flutter analyze --machine` until 0 errors).
- `main.dart`: `ThemeData` parametrized as `_buildTheme(Brightness, isArabic)` (light textTheme base = `ThemeData.light()`, lighter modal barrier on light); `theme:` + `darkTheme:` + `themeMode:` wired.
- New `lib/providers/theme_mode_provider.dart` — `ChangeNotifier` + `SharedPreferences` (`themeMode` key), **default = system**.
- Builder computes effective brightness (mode, or platform brightness in system mode), calls `AppColors.apply`, keys the subtree.
- New `lib/widgets/theme_mode_toggle.dart` — segmented System/Light/Dark (volt fill + ink text when selected, volt glow).
- `profile.dart`: new **Appearance** section (header + card with the toggle) between Coach CTA and Sign Out.
- l10n: `appearance`, `themeSystem`, `themeLight`, `themeDark` (en + ar), `flutter gen-l10n` run.

**Remaining (Bucket A/B polish, exact lists in §6):**
1. Bucket A hardcoded light-surface hexes (`today_activity_card.dart`, `fitness_home_pages.dart` hero, `fitness_coach_screen.dart` private palette, plus the white-text-on-dark-panel sites listed in §6).
2. Bucket B white text on volt/gold fills → `AppColors.onPrimary` at the listed fill sites.
3. Smoke-test light/dark on device; verify no list/card survives the flip unreadable.

## 6. Color inventory for bucket A/B fixes

**Bucket A — light-surface hexes breaking either theme (fix):**
- `today_activity_card.dart`: `0xFFF9FAFB` ×3, `0xFFFFF8E1/FFE082/F57F17/E65100` warning card, `0xFFFEE2E2/DC2626` error card, `0xFFE53935/3B82F6` accents.
- `fitness_home_pages.dart`: `0xFFF1F5F3` circle, `0xFFF0F3F1` ring track, `0xFFFFF8E1/FFD54F` banner, `0xFFFFF3E0` fire badge, `0xFFFEE2E2/B91C1C` over-pill, `0xFFFCA5A5` border.
- `fitness_coach_screen.dart`: **whole screen on private dark palette** (`_kSurface/_kCard/_kCard2/_kAccent 0xFFD4FF57/_kMuted/_kSubtle`, lines 10–15 + 9 `Colors.white` texts) → migrate to tokens.
- `premium_glass_bg.dart:36` `0xFF050505` → token.
- White text/glass on dark panels: `onboarding_flow.dart` ×12, `home_header.dart` ×3, `food_scan_screen.dart` ~10, `text_food_log_screen.dart` ~10, `voice_food_log_screen.dart` ~9, `gender.dart:326`, `login_sign_up.dart:1611/1340/1499`, `splashscreen.dart:476`, `language_toggle.dart:50/106`, `enhanced_charts.dart` ~9, `progress_screen.dart:479`, `nutrition_screen.dart:2389`, `programs_library_tab.dart:414`.

**Bucket B — white text on volt/gold fills → `AppColors.onPrimary`:**
- **Top priority: `app_text.dart` `AppText.buttonPrimary` still `Colors.white` → `AppColors.onPrimary`** (root cause, app-wide).
- Fill sites: fitness_home_pages 540/903/1005, nutrition_screen 400/635/694/838/2177, add_food_sheet 217/639/831/859, exercise_detail_sheet 502/711, profile 1430-1461/1740/1750/2314, active_workout_sheet 195-198, barcode_scan_screen 811-829/935, text/voice food-log enabled states, my_program_tab 179-184, programs_library_tab 305-313/414, log_workout_tab 948/1051-1067, today_activity_card 433.

**Bucket C — legitimately fixed, do NOT tokenize:** camera/scanner overlays, image scrims, black box-shadows, `main.dart:164` barrier.

**Bucket D — leave as-is:** data-viz accents, progrems gradients, food-category thumbnail colors, black-on-gold coach set, splash brand palette, pixel-art palette.

## 7. Parts 1/5 — remaining polish

- Feature discoverability: home `_QuickFoodLogHub` already surfaces AI Scan / Voice / Text / Barcode; verify coach marketplace discoverability for members.
- Spacing/typography consistency: `profile.dart`, `progrems.dart`, chat screens, onboarding.
- Verify remaining screens use `AppStateViews` for loading/empty/error.

## 8. Handy facts

- Checks: `flutter analyze --no-pub 2>&1 | grep -cE " error "` and `flutter test`.
- pubspec: `provider` + `flutter_riverpod` both present (state uses `provider` + ChangeNotifiers); verify `shared_preferences` exists for the ThemeModeController (`flutter pub add shared_preferences` if not).
- l10n: edit `lib/l10n/*.arb` then run `flutter gen-l10n` (generated files checked in).
- Biggest files: `nutrition_screen.dart` (3141), `fitness_home_pages.dart` (3006+), `profile.dart` (2483), `login_sign_up.dart` (1859); coach under `lib/features/coach/`, chat under `lib/chat/`.
- `pixel_art_icons.dart` palette is intentionally fixed — never tokenize.
- No named routes anywhere (all `MaterialPageRoute`); sign-out uses `pushAndRemoveUntil(AuthWrapper())`.
- The ~319 Egyptian foods live in the Supabase project (not in repo); `NutritionService.getFoods/searchFoods` are the only correct accessors.
