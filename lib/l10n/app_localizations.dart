import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'CoreGym'**
  String get appName;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navNutrition.
  ///
  /// In en, this message translates to:
  /// **'Nutrition'**
  String get navNutrition;

  /// No description provided for @navWorkout.
  ///
  /// In en, this message translates to:
  /// **'Workout'**
  String get navWorkout;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @navMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get navMessages;

  /// No description provided for @navCoaches.
  ///
  /// In en, this message translates to:
  /// **'Coaches'**
  String get navCoaches;

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navMore;

  /// No description provided for @moreMenuTitle.
  ///
  /// In en, this message translates to:
  /// **'Explore CoreGym'**
  String get moreMenuTitle;

  /// No description provided for @moreMarketplaceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Browse coaches, compare plans, manage subscriptions'**
  String get moreMarketplaceSubtitle;

  /// No description provided for @moreProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your body data, goals, settings and achievements'**
  String get moreProfileSubtitle;

  /// No description provided for @dashboardOverview.
  ///
  /// In en, this message translates to:
  /// **'Dashboard Overview'**
  String get dashboardOverview;

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get goodMorning;

  /// No description provided for @goodAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get goodAfternoon;

  /// No description provided for @goodEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get goodEvening;

  /// No description provided for @readyConquer.
  ///
  /// In en, this message translates to:
  /// **'Ready to conquer your fitness goals today?'**
  String get readyConquer;

  /// No description provided for @calorieGoalReached.
  ///
  /// In en, this message translates to:
  /// **'Calorie goal reached! Peak performance! 🔥'**
  String get calorieGoalReached;

  /// No description provided for @calorieProgressMsg.
  ///
  /// In en, this message translates to:
  /// **'Completed {pct}% of daily energy target'**
  String calorieProgressMsg(int pct);

  /// No description provided for @daysStreak.
  ///
  /// In en, this message translates to:
  /// **'{count} DAYS'**
  String daysStreak(int count);

  /// No description provided for @dayStreakLabel.
  ///
  /// In en, this message translates to:
  /// **'day streak'**
  String get dayStreakLabel;

  /// No description provided for @dailyMetrics.
  ///
  /// In en, this message translates to:
  /// **'DAILY METRIC MATRIX'**
  String get dailyMetrics;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @todayCalories.
  ///
  /// In en, this message translates to:
  /// **'Calories Today'**
  String get todayCalories;

  /// No description provided for @caloriesRemaining.
  ///
  /// In en, this message translates to:
  /// **'remaining'**
  String get caloriesRemaining;

  /// No description provided for @caloriesOver.
  ///
  /// In en, this message translates to:
  /// **'over'**
  String get caloriesOver;

  /// No description provided for @kcalLeft.
  ///
  /// In en, this message translates to:
  /// **'KCAL LEFT'**
  String get kcalLeft;

  /// No description provided for @kcalOver.
  ///
  /// In en, this message translates to:
  /// **'KCAL OVER'**
  String get kcalOver;

  /// No description provided for @kcal.
  ///
  /// In en, this message translates to:
  /// **'kcal'**
  String get kcal;

  /// No description provided for @eaten.
  ///
  /// In en, this message translates to:
  /// **'Eaten'**
  String get eaten;

  /// No description provided for @burned.
  ///
  /// In en, this message translates to:
  /// **'Burned'**
  String get burned;

  /// No description provided for @protein.
  ///
  /// In en, this message translates to:
  /// **'Protein'**
  String get protein;

  /// No description provided for @carbs.
  ///
  /// In en, this message translates to:
  /// **'Carbs'**
  String get carbs;

  /// No description provided for @fat.
  ///
  /// In en, this message translates to:
  /// **'Fat'**
  String get fat;

  /// No description provided for @additionalNutrients.
  ///
  /// In en, this message translates to:
  /// **'Additional Nutrients'**
  String get additionalNutrients;

  /// No description provided for @macronutrients.
  ///
  /// In en, this message translates to:
  /// **'Macronutrients'**
  String get macronutrients;

  /// No description provided for @fiber.
  ///
  /// In en, this message translates to:
  /// **'Fiber'**
  String get fiber;

  /// No description provided for @sugars.
  ///
  /// In en, this message translates to:
  /// **'Sugar'**
  String get sugars;

  /// No description provided for @sodium.
  ///
  /// In en, this message translates to:
  /// **'Sodium'**
  String get sodium;

  /// No description provided for @potassium.
  ///
  /// In en, this message translates to:
  /// **'Potassium'**
  String get potassium;

  /// No description provided for @calcium.
  ///
  /// In en, this message translates to:
  /// **'Calcium'**
  String get calcium;

  /// No description provided for @iron.
  ///
  /// In en, this message translates to:
  /// **'Iron'**
  String get iron;

  /// No description provided for @cholesterol.
  ///
  /// In en, this message translates to:
  /// **'Cholesterol'**
  String get cholesterol;

  /// No description provided for @caffeine.
  ///
  /// In en, this message translates to:
  /// **'Caffeine'**
  String get caffeine;

  /// No description provided for @percentOfGoal.
  ///
  /// In en, this message translates to:
  /// **'{pct}% of goal'**
  String percentOfGoal(int pct);

  /// No description provided for @quickAddWater.
  ///
  /// In en, this message translates to:
  /// **'+250ml'**
  String get quickAddWater;

  /// No description provided for @quickWorkout.
  ///
  /// In en, this message translates to:
  /// **'Workout'**
  String get quickWorkout;

  /// No description provided for @setGoalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Personalize Your Target Goals'**
  String get setGoalsTitle;

  /// No description provided for @setGoalsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set calories, macros & water for tailored tracking'**
  String get setGoalsSubtitle;

  /// No description provided for @moodSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose Your Mood'**
  String get moodSectionTitle;

  /// No description provided for @moodTired.
  ///
  /// In en, this message translates to:
  /// **'Tired'**
  String get moodTired;

  /// No description provided for @moodLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get moodLight;

  /// No description provided for @moodMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get moodMedium;

  /// No description provided for @moodActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get moodActive;

  /// No description provided for @moodFull.
  ///
  /// In en, this message translates to:
  /// **'Full Power'**
  String get moodFull;

  /// No description provided for @muscleGroupsTitle.
  ///
  /// In en, this message translates to:
  /// **'Muscle Groups'**
  String get muscleGroupsTitle;

  /// No description provided for @muscleChest.
  ///
  /// In en, this message translates to:
  /// **'Chest'**
  String get muscleChest;

  /// No description provided for @muscleArms.
  ///
  /// In en, this message translates to:
  /// **'Arms'**
  String get muscleArms;

  /// No description provided for @muscleLegs.
  ///
  /// In en, this message translates to:
  /// **'Legs'**
  String get muscleLegs;

  /// No description provided for @muscleCore.
  ///
  /// In en, this message translates to:
  /// **'Core'**
  String get muscleCore;

  /// No description provided for @aiWorkoutCta.
  ///
  /// In en, this message translates to:
  /// **'Generate Your AI Workout'**
  String get aiWorkoutCta;

  /// No description provided for @aiWorkoutSub.
  ///
  /// In en, this message translates to:
  /// **'Smart Trainer — 45 min'**
  String get aiWorkoutSub;

  /// No description provided for @caloriesOf.
  ///
  /// In en, this message translates to:
  /// **'of {goal}'**
  String caloriesOf(int goal);

  /// No description provided for @caloriesRemainingMsg.
  ///
  /// In en, this message translates to:
  /// **'{remaining} kcal remaining'**
  String caloriesRemainingMsg(int remaining);

  /// No description provided for @caloriesOverMsg.
  ///
  /// In en, this message translates to:
  /// **'{over} kcal over goal'**
  String caloriesOverMsg(int over);

  /// No description provided for @addMeal.
  ///
  /// In en, this message translates to:
  /// **'+ Add Meal'**
  String get addMeal;

  /// No description provided for @scanAi.
  ///
  /// In en, this message translates to:
  /// **'AI Scan'**
  String get scanAi;

  /// No description provided for @voiceLog.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get voiceLog;

  /// No description provided for @barcodeScan.
  ///
  /// In en, this message translates to:
  /// **'Barcode'**
  String get barcodeScan;

  /// No description provided for @quickText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get quickText;

  /// No description provided for @foodLogSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Log your food'**
  String get foodLogSheetTitle;

  /// No description provided for @foodLogSheetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Every way to log your food, in one place'**
  String get foodLogSheetSubtitle;

  /// No description provided for @voiceLogSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Say it — AI logs the macros'**
  String get voiceLogSubtitle;

  /// No description provided for @quickTextSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Describe the meal — AI analyzes it'**
  String get quickTextSubtitle;

  /// No description provided for @barcodeScanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Scan the package, log instantly'**
  String get barcodeScanSubtitle;

  /// No description provided for @addMealSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Browse the food database'**
  String get addMealSubtitle;

  /// No description provided for @dailyQuests.
  ///
  /// In en, this message translates to:
  /// **'Daily Quests'**
  String get dailyQuests;

  /// No description provided for @hydrationHero.
  ///
  /// In en, this message translates to:
  /// **'Hydration Hero'**
  String get hydrationHero;

  /// No description provided for @proteinChampion.
  ///
  /// In en, this message translates to:
  /// **'Protein Champion'**
  String get proteinChampion;

  /// No description provided for @streakMaster.
  ///
  /// In en, this message translates to:
  /// **'Streak Master'**
  String get streakMaster;

  /// No description provided for @xpEarned.
  ///
  /// In en, this message translates to:
  /// **'+{count} XP'**
  String xpEarned(int count);

  /// No description provided for @levelLabel.
  ///
  /// In en, this message translates to:
  /// **'LVL {lvl}'**
  String levelLabel(int lvl);

  /// No description provided for @todayMeals.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Meals'**
  String get todayMeals;

  /// No description provided for @todaysFueling.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Fueling'**
  String get todaysFueling;

  /// No description provided for @addFood.
  ///
  /// In en, this message translates to:
  /// **'+ Add Food'**
  String get addFood;

  /// No description provided for @noMealsYet.
  ///
  /// In en, this message translates to:
  /// **'No meals logged yet'**
  String get noMealsYet;

  /// No description provided for @logFirstMeal.
  ///
  /// In en, this message translates to:
  /// **'Log your first meal today'**
  String get logFirstMeal;

  /// No description provided for @logMeal.
  ///
  /// In en, this message translates to:
  /// **'Log Meal'**
  String get logMeal;

  /// No description provided for @loggingNotToday.
  ///
  /// In en, this message translates to:
  /// **'You\'re logging for {date} — not today'**
  String loggingNotToday(String date);

  /// No description provided for @breakfast.
  ///
  /// In en, this message translates to:
  /// **'Breakfast'**
  String get breakfast;

  /// No description provided for @lunch.
  ///
  /// In en, this message translates to:
  /// **'Lunch'**
  String get lunch;

  /// No description provided for @dinner.
  ///
  /// In en, this message translates to:
  /// **'Dinner'**
  String get dinner;

  /// No description provided for @snack.
  ///
  /// In en, this message translates to:
  /// **'Snack'**
  String get snack;

  /// No description provided for @notLogged.
  ///
  /// In en, this message translates to:
  /// **'not logged'**
  String get notLogged;

  /// No description provided for @items.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String items(int count);

  /// No description provided for @yourProgram.
  ///
  /// In en, this message translates to:
  /// **'Your Program'**
  String get yourProgram;

  /// No description provided for @activeProgram.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE PROGRAM'**
  String get activeProgram;

  /// No description provided for @activeTrainingProgram.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE TRAINING PROGRAM'**
  String get activeTrainingProgram;

  /// No description provided for @noActiveProgram.
  ///
  /// In en, this message translates to:
  /// **'No active program'**
  String get noActiveProgram;

  /// No description provided for @browsePrograms.
  ///
  /// In en, this message translates to:
  /// **'Browse Programs →'**
  String get browsePrograms;

  /// No description provided for @startTodaysWorkout.
  ///
  /// In en, this message translates to:
  /// **'Start Today\'s Workout'**
  String get startTodaysWorkout;

  /// No description provided for @week.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get week;

  /// No description provided for @ofWord.
  ///
  /// In en, this message translates to:
  /// **'of'**
  String get ofWord;

  /// No description provided for @weekOfTotal.
  ///
  /// In en, this message translates to:
  /// **'Week {current} of {total}'**
  String weekOfTotal(int current, int total);

  /// No description provided for @percentComplete.
  ///
  /// In en, this message translates to:
  /// **'{pct}% complete'**
  String percentComplete(int pct);

  /// No description provided for @beginner.
  ///
  /// In en, this message translates to:
  /// **'BEGINNER'**
  String get beginner;

  /// No description provided for @intermediate.
  ///
  /// In en, this message translates to:
  /// **'INTERMEDIATE'**
  String get intermediate;

  /// No description provided for @advanced.
  ///
  /// In en, this message translates to:
  /// **'ADVANCED'**
  String get advanced;

  /// No description provided for @lastWorkout.
  ///
  /// In en, this message translates to:
  /// **'Last Workout'**
  String get lastWorkout;

  /// No description provided for @lastWorkoutUpper.
  ///
  /// In en, this message translates to:
  /// **'LAST WORKOUT'**
  String get lastWorkoutUpper;

  /// No description provided for @noWorkoutsYet.
  ///
  /// In en, this message translates to:
  /// **'No workouts logged yet'**
  String get noWorkoutsYet;

  /// No description provided for @logFirstWorkout.
  ///
  /// In en, this message translates to:
  /// **'Log Your First Workout →'**
  String get logFirstWorkout;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @min.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get min;

  /// No description provided for @kgVolume.
  ///
  /// In en, this message translates to:
  /// **'kg volume'**
  String get kgVolume;

  /// No description provided for @water.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get water;

  /// No description provided for @glasses.
  ///
  /// In en, this message translates to:
  /// **'glasses'**
  String get glasses;

  /// No description provided for @ofGlasses.
  ///
  /// In en, this message translates to:
  /// **'of 8 glasses'**
  String get ofGlasses;

  /// No description provided for @ofGlassesGoal.
  ///
  /// In en, this message translates to:
  /// **'of 8 goal'**
  String get ofGlassesGoal;

  /// No description provided for @steps.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get steps;

  /// No description provided for @ofSteps.
  ///
  /// In en, this message translates to:
  /// **'of 10,000 steps'**
  String get ofSteps;

  /// No description provided for @ofStepsGoal.
  ///
  /// In en, this message translates to:
  /// **'{pct}% of 10k'**
  String ofStepsGoal(int pct);

  /// No description provided for @activity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activity;

  /// No description provided for @ofGlassesCount.
  ///
  /// In en, this message translates to:
  /// **'of {count} glasses'**
  String ofGlassesCount(String count);

  /// No description provided for @ofStepsTotal.
  ///
  /// In en, this message translates to:
  /// **'of {total}'**
  String ofStepsTotal(String total);

  /// No description provided for @addWaterPortion.
  ///
  /// In en, this message translates to:
  /// **'+ Add 250 ml'**
  String get addWaterPortion;

  /// No description provided for @connectHealthToSync.
  ///
  /// In en, this message translates to:
  /// **'Connect {source} to sync'**
  String connectHealthToSync(String source);

  /// No description provided for @kcalBurned.
  ///
  /// In en, this message translates to:
  /// **'kcal burned'**
  String get kcalBurned;

  /// No description provided for @burnedToday.
  ///
  /// In en, this message translates to:
  /// **'burned today'**
  String get burnedToday;

  /// No description provided for @updateSteps.
  ///
  /// In en, this message translates to:
  /// **'Update Steps'**
  String get updateSteps;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @coachBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Level up with a Pro Coach'**
  String get coachBannerTitle;

  /// No description provided for @coachBannerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Certified coaches available · Personalized plans'**
  String get coachBannerSubtitle;

  /// No description provided for @completeProfile.
  ///
  /// In en, this message translates to:
  /// **'Complete your profile to see personalized goals.'**
  String get completeProfile;

  /// No description provided for @fix.
  ///
  /// In en, this message translates to:
  /// **'Fix →'**
  String get fix;

  /// No description provided for @nutritionTitle.
  ///
  /// In en, this message translates to:
  /// **'NUTRITION'**
  String get nutritionTitle;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'TODAY'**
  String get today;

  /// No description provided for @historyTab.
  ///
  /// In en, this message translates to:
  /// **'HISTORY'**
  String get historyTab;

  /// No description provided for @caloriesToday.
  ///
  /// In en, this message translates to:
  /// **'CALORIES TODAY'**
  String get caloriesToday;

  /// No description provided for @caloriesConsumed.
  ///
  /// In en, this message translates to:
  /// **'kcal consumed'**
  String get caloriesConsumed;

  /// No description provided for @searchFood.
  ///
  /// In en, this message translates to:
  /// **'Search Food'**
  String get searchFood;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search in English or Arabic...'**
  String get searchHint;

  /// No description provided for @allCategories.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allCategories;

  /// No description provided for @logFood.
  ///
  /// In en, this message translates to:
  /// **'Log Food'**
  String get logFood;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @grams.
  ///
  /// In en, this message translates to:
  /// **'grams'**
  String get grams;

  /// No description provided for @mealType.
  ///
  /// In en, this message translates to:
  /// **'Meal'**
  String get mealType;

  /// No description provided for @noFoodFound.
  ///
  /// In en, this message translates to:
  /// **'Search for a food'**
  String get noFoodFound;

  /// No description provided for @last7Days.
  ///
  /// In en, this message translates to:
  /// **'CALORIES — LAST 7 DAYS'**
  String get last7Days;

  /// No description provided for @dailyLogs.
  ///
  /// In en, this message translates to:
  /// **'Daily Logs'**
  String get dailyLogs;

  /// No description provided for @goalMet.
  ///
  /// In en, this message translates to:
  /// **'Goal met'**
  String get goalMet;

  /// No description provided for @underGoal.
  ///
  /// In en, this message translates to:
  /// **'Under goal'**
  String get underGoal;

  /// No description provided for @noHistory.
  ///
  /// In en, this message translates to:
  /// **'No history yet'**
  String get noHistory;

  /// No description provided for @startLogging.
  ///
  /// In en, this message translates to:
  /// **'Start logging meals to see your progress'**
  String get startLogging;

  /// No description provided for @workoutTitle.
  ///
  /// In en, this message translates to:
  /// **'WORKOUT'**
  String get workoutTitle;

  /// No description provided for @myProgram.
  ///
  /// In en, this message translates to:
  /// **'My Program'**
  String get myProgram;

  /// No description provided for @workoutLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get workoutLibrary;

  /// No description provided for @programs.
  ///
  /// In en, this message translates to:
  /// **'Programs'**
  String get programs;

  /// No description provided for @logWorkout.
  ///
  /// In en, this message translates to:
  /// **'Log Workout'**
  String get logWorkout;

  /// No description provided for @sectionTodaysWorkout.
  ///
  /// In en, this message translates to:
  /// **'TODAY\'S WORKOUT'**
  String get sectionTodaysWorkout;

  /// No description provided for @sectionThisWeek.
  ///
  /// In en, this message translates to:
  /// **'THIS WEEK'**
  String get sectionThisWeek;

  /// No description provided for @noActiveProgramHint.
  ///
  /// In en, this message translates to:
  /// **'Head to the Library tab to pick a program and start your journey.'**
  String get noActiveProgramHint;

  /// No description provided for @chooseMuscleGroup.
  ///
  /// In en, this message translates to:
  /// **'Choose Muscle Group'**
  String get chooseMuscleGroup;

  /// No description provided for @sessionName.
  ///
  /// In en, this message translates to:
  /// **'Session Name'**
  String get sessionName;

  /// No description provided for @startWorkout.
  ///
  /// In en, this message translates to:
  /// **'Start Workout'**
  String get startWorkout;

  /// No description provided for @chest.
  ///
  /// In en, this message translates to:
  /// **'Chest'**
  String get chest;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @shoulders.
  ///
  /// In en, this message translates to:
  /// **'Shoulders'**
  String get shoulders;

  /// No description provided for @arms.
  ///
  /// In en, this message translates to:
  /// **'Arms'**
  String get arms;

  /// No description provided for @legs.
  ///
  /// In en, this message translates to:
  /// **'Legs'**
  String get legs;

  /// No description provided for @core.
  ///
  /// In en, this message translates to:
  /// **'Core'**
  String get core;

  /// No description provided for @fullBody.
  ///
  /// In en, this message translates to:
  /// **'Full Body'**
  String get fullBody;

  /// No description provided for @activeWorkout.
  ///
  /// In en, this message translates to:
  /// **'Active Workout'**
  String get activeWorkout;

  /// No description provided for @finish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get finish;

  /// No description provided for @addExercise.
  ///
  /// In en, this message translates to:
  /// **'+ Add Exercise'**
  String get addExercise;

  /// No description provided for @addSet.
  ///
  /// In en, this message translates to:
  /// **'+ Add Set'**
  String get addSet;

  /// No description provided for @set.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get set;

  /// No description provided for @kg.
  ///
  /// In en, this message translates to:
  /// **'kg'**
  String get kg;

  /// No description provided for @reps.
  ///
  /// In en, this message translates to:
  /// **'Reps'**
  String get reps;

  /// No description provided for @lastBest.
  ///
  /// In en, this message translates to:
  /// **'Last: {weight}kg × {reps} reps'**
  String lastBest(double weight, int reps);

  /// No description provided for @warmup.
  ///
  /// In en, this message translates to:
  /// **'W'**
  String get warmup;

  /// No description provided for @restTimer.
  ///
  /// In en, this message translates to:
  /// **'Rest Timer'**
  String get restTimer;

  /// No description provided for @skipRest.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skipRest;

  /// No description provided for @restComplete.
  ///
  /// In en, this message translates to:
  /// **'Rest complete!'**
  String get restComplete;

  /// No description provided for @workoutSummary.
  ///
  /// In en, this message translates to:
  /// **'Workout Summary'**
  String get workoutSummary;

  /// No description provided for @totalVolume.
  ///
  /// In en, this message translates to:
  /// **'Total Volume'**
  String get totalVolume;

  /// No description provided for @totalSets.
  ///
  /// In en, this message translates to:
  /// **'Total Sets'**
  String get totalSets;

  /// No description provided for @exercises.
  ///
  /// In en, this message translates to:
  /// **'Exercises'**
  String get exercises;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @saveWorkout.
  ///
  /// In en, this message translates to:
  /// **'Save Workout'**
  String get saveWorkout;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @personalRecord.
  ///
  /// In en, this message translates to:
  /// **'🏆 PR!'**
  String get personalRecord;

  /// No description provided for @searchExercise.
  ///
  /// In en, this message translates to:
  /// **'Search exercises...'**
  String get searchExercise;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'PROFILE'**
  String get profileTitle;

  /// No description provided for @operativeData.
  ///
  /// In en, this message translates to:
  /// **'OPERATIVE DATA'**
  String get operativeData;

  /// No description provided for @dailyTargets.
  ///
  /// In en, this message translates to:
  /// **'DAILY TARGETS'**
  String get dailyTargets;

  /// No description provided for @thisMonth.
  ///
  /// In en, this message translates to:
  /// **'THIS MONTH'**
  String get thisMonth;

  /// No description provided for @rmProgress.
  ///
  /// In en, this message translates to:
  /// **'1RM PROGRESS'**
  String get rmProgress;

  /// No description provided for @totalWorkouts.
  ///
  /// In en, this message translates to:
  /// **'Total\nWorkouts'**
  String get totalWorkouts;

  /// No description provided for @thisMonthWorkouts.
  ///
  /// In en, this message translates to:
  /// **'This\nMonth'**
  String get thisMonthWorkouts;

  /// No description provided for @kcalLogged.
  ///
  /// In en, this message translates to:
  /// **'kcal\nLogged'**
  String get kcalLogged;

  /// No description provided for @activeProgram2.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE PROGRAM'**
  String get activeProgram2;

  /// No description provided for @age.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get age;

  /// No description provided for @weight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weight;

  /// No description provided for @height.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get height;

  /// No description provided for @goal.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get goal;

  /// No description provided for @calorieGoal.
  ///
  /// In en, this message translates to:
  /// **'Calories'**
  String get calorieGoal;

  /// No description provided for @proteinGoal.
  ///
  /// In en, this message translates to:
  /// **'Protein'**
  String get proteinGoal;

  /// No description provided for @weeklyWorkouts.
  ///
  /// In en, this message translates to:
  /// **'Workouts'**
  String get weeklyWorkouts;

  /// No description provided for @workoutsLabel.
  ///
  /// In en, this message translates to:
  /// **'Workouts'**
  String get workoutsLabel;

  /// No description provided for @caloriesLabel.
  ///
  /// In en, this message translates to:
  /// **'Calories'**
  String get caloriesLabel;

  /// No description provided for @estimatedOneRM.
  ///
  /// In en, this message translates to:
  /// **'Estimated 1RM over time'**
  String get estimatedOneRM;

  /// No description provided for @editGoals.
  ///
  /// In en, this message translates to:
  /// **'EDIT GOALS'**
  String get editGoals;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'SIGN OUT'**
  String get signOut;

  /// No description provided for @editGoalsTitle.
  ///
  /// In en, this message translates to:
  /// **'EDIT GOALS'**
  String get editGoalsTitle;

  /// No description provided for @dailyCalories.
  ///
  /// In en, this message translates to:
  /// **'Daily Calories'**
  String get dailyCalories;

  /// No description provided for @dailyProtein.
  ///
  /// In en, this message translates to:
  /// **'Daily Protein'**
  String get dailyProtein;

  /// No description provided for @signOutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get signOutConfirm;

  /// No description provided for @signOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOutTitle;

  /// No description provided for @weeklyWorkoutsLabel.
  ///
  /// In en, this message translates to:
  /// **'Weekly Workouts'**
  String get weeklyWorkoutsLabel;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'CoreGym'**
  String get loginSubtitle;

  /// No description provided for @loginDesc.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue your fitness journey'**
  String get loginDesc;

  /// No description provided for @operatorId.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get operatorId;

  /// No description provided for @encryptedKey.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get encryptedKey;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'name@example.com'**
  String get emailHint;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'••••••••'**
  String get passwordHint;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @initializeSession.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get initializeSession;

  /// No description provided for @externalAuth.
  ///
  /// In en, this message translates to:
  /// **'Or continue with'**
  String get externalAuth;

  /// No description provided for @google.
  ///
  /// In en, this message translates to:
  /// **'Google'**
  String get google;

  /// No description provided for @apple.
  ///
  /// In en, this message translates to:
  /// **'Apple'**
  String get apple;

  /// No description provided for @newOperative.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get newOperative;

  /// No description provided for @enrollNow.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get enrollNow;

  /// No description provided for @signupTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get signupTitle;

  /// No description provided for @signupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Join Core'**
  String get signupSubtitle;

  /// No description provided for @signupDesc.
  ///
  /// In en, this message translates to:
  /// **'Start your fitness journey today'**
  String get signupDesc;

  /// No description provided for @operativeName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get operativeName;

  /// No description provided for @confirmKey.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmKey;

  /// No description provided for @createOperative.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createOperative;

  /// No description provided for @alreadyEnrolled.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get alreadyEnrolled;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @agreeTerms.
  ///
  /// In en, this message translates to:
  /// **'I agree to the '**
  String get agreeTerms;

  /// No description provided for @termsConditions.
  ///
  /// In en, this message translates to:
  /// **'Terms & Conditions'**
  String get termsConditions;

  /// No description provided for @and.
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get and;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @fullNameHint.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullNameHint;

  /// No description provided for @loginTab.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get loginTab;

  /// No description provided for @signUpTab.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get signUpTab;

  /// No description provided for @trustCalorieTracking.
  ///
  /// In en, this message translates to:
  /// **'Calorie tracking'**
  String get trustCalorieTracking;

  /// No description provided for @trustHydration.
  ///
  /// In en, this message translates to:
  /// **'Hydration'**
  String get trustHydration;

  /// No description provided for @trustWorkouts.
  ///
  /// In en, this message translates to:
  /// **'Workouts'**
  String get trustWorkouts;

  /// No description provided for @trustCoachVerified.
  ///
  /// In en, this message translates to:
  /// **'Coach verified'**
  String get trustCoachVerified;

  /// No description provided for @joiningAs.
  ///
  /// In en, this message translates to:
  /// **'I am joining as'**
  String get joiningAs;

  /// No description provided for @athleteRole.
  ///
  /// In en, this message translates to:
  /// **'Athlete'**
  String get athleteRole;

  /// No description provided for @coachRole.
  ///
  /// In en, this message translates to:
  /// **'Coach'**
  String get coachRole;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @arabic.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get arabic;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @changeLanguage.
  ///
  /// In en, this message translates to:
  /// **'Change Language'**
  String get changeLanguage;

  /// No description provided for @weightLoss.
  ///
  /// In en, this message translates to:
  /// **'Weight Loss'**
  String get weightLoss;

  /// No description provided for @muscleGain.
  ///
  /// In en, this message translates to:
  /// **'Muscle Gain'**
  String get muscleGain;

  /// No description provided for @endurance.
  ///
  /// In en, this message translates to:
  /// **'Endurance'**
  String get endurance;

  /// No description provided for @flexibility.
  ///
  /// In en, this message translates to:
  /// **'Flexibility'**
  String get flexibility;

  /// No description provided for @generalFitness.
  ///
  /// In en, this message translates to:
  /// **'General Fitness'**
  String get generalFitness;

  /// No description provided for @onboarding.
  ///
  /// In en, this message translates to:
  /// **'Setup'**
  String get onboarding;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @back2.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back2;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @yourAge.
  ///
  /// In en, this message translates to:
  /// **'Your Age'**
  String get yourAge;

  /// No description provided for @yourWeight.
  ///
  /// In en, this message translates to:
  /// **'Your Weight'**
  String get yourWeight;

  /// No description provided for @yourHeight.
  ///
  /// In en, this message translates to:
  /// **'Your Height'**
  String get yourHeight;

  /// No description provided for @yourGoal.
  ///
  /// In en, this message translates to:
  /// **'Your Goal'**
  String get yourGoal;

  /// No description provided for @activityLevel.
  ///
  /// In en, this message translates to:
  /// **'Activity Level'**
  String get activityLevel;

  /// No description provided for @targetWeight.
  ///
  /// In en, this message translates to:
  /// **'Target Weight'**
  String get targetWeight;

  /// No description provided for @workoutsPerWeek.
  ///
  /// In en, this message translates to:
  /// **'Workouts Per Week'**
  String get workoutsPerWeek;

  /// No description provided for @sedentary.
  ///
  /// In en, this message translates to:
  /// **'Sedentary'**
  String get sedentary;

  /// No description provided for @lightlyActive.
  ///
  /// In en, this message translates to:
  /// **'Lightly Active'**
  String get lightlyActive;

  /// No description provided for @moderatelyActive.
  ///
  /// In en, this message translates to:
  /// **'Moderately Active'**
  String get moderatelyActive;

  /// No description provided for @veryActive.
  ///
  /// In en, this message translates to:
  /// **'Very Active'**
  String get veryActive;

  /// No description provided for @extraActive.
  ///
  /// In en, this message translates to:
  /// **'Extra Active'**
  String get extraActive;

  /// No description provided for @chatTitle.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get chatTitle;

  /// No description provided for @noConversations.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get noConversations;

  /// No description provided for @noConversationsHint.
  ///
  /// In en, this message translates to:
  /// **'Subscribe to a coach to start chatting'**
  String get noConversationsHint;

  /// No description provided for @typeMessage.
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get typeMessage;

  /// No description provided for @sayHello.
  ///
  /// In en, this message translates to:
  /// **'Say hello! 👋'**
  String get sayHello;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @coach.
  ///
  /// In en, this message translates to:
  /// **'Coach'**
  String get coach;

  /// No description provided for @client.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get client;

  /// No description provided for @scanTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Food Scan'**
  String get scanTitle;

  /// No description provided for @scanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Snap your food, we\'ll do the rest'**
  String get scanSubtitle;

  /// No description provided for @scanSaveToMeal.
  ///
  /// In en, this message translates to:
  /// **'Log this meal to'**
  String get scanSaveToMeal;

  /// No description provided for @scanIdleHint.
  ///
  /// In en, this message translates to:
  /// **'One photo is all it takes — we\'ll detect each item, its weight and calories automatically.'**
  String get scanIdleHint;

  /// No description provided for @scanCameraCta.
  ///
  /// In en, this message translates to:
  /// **'Scan your food'**
  String get scanCameraCta;

  /// No description provided for @scanGalleryCta.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get scanGalleryCta;

  /// No description provided for @scanAnalyzingTitle.
  ///
  /// In en, this message translates to:
  /// **'Analyzing your photo…'**
  String get scanAnalyzingTitle;

  /// No description provided for @scanAnalyzingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Detecting items, weight & macros'**
  String get scanAnalyzingSubtitle;

  /// No description provided for @scanItemsHeader.
  ///
  /// In en, this message translates to:
  /// **'Detected items'**
  String get scanItemsHeader;

  /// No description provided for @scanConfidenceHigh.
  ///
  /// In en, this message translates to:
  /// **'High accuracy'**
  String get scanConfidenceHigh;

  /// No description provided for @scanConfidenceMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium accuracy'**
  String get scanConfidenceMedium;

  /// No description provided for @scanConfidenceLow.
  ///
  /// In en, this message translates to:
  /// **'Low accuracy'**
  String get scanConfidenceLow;

  /// No description provided for @scanLogToMeal.
  ///
  /// In en, this message translates to:
  /// **'Log to {meal}'**
  String scanLogToMeal(String meal);

  /// No description provided for @scanErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Oops!'**
  String get scanErrorTitle;

  /// No description provided for @scanRetrySamePhoto.
  ///
  /// In en, this message translates to:
  /// **'Retry same photo'**
  String get scanRetrySamePhoto;

  /// No description provided for @scanNewPhoto.
  ///
  /// In en, this message translates to:
  /// **'New photo'**
  String get scanNewPhoto;

  /// No description provided for @scanErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Check your network and try again.'**
  String get scanErrorNetwork;

  /// No description provided for @scanErrorUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Please sign in first to use the scanner.'**
  String get scanErrorUnauthorized;

  /// No description provided for @scanErrorNotFood.
  ///
  /// In en, this message translates to:
  /// **'No clear food in the photo. Try another angle.'**
  String get scanErrorNotFood;

  /// No description provided for @scanErrorAnalysis.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t analyze the photo. Please try again.'**
  String get scanErrorAnalysis;

  /// No description provided for @scanErrorPersist.
  ///
  /// In en, this message translates to:
  /// **'The photo was analyzed but saving failed. Please try again.'**
  String get scanErrorPersist;

  /// No description provided for @scanErrorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something unexpected went wrong. Please try again.'**
  String get scanErrorUnknown;

  /// No description provided for @voiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Voice Food Log'**
  String get voiceTitle;

  /// No description provided for @voiceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Just say what you ate'**
  String get voiceSubtitle;

  /// No description provided for @voiceIdleHint.
  ///
  /// In en, this message translates to:
  /// **'Describe your meal in one sentence — we\'ll transcribe it and estimate the calories automatically.'**
  String get voiceIdleHint;

  /// No description provided for @voiceRecordCta.
  ///
  /// In en, this message translates to:
  /// **'Start recording'**
  String get voiceRecordCta;

  /// No description provided for @voiceStopCta.
  ///
  /// In en, this message translates to:
  /// **'Stop & analyze'**
  String get voiceStopCta;

  /// No description provided for @voiceRecordingHint.
  ///
  /// In en, this message translates to:
  /// **'Listening… tap stop when you\'re done describing your meal.'**
  String get voiceRecordingHint;

  /// No description provided for @voiceAnalyzingTitle.
  ///
  /// In en, this message translates to:
  /// **'Analyzing your recording…'**
  String get voiceAnalyzingTitle;

  /// No description provided for @voiceTranscriptLabel.
  ///
  /// In en, this message translates to:
  /// **'You said'**
  String get voiceTranscriptLabel;

  /// No description provided for @voiceRetrySameAudio.
  ///
  /// In en, this message translates to:
  /// **'Retry same recording'**
  String get voiceRetrySameAudio;

  /// No description provided for @voiceNewRecording.
  ///
  /// In en, this message translates to:
  /// **'New recording'**
  String get voiceNewRecording;

  /// No description provided for @voiceErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Check your network and try again.'**
  String get voiceErrorNetwork;

  /// No description provided for @voiceErrorUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Please sign in first to use the voice logger.'**
  String get voiceErrorUnauthorized;

  /// No description provided for @voiceErrorMicrophone.
  ///
  /// In en, this message translates to:
  /// **'Microphone access is needed. Enable it in Settings and try again.'**
  String get voiceErrorMicrophone;

  /// No description provided for @voiceErrorNotFood.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t hear any food in that recording. Try describing your meal again.'**
  String get voiceErrorNotFood;

  /// No description provided for @voiceErrorAnalysis.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t understand that recording. Please try again.'**
  String get voiceErrorAnalysis;

  /// No description provided for @voiceErrorPersist.
  ///
  /// In en, this message translates to:
  /// **'The recording was analyzed but saving failed. Please try again.'**
  String get voiceErrorPersist;

  /// No description provided for @voiceErrorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something unexpected went wrong. Please try again.'**
  String get voiceErrorUnknown;

  /// No description provided for @textTitle.
  ///
  /// In en, this message translates to:
  /// **'Text Food Log'**
  String get textTitle;

  /// No description provided for @textSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Type what you ate'**
  String get textSubtitle;

  /// No description provided for @textInputHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. breakfast: 2 eggs, toast and tea…'**
  String get textInputHint;

  /// No description provided for @textAnalyzeCta.
  ///
  /// In en, this message translates to:
  /// **'Analyze with AI'**
  String get textAnalyzeCta;

  /// No description provided for @textAnalyzingTitle.
  ///
  /// In en, this message translates to:
  /// **'Analyzing your meal…'**
  String get textAnalyzingTitle;

  /// No description provided for @textEmptyInput.
  ///
  /// In en, this message translates to:
  /// **'Type what you ate first, then tap analyze.'**
  String get textEmptyInput;

  /// No description provided for @textWroteLabel.
  ///
  /// In en, this message translates to:
  /// **'You wrote'**
  String get textWroteLabel;

  /// No description provided for @textErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Check your network and try again.'**
  String get textErrorNetwork;

  /// No description provided for @textErrorUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Please sign in first to use the text logger.'**
  String get textErrorUnauthorized;

  /// No description provided for @textErrorNotFood.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find any food in that text. Try describing your meal again.'**
  String get textErrorNotFood;

  /// No description provided for @textErrorAnalysis.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t understand that description. Please try again.'**
  String get textErrorAnalysis;

  /// No description provided for @textErrorPersist.
  ///
  /// In en, this message translates to:
  /// **'The meal was analyzed but saving failed. Please try again.'**
  String get textErrorPersist;

  /// No description provided for @textErrorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something unexpected went wrong. Please try again.'**
  String get textErrorUnknown;

  /// No description provided for @textEditDescription.
  ///
  /// In en, this message translates to:
  /// **'Edit description'**
  String get textEditDescription;

  /// No description provided for @textNewDescription.
  ///
  /// In en, this message translates to:
  /// **'New description'**
  String get textNewDescription;

  /// No description provided for @profileFirstRunNudge.
  ///
  /// In en, this message translates to:
  /// **'Log your first workout to start ranking up!'**
  String get profileFirstRunNudge;

  /// No description provided for @dashboardEyebrow.
  ///
  /// In en, this message translates to:
  /// **'MY DASHBOARD'**
  String get dashboardEyebrow;

  /// No description provided for @dashboardSubscribers.
  ///
  /// In en, this message translates to:
  /// **'Subscribers'**
  String get dashboardSubscribers;

  /// No description provided for @subscriberCount.
  ///
  /// In en, this message translates to:
  /// **'{count} total'**
  String subscriberCount(int count);

  /// No description provided for @statActiveSubscribers.
  ///
  /// In en, this message translates to:
  /// **'Active\nSubscribers'**
  String get statActiveSubscribers;

  /// No description provided for @statAvgRating.
  ///
  /// In en, this message translates to:
  /// **'Avg\nRating'**
  String get statAvgRating;

  /// No description provided for @statMonthlyRevenue.
  ///
  /// In en, this message translates to:
  /// **'Monthly\nRevenue'**
  String get statMonthlyRevenue;

  /// No description provided for @statOpenSlots.
  ///
  /// In en, this message translates to:
  /// **'Open\nSlots'**
  String get statOpenSlots;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get filterActive;

  /// No description provided for @filterPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get filterPending;

  /// No description provided for @filterExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get filterExpired;

  /// No description provided for @noSubscribersYet.
  ///
  /// In en, this message translates to:
  /// **'No subscribers yet'**
  String get noSubscribersYet;

  /// No description provided for @completeProfileHint.
  ///
  /// In en, this message translates to:
  /// **'Complete your coach profile so clients can find and subscribe to you.'**
  String get completeProfileHint;

  /// No description provided for @completeProfileCta.
  ///
  /// In en, this message translates to:
  /// **'Complete Your Profile'**
  String get completeProfileCta;

  /// No description provided for @failedToLoadStats.
  ///
  /// In en, this message translates to:
  /// **'Failed to load stats: {error}'**
  String failedToLoadStats(String error);

  /// No description provided for @daysLeft.
  ///
  /// In en, this message translates to:
  /// **'{n} days left'**
  String daysLeft(int n);

  /// No description provided for @daysRemaining.
  ///
  /// In en, this message translates to:
  /// **'{n} days remaining'**
  String daysRemaining(int n);

  /// No description provided for @statusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get statusExpired;

  /// No description provided for @statusPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get statusPaused;

  /// No description provided for @statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// No description provided for @planPhases.
  ///
  /// In en, this message translates to:
  /// **'PLAN PHASES'**
  String get planPhases;

  /// No description provided for @paymentPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paymentPaid;

  /// No description provided for @paymentUnpaid.
  ///
  /// In en, this message translates to:
  /// **'Unpaid'**
  String get paymentUnpaid;

  /// No description provided for @paymentRefunded.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get paymentRefunded;

  /// No description provided for @phaseWeek.
  ///
  /// In en, this message translates to:
  /// **'Week {w}'**
  String phaseWeek(int w);

  /// No description provided for @previousDay.
  ///
  /// In en, this message translates to:
  /// **'Previous day'**
  String get previousDay;

  /// No description provided for @nextDay.
  ///
  /// In en, this message translates to:
  /// **'Next day'**
  String get nextDay;

  /// No description provided for @smartwatchSync.
  ///
  /// In en, this message translates to:
  /// **'Smartwatch sync'**
  String get smartwatchSync;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @themeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeMode;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save — check your connection and try again.'**
  String get saveFailed;

  /// No description provided for @aiScanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Snap your meal — AI logs it for you'**
  String get aiScanSubtitle;

  /// No description provided for @logAnotherWay.
  ///
  /// In en, this message translates to:
  /// **'Or log another way'**
  String get logAnotherWay;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @markAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get markAllRead;

  /// No description provided for @notificationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get notificationsEmpty;

  /// No description provided for @onbSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onbSkip;

  /// No description provided for @onbNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onbNext;

  /// No description provided for @onbInitiate.
  ///
  /// In en, this message translates to:
  /// **'INITIATE ENGINE'**
  String get onbInitiate;

  /// No description provided for @onbAlreadyMember.
  ///
  /// In en, this message translates to:
  /// **'ALREADY A MEMBER?'**
  String get onbAlreadyMember;

  /// No description provided for @onbSignInLink.
  ///
  /// In en, this message translates to:
  /// **'SIGN IN'**
  String get onbSignInLink;

  /// No description provided for @onbStepLabel.
  ///
  /// In en, this message translates to:
  /// **'STEP'**
  String get onbStepLabel;

  /// No description provided for @onb1Title.
  ///
  /// In en, this message translates to:
  /// **'Transform your\nbody and mind'**
  String get onb1Title;

  /// No description provided for @onb1Desc.
  ///
  /// In en, this message translates to:
  /// **'Discover the power within you. Our comprehensive fitness programs are designed to help you achieve your goals and unlock your full potential.'**
  String get onb1Desc;

  /// No description provided for @onb2Title.
  ///
  /// In en, this message translates to:
  /// **'Snap your meal\nAI tracks it'**
  String get onb2Title;

  /// No description provided for @onb2Desc.
  ///
  /// In en, this message translates to:
  /// **'Point your camera at any plate — AI reads it and logs calories, protein, carbs and fat in seconds. You can also log by voice or text.'**
  String get onb2Desc;

  /// No description provided for @onb3Title.
  ///
  /// In en, this message translates to:
  /// **'Nutrition built\naround you'**
  String get onb3Title;

  /// No description provided for @onb3Desc.
  ///
  /// In en, this message translates to:
  /// **'Daily calorie and macro targets calculated for your body, hydration reminders on schedule, and coaches who adapt your plan as you progress.'**
  String get onb3Desc;

  /// No description provided for @onbSelectYour.
  ///
  /// In en, this message translates to:
  /// **'SELECT YOUR'**
  String get onbSelectYour;

  /// No description provided for @onbIdentity.
  ///
  /// In en, this message translates to:
  /// **'IDENTITY'**
  String get onbIdentity;

  /// No description provided for @onbPersonalize.
  ///
  /// In en, this message translates to:
  /// **'HELP US PERSONALIZE YOUR EXPERIENCE\nWITH CONTENT THAT MATTERS TO YOU'**
  String get onbPersonalize;

  /// No description provided for @onbFemale.
  ///
  /// In en, this message translates to:
  /// **'FEMALE'**
  String get onbFemale;

  /// No description provided for @onbMale.
  ///
  /// In en, this message translates to:
  /// **'MALE'**
  String get onbMale;

  /// No description provided for @onbContinue.
  ///
  /// In en, this message translates to:
  /// **'CONTINUE'**
  String get onbContinue;

  /// No description provided for @flow1Title.
  ///
  /// In en, this message translates to:
  /// **'Let\'s get to\nknow you'**
  String get flow1Title;

  /// No description provided for @flow1Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your basic info'**
  String get flow1Subtitle;

  /// No description provided for @flow2Title.
  ///
  /// In en, this message translates to:
  /// **'Your current\nbody'**
  String get flow2Title;

  /// No description provided for @flow2Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Help us tailor your plan'**
  String get flow2Subtitle;

  /// No description provided for @flow3Title.
  ///
  /// In en, this message translates to:
  /// **'What\'s your\ngoal?'**
  String get flow3Title;

  /// No description provided for @flow3Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Select your primary focus'**
  String get flow3Subtitle;

  /// No description provided for @flow4Title.
  ///
  /// In en, this message translates to:
  /// **'How fast do you\nwant results?'**
  String get flow4Title;

  /// No description provided for @flow4Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Your pace sets the calorie adjustment'**
  String get flow4Subtitle;

  /// No description provided for @flowPaceNotNeeded.
  ///
  /// In en, this message translates to:
  /// **'Your goal is about performance — calories stay at full burn, no pace adjustment needed.'**
  String get flowPaceNotNeeded;

  /// No description provided for @flow5Title.
  ///
  /// In en, this message translates to:
  /// **'How active\nare you?'**
  String get flow5Title;

  /// No description provided for @flow5Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Helps calculate your nutrition'**
  String get flow5Subtitle;

  /// No description provided for @flow6Title.
  ///
  /// In en, this message translates to:
  /// **'Set your\ntargets'**
  String get flow6Title;

  /// No description provided for @flow6Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Build your routine'**
  String get flow6Subtitle;

  /// No description provided for @flowAge.
  ///
  /// In en, this message translates to:
  /// **'AGE'**
  String get flowAge;

  /// No description provided for @flowGender.
  ///
  /// In en, this message translates to:
  /// **'GENDER'**
  String get flowGender;

  /// No description provided for @flowHeight.
  ///
  /// In en, this message translates to:
  /// **'HEIGHT (CM)'**
  String get flowHeight;

  /// No description provided for @flowWeight.
  ///
  /// In en, this message translates to:
  /// **'WEIGHT (KG)'**
  String get flowWeight;

  /// No description provided for @flowBodyFat.
  ///
  /// In en, this message translates to:
  /// **'BODY FAT %'**
  String get flowBodyFat;

  /// No description provided for @flowOptional.
  ///
  /// In en, this message translates to:
  /// **'OPTIONAL'**
  String get flowOptional;

  /// No description provided for @flowKnowBodyFat.
  ///
  /// In en, this message translates to:
  /// **'I know my body fat %'**
  String get flowKnowBodyFat;

  /// No description provided for @flowBodyFatHint.
  ///
  /// In en, this message translates to:
  /// **'Lean-mass math (Katch-McArdle) — the most precise estimate'**
  String get flowBodyFatHint;

  /// No description provided for @flowTargetWeight.
  ///
  /// In en, this message translates to:
  /// **'TARGET WEIGHT'**
  String get flowTargetWeight;

  /// No description provided for @flowYears.
  ///
  /// In en, this message translates to:
  /// **'years'**
  String get flowYears;

  /// No description provided for @flowGoalDescGain.
  ///
  /// In en, this message translates to:
  /// **'Build strength and mass'**
  String get flowGoalDescGain;

  /// No description provided for @flowGoalDescLoss.
  ///
  /// In en, this message translates to:
  /// **'Burn fat, feel lighter'**
  String get flowGoalDescLoss;

  /// No description provided for @flowGoalDescEndurance.
  ///
  /// In en, this message translates to:
  /// **'Improve stamina and cardio'**
  String get flowGoalDescEndurance;

  /// No description provided for @flowGoalDescFlex.
  ///
  /// In en, this message translates to:
  /// **'Move better, recover faster'**
  String get flowGoalDescFlex;

  /// No description provided for @flowGoalDescGeneral.
  ///
  /// In en, this message translates to:
  /// **'Stay healthy and active'**
  String get flowGoalDescGeneral;

  /// No description provided for @flowPaceSlow.
  ///
  /// In en, this message translates to:
  /// **'Steady'**
  String get flowPaceSlow;

  /// No description provided for @flowPaceStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get flowPaceStandard;

  /// No description provided for @flowPaceFast.
  ///
  /// In en, this message translates to:
  /// **'Fast'**
  String get flowPaceFast;

  /// No description provided for @flowPaceDescSlow.
  ///
  /// In en, this message translates to:
  /// **'{delta} kcal / day — gentler on your routine'**
  String flowPaceDescSlow(int delta);

  /// No description provided for @flowPaceDescStandard.
  ///
  /// In en, this message translates to:
  /// **'{delta} kcal / day — the classic rate'**
  String flowPaceDescStandard(int delta);

  /// No description provided for @flowPaceDescFast.
  ///
  /// In en, this message translates to:
  /// **'{delta} kcal / day — demanding, needs discipline'**
  String flowPaceDescFast(int delta);

  /// No description provided for @flowActDescSedentary.
  ///
  /// In en, this message translates to:
  /// **'Little to no exercise'**
  String get flowActDescSedentary;

  /// No description provided for @flowActDescLight.
  ///
  /// In en, this message translates to:
  /// **'1–3 days / week'**
  String get flowActDescLight;

  /// No description provided for @flowActDescModerate.
  ///
  /// In en, this message translates to:
  /// **'3–5 days / week'**
  String get flowActDescModerate;

  /// No description provided for @flowActDescVery.
  ///
  /// In en, this message translates to:
  /// **'6–7 days / week'**
  String get flowActDescVery;

  /// No description provided for @flowActDescExtra.
  ///
  /// In en, this message translates to:
  /// **'Twice daily / athlete'**
  String get flowActDescExtra;

  /// No description provided for @flowEstDaily.
  ///
  /// In en, this message translates to:
  /// **'Est. daily calories:'**
  String get flowEstDaily;

  /// No description provided for @flowBmiTitle.
  ///
  /// In en, this message translates to:
  /// **'Your BMI'**
  String get flowBmiTitle;

  /// No description provided for @flowBmiUnder.
  ///
  /// In en, this message translates to:
  /// **'Underweight'**
  String get flowBmiUnder;

  /// No description provided for @flowBmiNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get flowBmiNormal;

  /// No description provided for @flowBmiOver.
  ///
  /// In en, this message translates to:
  /// **'Overweight'**
  String get flowBmiOver;

  /// No description provided for @flowBmiObese.
  ///
  /// In en, this message translates to:
  /// **'Obese'**
  String get flowBmiObese;

  /// No description provided for @flowGainInsight.
  ///
  /// In en, this message translates to:
  /// **'Gain {diff} kg from current weight'**
  String flowGainInsight(String diff);

  /// No description provided for @flowLoseInsight.
  ///
  /// In en, this message translates to:
  /// **'Lose {diff} kg from current weight'**
  String flowLoseInsight(String diff);

  /// No description provided for @flowAllSet.
  ///
  /// In en, this message translates to:
  /// **'You\'re all set!'**
  String get flowAllSet;

  /// No description provided for @flowAllSetDesc.
  ///
  /// In en, this message translates to:
  /// **'Here\'s the plan your numbers built — change anything and it updates live.'**
  String get flowAllSetDesc;

  /// No description provided for @flowResultDaily.
  ///
  /// In en, this message translates to:
  /// **'YOUR DAILY TARGET'**
  String get flowResultDaily;

  /// No description provided for @flowResultBmr.
  ///
  /// In en, this message translates to:
  /// **'Resting burn (BMR)'**
  String get flowResultBmr;

  /// No description provided for @flowResultActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity burn'**
  String get flowResultActivity;

  /// No description provided for @flowResultGoal.
  ///
  /// In en, this message translates to:
  /// **'Goal adjustment'**
  String get flowResultGoal;

  /// No description provided for @flowResultMacros.
  ///
  /// In en, this message translates to:
  /// **'RECOMMENDED MACROS'**
  String get flowResultMacros;

  /// No description provided for @flowKcalDay.
  ///
  /// In en, this message translates to:
  /// **'kcal / day'**
  String get flowKcalDay;

  /// No description provided for @flowContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get flowContinue;

  /// No description provided for @flowComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get flowComplete;

  /// No description provided for @pushDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable notifications'**
  String get pushDialogTitle;

  /// No description provided for @pushDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Enable notifications so we can remind you about meals, water and your daily calorie goal.'**
  String get pushDialogBody;

  /// No description provided for @pushDialogCta.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get pushDialogCta;

  /// No description provided for @splashError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t connect. Check your internet and try again.'**
  String get splashError;

  /// No description provided for @splashLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get splashLoading;

  /// No description provided for @rankTitle.
  ///
  /// In en, this message translates to:
  /// **'Rankings'**
  String get rankTitle;

  /// No description provided for @rankLast7.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get rankLast7;

  /// No description provided for @rankLast30.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get rankLast30;

  /// No description provided for @rankEmpty.
  ///
  /// In en, this message translates to:
  /// **'No ranked clients yet. Log your meals and water to enter the board!'**
  String get rankEmpty;

  /// No description provided for @rankDaysLogged.
  ///
  /// In en, this message translates to:
  /// **'{n} days logged'**
  String rankDaysLogged(int n);

  /// No description provided for @cpDaysLoggedN.
  ///
  /// In en, this message translates to:
  /// **'{n} days'**
  String cpDaysLoggedN(int n);

  /// No description provided for @cpDaysLogged.
  ///
  /// In en, this message translates to:
  /// **'Days logged'**
  String get cpDaysLogged;

  /// No description provided for @cpAvgScore.
  ///
  /// In en, this message translates to:
  /// **'Avg score'**
  String get cpAvgScore;

  /// No description provided for @cpWorkouts.
  ///
  /// In en, this message translates to:
  /// **'Workouts'**
  String get cpWorkouts;

  /// No description provided for @cpCommitment.
  ///
  /// In en, this message translates to:
  /// **'Commitment activity'**
  String get cpCommitment;

  /// No description provided for @cpLess.
  ///
  /// In en, this message translates to:
  /// **'Less'**
  String get cpLess;

  /// No description provided for @cpMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get cpMore;

  /// No description provided for @cpTrend.
  ///
  /// In en, this message translates to:
  /// **'Trend'**
  String get cpTrend;

  /// No description provided for @cpDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get cpDaily;

  /// No description provided for @cpWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get cpWeekly;

  /// No description provided for @cpCumulative.
  ///
  /// In en, this message translates to:
  /// **'Cumulative'**
  String get cpCumulative;

  /// No description provided for @cpCalories.
  ///
  /// In en, this message translates to:
  /// **'Calories'**
  String get cpCalories;

  /// No description provided for @cpWater.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get cpWater;

  /// No description provided for @cpSteps.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get cpSteps;

  /// No description provided for @cpNoData.
  ///
  /// In en, this message translates to:
  /// **'No data logged yet'**
  String get cpNoData;

  /// No description provided for @cpActivityPrivate.
  ///
  /// In en, this message translates to:
  /// **'This member keeps their daily activity private — you\'re seeing their competitive standing only.'**
  String get cpActivityPrivate;

  /// No description provided for @rankCard.
  ///
  /// In en, this message translates to:
  /// **'Rankings'**
  String get rankCard;

  /// No description provided for @rankCardSub.
  ///
  /// In en, this message translates to:
  /// **'Weekly leaderboard'**
  String get rankCardSub;

  /// No description provided for @assignedWorkoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Workout'**
  String get assignedWorkoutTitle;

  /// No description provided for @assignedNutritionTitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Nutrition'**
  String get assignedNutritionTitle;

  /// No description provided for @assignedNutritionNoPlan.
  ///
  /// In en, this message translates to:
  /// **'No nutrition plan assigned'**
  String get assignedNutritionNoPlan;

  /// No description provided for @assignedNutritionNoPlanBody.
  ///
  /// In en, this message translates to:
  /// **'Your coach hasn\'t assigned a nutrition plan for today yet.'**
  String get assignedNutritionNoPlanBody;

  /// No description provided for @assignedNutritionNoMealsToday.
  ///
  /// In en, this message translates to:
  /// **'No meals assigned for today'**
  String get assignedNutritionNoMealsToday;

  /// No description provided for @assignedNutritionStatMeals.
  ///
  /// In en, this message translates to:
  /// **'Meals'**
  String get assignedNutritionStatMeals;

  /// No description provided for @assignedNutritionStatFoods.
  ///
  /// In en, this message translates to:
  /// **'Foods'**
  String get assignedNutritionStatFoods;

  /// No description provided for @assignedNutritionStatusAssigned.
  ///
  /// In en, this message translates to:
  /// **'Assigned'**
  String get assignedNutritionStatusAssigned;

  /// No description provided for @assignedNutritionStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get assignedNutritionStatusCompleted;

  /// No description provided for @assignedNutritionStatusSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get assignedNutritionStatusSkipped;

  /// No description provided for @assignedNutritionChanged.
  ///
  /// In en, this message translates to:
  /// **'Changed'**
  String get assignedNutritionChanged;

  /// No description provided for @assignedNutritionMealTotal.
  ///
  /// In en, this message translates to:
  /// **'Meal total'**
  String get assignedNutritionMealTotal;

  /// No description provided for @assignedNutritionMarkEaten.
  ///
  /// In en, this message translates to:
  /// **'Mark as eaten'**
  String get assignedNutritionMarkEaten;

  /// No description provided for @assignedNutritionMarkedEaten.
  ///
  /// In en, this message translates to:
  /// **'Meal logged — calories added to today'**
  String get assignedNutritionMarkedEaten;

  /// No description provided for @assignedNutritionMarkFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t mark the meal — try again'**
  String get assignedNutritionMarkFailed;

  /// No description provided for @assignedNutritionNextDay.
  ///
  /// In en, this message translates to:
  /// **'No meals today — showing next scheduled day: {date}'**
  String assignedNutritionNextDay(String date);

  /// No description provided for @assignedCardMeta.
  ///
  /// In en, this message translates to:
  /// **'{ex} exercises · ~{min} min'**
  String assignedCardMeta(int ex, int min);

  /// No description provided for @assignedSetProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} sets done'**
  String assignedSetProgress(int done, int total);

  /// No description provided for @assignedRestSecs.
  ///
  /// In en, this message translates to:
  /// **'Rest {sec}s'**
  String assignedRestSecs(int sec);

  /// No description provided for @assignedLogSet.
  ///
  /// In en, this message translates to:
  /// **'Log Set'**
  String get assignedLogSet;

  /// No description provided for @assignedContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue Workout'**
  String get assignedContinue;

  /// No description provided for @assignedFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish Workout'**
  String get assignedFinish;

  /// No description provided for @assignedResume.
  ///
  /// In en, this message translates to:
  /// **'Resume workout'**
  String get assignedResume;

  /// No description provided for @assignedReadyHint.
  ///
  /// In en, this message translates to:
  /// **'Ready to go — tap to start'**
  String get assignedReadyHint;

  /// No description provided for @assignedStatExercises.
  ///
  /// In en, this message translates to:
  /// **'Exercises'**
  String get assignedStatExercises;

  /// No description provided for @assignedStatSets.
  ///
  /// In en, this message translates to:
  /// **'Sets'**
  String get assignedStatSets;

  /// No description provided for @assignedStatTime.
  ///
  /// In en, this message translates to:
  /// **'Est. time'**
  String get assignedStatTime;

  /// No description provided for @assignedDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Workout completed'**
  String get assignedDoneTitle;

  /// No description provided for @assignedDoneBody.
  ///
  /// In en, this message translates to:
  /// **'Nice work — your coach can see this session now.'**
  String get assignedDoneBody;

  /// No description provided for @assignedSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip workout'**
  String get assignedSkip;

  /// No description provided for @assignedSkipConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Skip this workout?'**
  String get assignedSkipConfirmTitle;

  /// No description provided for @assignedSkipConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'It will be marked as skipped and your coach will see it that way.'**
  String get assignedSkipConfirmBody;

  /// No description provided for @assignedSkippedDone.
  ///
  /// In en, this message translates to:
  /// **'Workout skipped'**
  String get assignedSkippedDone;

  /// No description provided for @assignedHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Coach assignments'**
  String get assignedHistoryTitle;

  /// No description provided for @assignedStatusAssigned.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get assignedStatusAssigned;

  /// No description provided for @assignedStatusStarted.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get assignedStatusStarted;

  /// No description provided for @assignedStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get assignedStatusCompleted;

  /// No description provided for @assignedStatusSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get assignedStatusSkipped;

  /// No description provided for @assignedNone.
  ///
  /// In en, this message translates to:
  /// **'No workout assigned today'**
  String get assignedNone;

  /// No description provided for @assignedNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get assignedNotes;

  /// No description provided for @assignedTarget.
  ///
  /// In en, this message translates to:
  /// **'{sets} sets × {reps} reps'**
  String assignedTarget(String sets, String reps);

  /// No description provided for @assignedTargetWeight.
  ///
  /// In en, this message translates to:
  /// **'{sets} sets × {reps} reps @ {weight} kg'**
  String assignedTargetWeight(String sets, String reps, String weight);

  /// No description provided for @assignedErrorStart.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start the workout — try again'**
  String get assignedErrorStart;

  /// No description provided for @assignedErrorSet.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t log the set — check your connection'**
  String get assignedErrorSet;

  /// No description provided for @assignedErrorFinish.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t finish the workout — try again'**
  String get assignedErrorFinish;

  /// No description provided for @assignedEnterReps.
  ///
  /// In en, this message translates to:
  /// **'Enter the reps first'**
  String get assignedEnterReps;

  /// No description provided for @assignedSetsLogged.
  ///
  /// In en, this message translates to:
  /// **'{count} sets logged'**
  String assignedSetsLogged(int count);

  /// No description provided for @assignedDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get assignedDone;

  /// No description provided for @foodTargetingMeal.
  ///
  /// In en, this message translates to:
  /// **'Targeting: {meal}'**
  String foodTargetingMeal(String meal);

  /// No description provided for @foodPopularFoods.
  ///
  /// In en, this message translates to:
  /// **'POPULAR FOODS'**
  String get foodPopularFoods;

  /// No description provided for @foodResultsFound.
  ///
  /// In en, this message translates to:
  /// **'{count} results found'**
  String foodResultsFound(int count);

  /// No description provided for @foodFilters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get foodFilters;

  /// No description provided for @foodFilterCalories.
  ///
  /// In en, this message translates to:
  /// **'Calories (kcal)'**
  String get foodFilterCalories;

  /// No description provided for @foodFilterProtein.
  ///
  /// In en, this message translates to:
  /// **'Protein (g)'**
  String get foodFilterProtein;

  /// No description provided for @foodFilterAny.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get foodFilterAny;

  /// No description provided for @foodFilterKcal.
  ///
  /// In en, this message translates to:
  /// **'kcal'**
  String get foodFilterKcal;

  /// No description provided for @foodFilterGrams.
  ///
  /// In en, this message translates to:
  /// **'g'**
  String get foodFilterGrams;

  /// No description provided for @foodApplyFilters.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get foodApplyFilters;

  /// No description provided for @foodResetFilters.
  ///
  /// In en, this message translates to:
  /// **'Reset filters'**
  String get foodResetFilters;

  /// No description provided for @foodNoResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'No foods match your filters'**
  String get foodNoResultsTitle;

  /// No description provided for @foodNoResultsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Try widening the ranges or reset the filters'**
  String get foodNoResultsSubtitle;

  /// No description provided for @foodNoFoodsTitle.
  ///
  /// In en, this message translates to:
  /// **'No foods found'**
  String get foodNoFoodsTitle;

  /// No description provided for @foodNoFoodsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Try another spelling or search keyword'**
  String get foodNoFoodsSubtitle;

  /// No description provided for @catArabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get catArabic;

  /// No description provided for @catProtein.
  ///
  /// In en, this message translates to:
  /// **'Protein'**
  String get catProtein;

  /// No description provided for @catCarbs.
  ///
  /// In en, this message translates to:
  /// **'Carbs'**
  String get catCarbs;

  /// No description provided for @catVegetables.
  ///
  /// In en, this message translates to:
  /// **'Veggies'**
  String get catVegetables;

  /// No description provided for @catFruits.
  ///
  /// In en, this message translates to:
  /// **'Fruits'**
  String get catFruits;

  /// No description provided for @catDairy.
  ///
  /// In en, this message translates to:
  /// **'Dairy'**
  String get catDairy;

  /// No description provided for @catFats.
  ///
  /// In en, this message translates to:
  /// **'Fats'**
  String get catFats;

  /// No description provided for @catFastfood.
  ///
  /// In en, this message translates to:
  /// **'Fast Food'**
  String get catFastfood;

  /// No description provided for @catDrinks.
  ///
  /// In en, this message translates to:
  /// **'Drinks'**
  String get catDrinks;

  /// No description provided for @catSnacks.
  ///
  /// In en, this message translates to:
  /// **'Snacks'**
  String get catSnacks;

  /// No description provided for @catDesserts.
  ///
  /// In en, this message translates to:
  /// **'Desserts'**
  String get catDesserts;

  /// No description provided for @catStreetFood.
  ///
  /// In en, this message translates to:
  /// **'Street Food'**
  String get catStreetFood;

  /// No description provided for @catBurgers.
  ///
  /// In en, this message translates to:
  /// **'Burgers'**
  String get catBurgers;

  /// No description provided for @catPizza.
  ///
  /// In en, this message translates to:
  /// **'Pizza'**
  String get catPizza;

  /// No description provided for @catPasta.
  ///
  /// In en, this message translates to:
  /// **'Pasta'**
  String get catPasta;

  /// No description provided for @catSandwiches.
  ///
  /// In en, this message translates to:
  /// **'Sandwiches'**
  String get catSandwiches;

  /// No description provided for @catSushi.
  ///
  /// In en, this message translates to:
  /// **'Sushi'**
  String get catSushi;

  /// No description provided for @catFriedChicken.
  ///
  /// In en, this message translates to:
  /// **'Fried Chicken'**
  String get catFriedChicken;

  /// No description provided for @catBreakfast.
  ///
  /// In en, this message translates to:
  /// **'Breakfast'**
  String get catBreakfast;

  /// No description provided for @catOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get catOther;

  /// No description provided for @foodLogSaveError.
  ///
  /// In en, this message translates to:
  /// **'❌ An error occurred while saving — check your internet connection'**
  String get foodLogSaveError;

  /// No description provided for @foodLogPer100g.
  ///
  /// In en, this message translates to:
  /// **'per 100g'**
  String get foodLogPer100g;

  /// No description provided for @foodLogCalories.
  ///
  /// In en, this message translates to:
  /// **'Calories'**
  String get foodLogCalories;

  /// No description provided for @foodLogProtein.
  ///
  /// In en, this message translates to:
  /// **'Protein'**
  String get foodLogProtein;

  /// No description provided for @foodLogCarbs.
  ///
  /// In en, this message translates to:
  /// **'Carbs'**
  String get foodLogCarbs;

  /// No description provided for @foodLogFat.
  ///
  /// In en, this message translates to:
  /// **'Fat'**
  String get foodLogFat;

  /// No description provided for @foodLogQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get foodLogQuantity;

  /// No description provided for @foodLogAssignMeal.
  ///
  /// In en, this message translates to:
  /// **'Assign to meal'**
  String get foodLogAssignMeal;

  /// No description provided for @foodLogLogged.
  ///
  /// In en, this message translates to:
  /// **'Logged!'**
  String get foodLogLogged;

  /// No description provided for @foodLogConfirm.
  ///
  /// In en, this message translates to:
  /// **'Log Food'**
  String get foodLogConfirm;

  /// No description provided for @suggestMeal.
  ///
  /// In en, this message translates to:
  /// **'Suggest a meal'**
  String get suggestMeal;

  /// No description provided for @dailyMeals.
  ///
  /// In en, this message translates to:
  /// **'Daily Meals'**
  String get dailyMeals;

  /// No description provided for @itemsLoggedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items logged'**
  String itemsLoggedCount(String count);

  /// No description provided for @kcalRemainingShort.
  ///
  /// In en, this message translates to:
  /// **'{kcal} kcal remaining'**
  String kcalRemainingShort(String kcal);

  /// No description provided for @kcalGoalLabel.
  ///
  /// In en, this message translates to:
  /// **'{kcal} kcal goal'**
  String kcalGoalLabel(String kcal);

  /// No description provided for @ofGoal.
  ///
  /// In en, this message translates to:
  /// **'of {goal}'**
  String ofGoal(String goal);

  /// No description provided for @syncingNutrition.
  ///
  /// In en, this message translates to:
  /// **'Syncing nutrition data...'**
  String get syncingNutrition;

  /// No description provided for @addLabel.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addLabel;

  /// No description provided for @quickLabel.
  ///
  /// In en, this message translates to:
  /// **'Quick'**
  String get quickLabel;

  /// No description provided for @removeLabel.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeLabel;

  /// No description provided for @keepGoing.
  ///
  /// In en, this message translates to:
  /// **'Keep going!'**
  String get keepGoing;

  /// No description provided for @suggestCardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'AI builds a meal that hits your remaining calories'**
  String get suggestCardSubtitle;

  /// No description provided for @suggestSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Suggest a meal'**
  String get suggestSheetTitle;

  /// No description provided for @suggestMealSlot.
  ///
  /// In en, this message translates to:
  /// **'MEAL'**
  String get suggestMealSlot;

  /// No description provided for @suggestStyle.
  ///
  /// In en, this message translates to:
  /// **'STYLE'**
  String get suggestStyle;

  /// No description provided for @suggestCaloriesRow.
  ///
  /// In en, this message translates to:
  /// **'CALORIES'**
  String get suggestCaloriesRow;

  /// No description provided for @suggestCravingLabel.
  ///
  /// In en, this message translates to:
  /// **'CRAVING (OPTIONAL)'**
  String get suggestCravingLabel;

  /// No description provided for @suggestCravingHint.
  ///
  /// In en, this message translates to:
  /// **'The meal in your head — e.g. koshary, burger, shawarma'**
  String get suggestCravingHint;

  /// No description provided for @suggestCaloriesLabel.
  ///
  /// In en, this message translates to:
  /// **'CALORIES'**
  String get suggestCaloriesLabel;

  /// No description provided for @suggestCaloriesHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 550'**
  String get suggestCaloriesHint;

  /// No description provided for @suggestCaloriesInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter 80–5000 kcal'**
  String get suggestCaloriesInvalid;

  /// No description provided for @suggestUseRemaining.
  ///
  /// In en, this message translates to:
  /// **'Use remaining'**
  String get suggestUseRemaining;

  /// No description provided for @suggestCustomCaloriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Your target'**
  String get suggestCustomCaloriesTitle;

  /// No description provided for @suggestCustomCaloriesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Type the calories you want this meal to hit — AI builds exactly to that number'**
  String get suggestCustomCaloriesSubtitle;

  /// No description provided for @suggestGoalMetTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'ve hit your goal'**
  String get suggestGoalMetTitle;

  /// No description provided for @suggestGoalMetBody.
  ///
  /// In en, this message translates to:
  /// **'Your calories for today are covered — there\'s no room left for a suggested meal.'**
  String get suggestGoalMetBody;

  /// No description provided for @suggestMatchLabel.
  ///
  /// In en, this message translates to:
  /// **'match'**
  String get suggestMatchLabel;

  /// No description provided for @suggestRegenerate.
  ///
  /// In en, this message translates to:
  /// **'Another idea'**
  String get suggestRegenerate;

  /// No description provided for @styleBalanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get styleBalanced;

  /// No description provided for @styleHighProtein.
  ///
  /// In en, this message translates to:
  /// **'High protein'**
  String get styleHighProtein;

  /// No description provided for @styleLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get styleLight;

  /// No description provided for @styleHome.
  ///
  /// In en, this message translates to:
  /// **'Home-style'**
  String get styleHome;

  /// No description provided for @styleJunk.
  ///
  /// In en, this message translates to:
  /// **'Junk food'**
  String get styleJunk;

  /// No description provided for @suggestCta.
  ///
  /// In en, this message translates to:
  /// **'Suggest for me'**
  String get suggestCta;

  /// No description provided for @suggestTargetLabel.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get suggestTargetLabel;

  /// No description provided for @stageReadRemaining.
  ///
  /// In en, this message translates to:
  /// **'Reading your remaining macros'**
  String get stageReadRemaining;

  /// No description provided for @stageScanCatalog.
  ///
  /// In en, this message translates to:
  /// **'Picking from your foods catalog'**
  String get stageScanCatalog;

  /// No description provided for @stageCompose.
  ///
  /// In en, this message translates to:
  /// **'Composing your meal'**
  String get stageCompose;

  /// No description provided for @stageValidate.
  ///
  /// In en, this message translates to:
  /// **'Checking the numbers'**
  String get stageValidate;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @suggestedMealTitle.
  ///
  /// In en, this message translates to:
  /// **'Suggested meal'**
  String get suggestedMealTitle;

  /// No description provided for @buildingMeal.
  ///
  /// In en, this message translates to:
  /// **'Building your meal...'**
  String get buildingMeal;

  /// No description provided for @logThisMeal.
  ///
  /// In en, this message translates to:
  /// **'Log this meal'**
  String get logThisMeal;

  /// No description provided for @mealLogged.
  ///
  /// In en, this message translates to:
  /// **'Meal logged'**
  String get mealLogged;

  /// No description provided for @servingUnitLabel.
  ///
  /// In en, this message translates to:
  /// **'serving'**
  String get servingUnitLabel;

  /// No description provided for @suggestNoRemaining.
  ///
  /// In en, this message translates to:
  /// **'You\'ve used your calories for today — no room left for a suggested meal.'**
  String get suggestNoRemaining;

  /// No description provided for @suggestNoMatch.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t build a meal that fits your remaining macros. Try again in a moment.'**
  String get suggestNoMatch;

  /// No description provided for @suggestUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The suggestion service is busy right now. Try again in a bit.'**
  String get suggestUnavailable;

  /// No description provided for @suggestFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get a suggestion. Try again.'**
  String get suggestFailed;

  /// No description provided for @removeLogConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{name}\" from today\'s log?'**
  String removeLogConfirm(String name);

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Account?'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountBody.
  ///
  /// In en, this message translates to:
  /// **'Your account and all of its data — profile, workout history, subscriptions — will be permanently deleted. This cannot be undone.'**
  String get deleteAccountBody;

  /// No description provided for @deleteAccountFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete your account. Try again.'**
  String get deleteAccountFailed;

  /// No description provided for @legal.
  ///
  /// In en, this message translates to:
  /// **'LEGAL'**
  String get legal;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @rankRookie.
  ///
  /// In en, this message translates to:
  /// **'ROOKIE'**
  String get rankRookie;

  /// No description provided for @rankIron.
  ///
  /// In en, this message translates to:
  /// **'IRON'**
  String get rankIron;

  /// No description provided for @rankBronze.
  ///
  /// In en, this message translates to:
  /// **'BRONZE'**
  String get rankBronze;

  /// No description provided for @rankSilver.
  ///
  /// In en, this message translates to:
  /// **'SILVER'**
  String get rankSilver;

  /// No description provided for @rankGold.
  ///
  /// In en, this message translates to:
  /// **'GOLD'**
  String get rankGold;

  /// No description provided for @lbTierDiamond.
  ///
  /// In en, this message translates to:
  /// **'DIAMOND'**
  String get lbTierDiamond;

  /// No description provided for @lbWeeklyChallenge.
  ///
  /// In en, this message translates to:
  /// **'WEEKLY CHALLENGE'**
  String get lbWeeklyChallenge;

  /// No description provided for @lbMonthlyChallenge.
  ///
  /// In en, this message translates to:
  /// **'MONTHLY CHALLENGE'**
  String get lbMonthlyChallenge;

  /// No description provided for @lbDaysLeft.
  ///
  /// In en, this message translates to:
  /// **'{n} days left'**
  String lbDaysLeft(int n);

  /// No description provided for @lbResetsOn.
  ///
  /// In en, this message translates to:
  /// **'New cycle starts {date}'**
  String lbResetsOn(String date);

  /// No description provided for @lbWindowWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get lbWindowWeekly;

  /// No description provided for @lbWindowMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get lbWindowMonthly;

  /// No description provided for @lbCatOverall.
  ///
  /// In en, this message translates to:
  /// **'Overall'**
  String get lbCatOverall;

  /// No description provided for @lbCatCalories.
  ///
  /// In en, this message translates to:
  /// **'Calories'**
  String get lbCatCalories;

  /// No description provided for @lbCatWater.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get lbCatWater;

  /// No description provided for @lbCatWorkouts.
  ///
  /// In en, this message translates to:
  /// **'Workouts'**
  String get lbCatWorkouts;

  /// No description provided for @lbCatStreak.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get lbCatStreak;

  /// No description provided for @lbCatLongestStreak.
  ///
  /// In en, this message translates to:
  /// **'Longest streak'**
  String get lbCatLongestStreak;

  /// No description provided for @lbYourRank.
  ///
  /// In en, this message translates to:
  /// **'YOUR RANK'**
  String get lbYourRank;

  /// No description provided for @lbUnitPts.
  ///
  /// In en, this message translates to:
  /// **'pts'**
  String get lbUnitPts;

  /// No description provided for @lbUnitWorkouts.
  ///
  /// In en, this message translates to:
  /// **'workouts'**
  String get lbUnitWorkouts;

  /// No description provided for @lbUnitDays.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get lbUnitDays;

  /// No description provided for @lbDayStreakN.
  ///
  /// In en, this message translates to:
  /// **'{n}-day streak'**
  String lbDayStreakN(int n);

  /// No description provided for @lbLongestStreakN.
  ///
  /// In en, this message translates to:
  /// **'Longest: {n} days'**
  String lbLongestStreakN(int n);

  /// No description provided for @lbLeadingBoard.
  ///
  /// In en, this message translates to:
  /// **'You\'re leading the board'**
  String get lbLeadingBoard;

  /// No description provided for @lbTiedWith.
  ///
  /// In en, this message translates to:
  /// **'Level with #{rank}'**
  String lbTiedWith(int rank);

  /// No description provided for @lbPtsToNextRank.
  ///
  /// In en, this message translates to:
  /// **'{n} pts to #{rank}'**
  String lbPtsToNextRank(int n, int rank);

  /// No description provided for @lbTopTier.
  ///
  /// In en, this message translates to:
  /// **'Top tier reached'**
  String get lbTopTier;

  /// No description provided for @lbPtsToTier.
  ///
  /// In en, this message translates to:
  /// **'{n} pts to {tier}'**
  String lbPtsToTier(int n, String tier);

  /// No description provided for @lbNewHere.
  ///
  /// In en, this message translates to:
  /// **'NEW'**
  String get lbNewHere;

  /// No description provided for @lbSameRank.
  ///
  /// In en, this message translates to:
  /// **'No change'**
  String get lbSameRank;

  /// No description provided for @lbMovedUp.
  ///
  /// In en, this message translates to:
  /// **'Moved up {n} spots'**
  String lbMovedUp(int n);

  /// No description provided for @lbMovedDown.
  ///
  /// In en, this message translates to:
  /// **'Dropped {n} spots'**
  String lbMovedDown(int n);

  /// No description provided for @lbLastWeek.
  ///
  /// In en, this message translates to:
  /// **'LAST WEEK'**
  String get lbLastWeek;

  /// No description provided for @lbNewCycle.
  ///
  /// In en, this message translates to:
  /// **'New competition started'**
  String get lbNewCycle;

  /// No description provided for @lbDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get lbDismiss;

  /// No description provided for @lbScoreTooltip.
  ///
  /// In en, this message translates to:
  /// **'How your score is calculated'**
  String get lbScoreTooltip;

  /// No description provided for @lbScoreCalcTitle.
  ///
  /// In en, this message translates to:
  /// **'Your score'**
  String get lbScoreCalcTitle;

  /// No description provided for @lbScoreFormula.
  ///
  /// In en, this message translates to:
  /// **'Score = 60% calorie adherence + 40% water adherence over the selected window. Log consistently to climb.'**
  String get lbScoreFormula;

  /// No description provided for @lbSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search a name…'**
  String get lbSearchHint;

  /// No description provided for @lbNoSearchResults.
  ///
  /// In en, this message translates to:
  /// **'No one named \"{query}\" here'**
  String lbNoSearchResults(String query);

  /// No description provided for @lbEmptyCategory.
  ///
  /// In en, this message translates to:
  /// **'No one has claimed this board yet'**
  String get lbEmptyCategory;

  /// No description provided for @lbEmptyCategorySub.
  ///
  /// In en, this message translates to:
  /// **'Log today and take the top spot'**
  String get lbEmptyCategorySub;

  /// No description provided for @lbPinJump.
  ///
  /// In en, this message translates to:
  /// **'Your rank — tap to jump'**
  String get lbPinJump;

  /// No description provided for @lbYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get lbYou;

  /// No description provided for @lbYouBadge.
  ///
  /// In en, this message translates to:
  /// **'YOU'**
  String get lbYouBadge;

  /// No description provided for @lbCompCardTitle.
  ///
  /// In en, this message translates to:
  /// **'COMPETITIVE'**
  String get lbCompCardTitle;

  /// No description provided for @lbRankOf.
  ///
  /// In en, this message translates to:
  /// **'#{rank} of {total}'**
  String lbRankOf(int rank, int total);

  /// No description provided for @lbRankOfTotal.
  ///
  /// In en, this message translates to:
  /// **'of {total}'**
  String lbRankOfTotal(int total);

  /// No description provided for @lbRankJourney.
  ///
  /// In en, this message translates to:
  /// **'#{from} → #{to}'**
  String lbRankJourney(int from, int to);

  /// No description provided for @lbRankHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'Not enough data yet'**
  String get lbRankHistoryEmpty;

  /// No description provided for @profilePhotoTitle.
  ///
  /// In en, this message translates to:
  /// **'PROFILE PHOTO'**
  String get profilePhotoTitle;

  /// No description provided for @editDataTitle.
  ///
  /// In en, this message translates to:
  /// **'EDIT DATA'**
  String get editDataTitle;

  /// No description provided for @saveDataBtn.
  ///
  /// In en, this message translates to:
  /// **'SAVE DATA'**
  String get saveDataBtn;

  /// No description provided for @saveGoalsBtn.
  ///
  /// In en, this message translates to:
  /// **'SAVE GOALS'**
  String get saveGoalsBtn;

  /// No description provided for @viewPhoto.
  ///
  /// In en, this message translates to:
  /// **'View Photo'**
  String get viewPhoto;

  /// No description provided for @changePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change Photo'**
  String get changePhoto;

  /// No description provided for @uploadPhoto.
  ///
  /// In en, this message translates to:
  /// **'Upload Photo'**
  String get uploadPhoto;

  /// No description provided for @profilePhotoUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile photo updated'**
  String get profilePhotoUpdated;

  /// No description provided for @uploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed. Try again.'**
  String get uploadFailed;

  /// No description provided for @coachDashboard.
  ///
  /// In en, this message translates to:
  /// **'Coach Dashboard'**
  String get coachDashboard;

  /// No description provided for @coachDashboardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage clients & programs on the web'**
  String get coachDashboardSubtitle;

  /// No description provided for @noProgressData.
  ///
  /// In en, this message translates to:
  /// **'No progress data yet'**
  String get noProgressData;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @refreshProfile.
  ///
  /// In en, this message translates to:
  /// **'Refresh profile'**
  String get refreshProfile;

  /// No description provided for @profilePhotoTapOptions.
  ///
  /// In en, this message translates to:
  /// **'Profile photo. Tap for options.'**
  String get profilePhotoTapOptions;

  /// No description provided for @editBodyData.
  ///
  /// In en, this message translates to:
  /// **'Edit body data'**
  String get editBodyData;

  /// No description provided for @editDailyTargets.
  ///
  /// In en, this message translates to:
  /// **'Edit daily targets'**
  String get editDailyTargets;

  /// No description provided for @activeProgramTapHint.
  ///
  /// In en, this message translates to:
  /// **'Active program: {name}. Tap to view.'**
  String activeProgramTapHint(String name);

  /// No description provided for @chartSessionsSemantics.
  ///
  /// In en, this message translates to:
  /// **'1RM progress line chart — {count} sessions recorded.'**
  String chartSessionsSemantics(int count);

  /// No description provided for @sessionsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} sessions'**
  String sessionsCount(int count);

  /// No description provided for @yearsShort.
  ///
  /// In en, this message translates to:
  /// **'yrs'**
  String get yearsShort;

  /// No description provided for @perWeekShort.
  ///
  /// In en, this message translates to:
  /// **'×/wk'**
  String get perWeekShort;

  /// No description provided for @statsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your stats.'**
  String get statsLoadFailed;

  /// No description provided for @invalidAgeRange.
  ///
  /// In en, this message translates to:
  /// **'Age must be a whole number between 10 and 100.'**
  String get invalidAgeRange;

  /// No description provided for @invalidWeightRange.
  ///
  /// In en, this message translates to:
  /// **'Weight must be a number between 20 and 300 kg.'**
  String get invalidWeightRange;

  /// No description provided for @invalidHeightRange.
  ///
  /// In en, this message translates to:
  /// **'Height must be a number between 100 and 250 cm.'**
  String get invalidHeightRange;

  /// No description provided for @invalidCalories.
  ///
  /// In en, this message translates to:
  /// **'Calories must be a non-negative whole number.'**
  String get invalidCalories;

  /// No description provided for @invalidProtein.
  ///
  /// In en, this message translates to:
  /// **'Protein must be a non-negative whole number.'**
  String get invalidProtein;

  /// No description provided for @invalidWeeklyWorkouts.
  ///
  /// In en, this message translates to:
  /// **'Weekly workouts must be a non-negative whole number.'**
  String get invalidWeeklyWorkouts;

  /// No description provided for @motivationEmpty.
  ///
  /// In en, this message translates to:
  /// **'Log your first meal to start your day! 🌟'**
  String get motivationEmpty;

  /// No description provided for @motivationStart.
  ///
  /// In en, this message translates to:
  /// **'Great start! Fuel up with clean nutrients 🌱'**
  String get motivationStart;

  /// No description provided for @motivationZone.
  ///
  /// In en, this message translates to:
  /// **'You are in the zone! Hit your protein target ⚡'**
  String get motivationZone;

  /// No description provided for @motivationAlmost.
  ///
  /// In en, this message translates to:
  /// **'Almost at your target! Finish strong 🎯'**
  String get motivationAlmost;

  /// No description provided for @motivationBullseye.
  ///
  /// In en, this message translates to:
  /// **'Bullseye! Perfect nutrition day 🎉'**
  String get motivationBullseye;

  /// No description provided for @motivationOver.
  ///
  /// In en, this message translates to:
  /// **'Over target — balance with light hydration 🧘'**
  String get motivationOver;

  /// No description provided for @addCaloriesTo.
  ///
  /// In en, this message translates to:
  /// **'Add calories directly to {meal}'**
  String addCaloriesTo(String meal);

  /// No description provided for @addToLog.
  ///
  /// In en, this message translates to:
  /// **'Add to Log'**
  String get addToLog;

  /// No description provided for @foodItemFallback.
  ///
  /// In en, this message translates to:
  /// **'Food item'**
  String get foodItemFallback;

  /// No description provided for @editServingMeal.
  ///
  /// In en, this message translates to:
  /// **'Edit serving & meal section'**
  String get editServingMeal;

  /// No description provided for @overBudget.
  ///
  /// In en, this message translates to:
  /// **'Over Budget'**
  String get overBudget;

  /// No description provided for @targetKcal.
  ///
  /// In en, this message translates to:
  /// **'Target: {kcal} kcal'**
  String targetKcal(String kcal);

  /// No description provided for @dailyTargetMl.
  ///
  /// In en, this message translates to:
  /// **'Daily target: {ml} ml'**
  String dailyTargetMl(String ml);

  /// No description provided for @waterGlassSub.
  ///
  /// In en, this message translates to:
  /// **'Glass 🥛'**
  String get waterGlassSub;

  /// No description provided for @waterBottleSub.
  ///
  /// In en, this message translates to:
  /// **'Bottle 💧'**
  String get waterBottleSub;

  /// No description provided for @dailyGoalTargets.
  ///
  /// In en, this message translates to:
  /// **'Daily Goal Targets'**
  String get dailyGoalTargets;

  /// No description provided for @macroLeftKcal.
  ///
  /// In en, this message translates to:
  /// **'{kcal} kcal · {grams}g left'**
  String macroLeftKcal(String kcal, String grams);

  /// No description provided for @noFoodLogged.
  ///
  /// In en, this message translates to:
  /// **'No food logged yet'**
  String get noFoodLogged;

  /// No description provided for @mealTotals.
  ///
  /// In en, this message translates to:
  /// **'Meal totals:'**
  String get mealTotals;

  /// No description provided for @removeItem.
  ///
  /// In en, this message translates to:
  /// **'Remove item?'**
  String get removeItem;

  /// No description provided for @avgCalories.
  ///
  /// In en, this message translates to:
  /// **'Avg Calories'**
  String get avgCalories;

  /// No description provided for @onTrack.
  ///
  /// In en, this message translates to:
  /// **'On Track'**
  String get onTrack;

  /// No description provided for @daysInZone.
  ///
  /// In en, this message translates to:
  /// **'days in zone'**
  String get daysInZone;

  /// No description provided for @workouts.
  ///
  /// In en, this message translates to:
  /// **'Workouts'**
  String get workouts;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'this week'**
  String get thisWeek;

  /// No description provided for @kcalPerDay.
  ///
  /// In en, this message translates to:
  /// **'kcal / day'**
  String get kcalPerDay;

  /// No description provided for @aiWaitWorking.
  ///
  /// In en, this message translates to:
  /// **'Still working…'**
  String get aiWaitWorking;

  /// No description provided for @aiWaitElapsed.
  ///
  /// In en, this message translates to:
  /// **'{secs}s'**
  String aiWaitElapsed(String secs);

  /// No description provided for @aiWaitSlow.
  ///
  /// In en, this message translates to:
  /// **'Taking a little longer than usual — still working on it. Busy moments can take up to a minute.'**
  String get aiWaitSlow;

  /// No description provided for @verifyTitle1.
  ///
  /// In en, this message translates to:
  /// **'VERIFY'**
  String get verifyTitle1;

  /// No description provided for @verifyTitle2.
  ///
  /// In en, this message translates to:
  /// **'CODE'**
  String get verifyTitle2;

  /// No description provided for @verifySubtitle.
  ///
  /// In en, this message translates to:
  /// **'We\'ve sent a verification code to {email}'**
  String verifySubtitle(String email);

  /// No description provided for @verifyButton.
  ///
  /// In en, this message translates to:
  /// **'VERIFY CODE'**
  String get verifyButton;

  /// No description provided for @verifyDidntReceive.
  ///
  /// In en, this message translates to:
  /// **'DIDN\'T RECEIVE?'**
  String get verifyDidntReceive;

  /// No description provided for @verifyResendIn.
  ///
  /// In en, this message translates to:
  /// **'RESEND IN {seconds}s'**
  String verifyResendIn(int seconds);

  /// No description provided for @verifyResend.
  ///
  /// In en, this message translates to:
  /// **'RESEND'**
  String get verifyResend;

  /// No description provided for @verifyRemember.
  ///
  /// In en, this message translates to:
  /// **'REMEMBER PASSWORD?'**
  String get verifyRemember;

  /// No description provided for @verifyDidntRemember.
  ///
  /// In en, this message translates to:
  /// **'DIDN\'T REMEMBER IT?'**
  String get verifyDidntRemember;

  /// No description provided for @verifySignIn.
  ///
  /// In en, this message translates to:
  /// **'SIGN IN'**
  String get verifySignIn;

  /// No description provided for @verifyErrIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Enter the full code from your email'**
  String get verifyErrIncomplete;

  /// No description provided for @verifyErrRateLimit.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait a moment.'**
  String get verifyErrRateLimit;

  /// No description provided for @verifyErrInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid or expired code'**
  String get verifyErrInvalid;

  /// No description provided for @verifyErrKeepTyping.
  ///
  /// In en, this message translates to:
  /// **'Invalid code - if it has more digits, keep typing'**
  String get verifyErrKeepTyping;

  /// No description provided for @verifyErrConnection.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Check your connection.'**
  String get verifyErrConnection;

  /// No description provided for @verifySnackResent.
  ///
  /// In en, this message translates to:
  /// **'A new code was sent to your email'**
  String get verifySnackResent;

  /// No description provided for @verifySnackWait.
  ///
  /// In en, this message translates to:
  /// **'Please wait before requesting another code'**
  String get verifySnackWait;

  /// No description provided for @verifySnackFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not resend the code. Try again.'**
  String get verifySnackFailed;

  /// No description provided for @forgotTitle1.
  ///
  /// In en, this message translates to:
  /// **'RESET'**
  String get forgotTitle1;

  /// No description provided for @forgotTitle2.
  ///
  /// In en, this message translates to:
  /// **'ACCESS'**
  String get forgotTitle2;

  /// No description provided for @forgotSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ENTER YOUR EMAIL TO RECEIVE A RESET CODE'**
  String get forgotSubtitle;

  /// No description provided for @forgotEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'OPERATOR_ID'**
  String get forgotEmailLabel;

  /// No description provided for @forgotEmailEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get forgotEmailEmpty;

  /// No description provided for @forgotEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get forgotEmailInvalid;

  /// No description provided for @forgotSendButton.
  ///
  /// In en, this message translates to:
  /// **'SEND RESET CODE'**
  String get forgotSendButton;

  /// No description provided for @resetTitle1.
  ///
  /// In en, this message translates to:
  /// **'NEW'**
  String get resetTitle1;

  /// No description provided for @resetTitle2.
  ///
  /// In en, this message translates to:
  /// **'PASSWORD'**
  String get resetTitle2;

  /// No description provided for @resetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ENTER YOUR NEW ENCRYPTED KEY'**
  String get resetSubtitle;

  /// No description provided for @resetNewKey.
  ///
  /// In en, this message translates to:
  /// **'NEW_KEY'**
  String get resetNewKey;

  /// No description provided for @resetConfirmKey.
  ///
  /// In en, this message translates to:
  /// **'CONFIRM_KEY'**
  String get resetConfirmKey;

  /// No description provided for @resetPassEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter a password'**
  String get resetPassEmpty;

  /// No description provided for @resetPassShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get resetPassShort;

  /// No description provided for @resetPassWeak.
  ///
  /// In en, this message translates to:
  /// **'Must contain uppercase, lowercase, and number'**
  String get resetPassWeak;

  /// No description provided for @resetPassConfirmEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your password'**
  String get resetPassConfirmEmpty;

  /// No description provided for @resetPassMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get resetPassMismatch;

  /// No description provided for @resetButton.
  ///
  /// In en, this message translates to:
  /// **'RESET PASSWORD'**
  String get resetButton;

  /// No description provided for @resetSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your reset session expired. Please request a new code.'**
  String get resetSessionExpired;

  /// No description provided for @resetSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password reset successfully!'**
  String get resetSuccess;

  /// No description provided for @authLoginTitleA.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get authLoginTitleA;

  /// No description provided for @authLoginTitleB.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get authLoginTitleB;

  /// No description provided for @authSignupTitleA.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get authSignupTitleA;

  /// No description provided for @authSignupTitleB.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get authSignupTitleB;

  /// No description provided for @authStrengthWeak.
  ///
  /// In en, this message translates to:
  /// **'Weak'**
  String get authStrengthWeak;

  /// No description provided for @authStrengthFair.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get authStrengthFair;

  /// No description provided for @authStrengthStrong.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get authStrengthStrong;

  /// No description provided for @authNameError.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get authNameError;

  /// No description provided for @authPassMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get authPassMismatch;

  /// No description provided for @authPassMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords match'**
  String get authPassMatch;

  /// No description provided for @authEmailEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get authEmailEmpty;

  /// No description provided for @authEmailError.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get authEmailError;

  /// No description provided for @authPassEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get authPassEmpty;

  /// No description provided for @authPassShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get authPassShort;

  /// No description provided for @authAgreeTerms.
  ///
  /// In en, this message translates to:
  /// **'Please agree to the Terms & Conditions'**
  String get authAgreeTerms;

  /// No description provided for @authAgreeTermsShort.
  ///
  /// In en, this message translates to:
  /// **'Agree to the Terms first'**
  String get authAgreeTermsShort;

  /// No description provided for @authAppleSoon.
  ///
  /// In en, this message translates to:
  /// **'Apple sign-in coming soon'**
  String get authAppleSoon;

  /// No description provided for @authLegalSoon.
  ///
  /// In en, this message translates to:
  /// **'Legal pages coming soon'**
  String get authLegalSoon;

  /// No description provided for @authShowPass.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get authShowPass;

  /// No description provided for @authHidePass.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get authHidePass;

  /// No description provided for @authWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back, {email}!'**
  String authWelcomeBack(String email);

  /// No description provided for @authWelcomeNew.
  ///
  /// In en, this message translates to:
  /// **'Welcome, {name}!'**
  String authWelcomeNew(String name);

  /// No description provided for @authGoogleOk.
  ///
  /// In en, this message translates to:
  /// **'Signed in with Google!'**
  String get authGoogleOk;

  /// No description provided for @gymAttEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Automatic Gym Attendance'**
  String get gymAttEntryTitle;

  /// No description provided for @gymAttEntryDesc.
  ///
  /// In en, this message translates to:
  /// **'Track your gym visits automatically'**
  String get gymAttEntryDesc;

  /// No description provided for @gymAttEntryActive.
  ///
  /// In en, this message translates to:
  /// **'Attendance tracking is active'**
  String get gymAttEntryActive;

  /// No description provided for @gymAttIntroTitle.
  ///
  /// In en, this message translates to:
  /// **'Automatic Gym Attendance'**
  String get gymAttIntroTitle;

  /// No description provided for @gymAttIntroBody.
  ///
  /// In en, this message translates to:
  /// **'CoreGym detects when you arrive at your gym and logs your visit automatically — no buttons, no check-ins.'**
  String get gymAttIntroBody;

  /// No description provided for @gymAttIntroRuleTitle.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get gymAttIntroRuleTitle;

  /// No description provided for @gymAttIntroRuleBody.
  ///
  /// In en, this message translates to:
  /// **'Stay 25 minutes or more inside your gym\'s area and the visit is recorded automatically. Passing by without stopping is ignored.'**
  String get gymAttIntroRuleBody;

  /// No description provided for @gymAttIntroPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Location is used only to detect gym visits — it stays on your device and is never sold or shared.'**
  String get gymAttIntroPrivacy;

  /// No description provided for @gymAttIntroCta.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get gymAttIntroCta;

  /// No description provided for @gymAttPromoCta.
  ///
  /// In en, this message translates to:
  /// **'Enable from Profile'**
  String get gymAttPromoCta;

  /// No description provided for @gymAttPermContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get gymAttPermContinue;

  /// No description provided for @gymAttPermAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get gymAttPermAllow;

  /// No description provided for @gymAttPermSkip.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get gymAttPermSkip;

  /// No description provided for @gymAttPermGranted.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get gymAttPermGranted;

  /// No description provided for @gymAttOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get gymAttOpenSettings;

  /// No description provided for @gymAttPermDeniedTitle.
  ///
  /// In en, this message translates to:
  /// **'Permission not granted'**
  String get gymAttPermDeniedTitle;

  /// No description provided for @gymAttPermDeniedBody.
  ///
  /// In en, this message translates to:
  /// **'This permission is needed for automatic tracking. You can enable it anytime from Settings.'**
  String get gymAttPermDeniedBody;

  /// No description provided for @gymAttContinueWithout.
  ///
  /// In en, this message translates to:
  /// **'Continue without it'**
  String get gymAttContinueWithout;

  /// No description provided for @gymAttLocTitle.
  ///
  /// In en, this message translates to:
  /// **'Know when you arrive'**
  String get gymAttLocTitle;

  /// No description provided for @gymAttLocBody.
  ///
  /// In en, this message translates to:
  /// **'We use your location only to detect when you arrive at or leave your gym. Nothing else.'**
  String get gymAttLocBody;

  /// No description provided for @gymAttLocWhy.
  ///
  /// In en, this message translates to:
  /// **'Why we need this: detection runs on your device and only near your gym.'**
  String get gymAttLocWhy;

  /// No description provided for @gymAttBgTitle.
  ///
  /// In en, this message translates to:
  /// **'Works even when the app is closed'**
  String get gymAttBgTitle;

  /// No description provided for @gymAttBgBody.
  ///
  /// In en, this message translates to:
  /// **'Background location lets CoreGym detect your visit without opening the app. Detection only activates near your gym to protect your battery and privacy.'**
  String get gymAttBgBody;

  /// No description provided for @gymAttBgWhy.
  ///
  /// In en, this message translates to:
  /// **'Why we need this: without it, visits are only detected while the app is open.'**
  String get gymAttBgWhy;

  /// No description provided for @gymAttActTitle.
  ///
  /// In en, this message translates to:
  /// **'Optional, but smarter'**
  String get gymAttActTitle;

  /// No description provided for @gymAttActBody.
  ///
  /// In en, this message translates to:
  /// **'Activity data like steps can optionally confirm you were actually training — attendance never depends on it. Notifications tell you when a visit is recorded.'**
  String get gymAttActBody;

  /// No description provided for @gymAttActWhy.
  ///
  /// In en, this message translates to:
  /// **'Fully optional — tracking works without it.'**
  String get gymAttActWhy;

  /// No description provided for @gymAttMapTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your gym'**
  String get gymAttMapTitle;

  /// No description provided for @gymAttMapSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap the map or search to place the pin on your gym'**
  String get gymAttMapSubtitle;

  /// No description provided for @gymAttMapFinding.
  ///
  /// In en, this message translates to:
  /// **'Finding your location...'**
  String get gymAttMapFinding;

  /// No description provided for @gymAttMapLocErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find your location'**
  String get gymAttMapLocErrorTitle;

  /// No description provided for @gymAttRetry.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get gymAttRetry;

  /// No description provided for @gymAttSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search gym or area'**
  String get gymAttSearchHint;

  /// No description provided for @gymAttSearchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get gymAttSearchNoResults;

  /// No description provided for @gymAttMyLocation.
  ///
  /// In en, this message translates to:
  /// **'My Location'**
  String get gymAttMyLocation;

  /// No description provided for @gymAttYourGym.
  ///
  /// In en, this message translates to:
  /// **'Your Gym'**
  String get gymAttYourGym;

  /// No description provided for @gymAttTrackingRadius.
  ///
  /// In en, this message translates to:
  /// **'Tracking radius'**
  String get gymAttTrackingRadius;

  /// No description provided for @gymAttRadiusValue.
  ///
  /// In en, this message translates to:
  /// **'{meters} m'**
  String gymAttRadiusValue(String meters);

  /// No description provided for @gymAttDistanceValue.
  ///
  /// In en, this message translates to:
  /// **'{distance} away'**
  String gymAttDistanceValue(String distance);

  /// No description provided for @gymAttConfirmGym.
  ///
  /// In en, this message translates to:
  /// **'Confirm Gym'**
  String get gymAttConfirmGym;

  /// No description provided for @gymAttUnnamedGym.
  ///
  /// In en, this message translates to:
  /// **'Selected location'**
  String get gymAttUnnamedGym;

  /// No description provided for @gymAttConfirmAreaTitle.
  ///
  /// In en, this message translates to:
  /// **'Tracking area'**
  String get gymAttConfirmAreaTitle;

  /// No description provided for @gymAttConfirmExplain.
  ///
  /// In en, this message translates to:
  /// **'CoreGym will automatically detect when you arrive at and leave this area. Visits of 25 minutes or more are recorded.'**
  String get gymAttConfirmExplain;

  /// No description provided for @gymAttStartTracking.
  ///
  /// In en, this message translates to:
  /// **'Start Tracking'**
  String get gymAttStartTracking;

  /// No description provided for @gymAttChangeGym.
  ///
  /// In en, this message translates to:
  /// **'Change Gym'**
  String get gymAttChangeGym;

  /// No description provided for @gymAttSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re all set'**
  String get gymAttSuccessTitle;

  /// No description provided for @gymAttSuccessBody.
  ///
  /// In en, this message translates to:
  /// **'CoreGym will track your gym visits automatically.'**
  String get gymAttSuccessBody;

  /// No description provided for @gymAttMyGymTitle.
  ///
  /// In en, this message translates to:
  /// **'My Gym'**
  String get gymAttMyGymTitle;

  /// No description provided for @gymAttTrackingOn.
  ///
  /// In en, this message translates to:
  /// **'Automatic tracking ON'**
  String get gymAttTrackingOn;

  /// No description provided for @gymAttTrackingOnDesc.
  ///
  /// In en, this message translates to:
  /// **'CoreGym is watching for your gym visits.'**
  String get gymAttTrackingOnDesc;

  /// No description provided for @gymAttSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get gymAttSaving;

  /// No description provided for @gymAttSaveError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save your gym. Try again.'**
  String get gymAttSaveError;

  /// No description provided for @gymAttBannerInsideTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re inside your gym area'**
  String get gymAttBannerInsideTitle;

  /// No description provided for @gymAttBannerCountdownLabel.
  ///
  /// In en, this message translates to:
  /// **'Visit will be recorded in'**
  String get gymAttBannerCountdownLabel;

  /// No description provided for @gymAttBannerCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get gymAttBannerCancel;

  /// No description provided for @gymAttBannerConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Visit recorded'**
  String get gymAttBannerConfirmed;

  /// No description provided for @gymAttBannerConfirmedDesc.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min at your gym'**
  String gymAttBannerConfirmedDesc(String minutes);

  /// No description provided for @gymAttHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Attendance log'**
  String get gymAttHistoryTitle;

  /// No description provided for @gymAttHeatmapNoVisit.
  ///
  /// In en, this message translates to:
  /// **'No visit'**
  String get gymAttHeatmapNoVisit;

  /// No description provided for @gymAttHeatmapVisited.
  ///
  /// In en, this message translates to:
  /// **'{date} · {minutes} min at the gym'**
  String gymAttHeatmapVisited(String date, String minutes);

  /// No description provided for @gymAttStatsWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get gymAttStatsWeek;

  /// No description provided for @gymAttStatsMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get gymAttStatsMonth;

  /// No description provided for @gymAttStatsAvgWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly avg'**
  String get gymAttStatsAvgWeekly;

  /// No description provided for @gymAttStatsAvgMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly avg'**
  String get gymAttStatsAvgMonthly;

  /// No description provided for @gymAttViewWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get gymAttViewWeekly;

  /// No description provided for @gymAttViewMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get gymAttViewMonthly;

  /// No description provided for @gymAttViewYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get gymAttViewYearly;

  /// No description provided for @gymAttStatsYear.
  ///
  /// In en, this message translates to:
  /// **'This year'**
  String get gymAttStatsYear;

  /// No description provided for @gymAttStatsStreak.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get gymAttStatsStreak;

  /// No description provided for @gymAttStatsLastVisit.
  ///
  /// In en, this message translates to:
  /// **'Last visit'**
  String get gymAttStatsLastVisit;

  /// No description provided for @gymAttStatsDays.
  ///
  /// In en, this message translates to:
  /// **'{n} days'**
  String gymAttStatsDays(String n);

  /// No description provided for @gymAttGeofenceActive.
  ///
  /// In en, this message translates to:
  /// **'Geofence active'**
  String get gymAttGeofenceActive;

  /// No description provided for @gymAttFacilityLabel.
  ///
  /// In en, this message translates to:
  /// **'Home facility'**
  String get gymAttFacilityLabel;

  /// No description provided for @gymAttAutoPill.
  ///
  /// In en, this message translates to:
  /// **'Auto check-in on'**
  String get gymAttAutoPill;

  /// No description provided for @gymAttLastSession.
  ///
  /// In en, this message translates to:
  /// **'Last session'**
  String get gymAttLastSession;

  /// No description provided for @gymAttDurationH.
  ///
  /// In en, this message translates to:
  /// **'{h}h'**
  String gymAttDurationH(String h);

  /// No description provided for @gymAttDurationHM.
  ///
  /// In en, this message translates to:
  /// **'{h}h {m}m'**
  String gymAttDurationHM(String h, String m);

  /// No description provided for @gymAttDurationM.
  ///
  /// In en, this message translates to:
  /// **'{m}m'**
  String gymAttDurationM(String m);

  /// No description provided for @gymAttMetricsTitle.
  ///
  /// In en, this message translates to:
  /// **'Metrics'**
  String get gymAttMetricsTitle;

  /// No description provided for @gymAttTotalVisits.
  ///
  /// In en, this message translates to:
  /// **'Total visits'**
  String get gymAttTotalVisits;

  /// No description provided for @gymAttPaceAvg.
  ///
  /// In en, this message translates to:
  /// **'Pace avg'**
  String get gymAttPaceAvg;

  /// No description provided for @gymAttPerWeek.
  ///
  /// In en, this message translates to:
  /// **'days/wk'**
  String get gymAttPerWeek;

  /// No description provided for @gymAttPerMonth.
  ///
  /// In en, this message translates to:
  /// **'days/mo'**
  String get gymAttPerMonth;

  /// No description provided for @gymAttAvgDwell.
  ///
  /// In en, this message translates to:
  /// **'Avg dwell'**
  String get gymAttAvgDwell;

  /// No description provided for @gymAttPerSession.
  ///
  /// In en, this message translates to:
  /// **'per session'**
  String get gymAttPerSession;

  /// No description provided for @gymAttMatrixTitle.
  ///
  /// In en, this message translates to:
  /// **'Attendance matrix'**
  String get gymAttMatrixTitle;

  /// No description provided for @gymAttMatrixSubYear.
  ///
  /// In en, this message translates to:
  /// **'52-week consistency'**
  String get gymAttMatrixSubYear;

  /// No description provided for @gymAttMatrixSubMonth.
  ///
  /// In en, this message translates to:
  /// **'This month\'s consistency'**
  String get gymAttMatrixSubMonth;

  /// No description provided for @gymAttMatrixSubWeek.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get gymAttMatrixSubWeek;

  /// No description provided for @gymAttHeatLess.
  ///
  /// In en, this message translates to:
  /// **'Less'**
  String get gymAttHeatLess;

  /// No description provided for @gymAttHeatMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get gymAttHeatMore;

  /// No description provided for @gymAttRecentTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent check-ins'**
  String get gymAttRecentTitle;

  /// No description provided for @gymAttRowCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get gymAttRowCompleted;

  /// No description provided for @gymAttRowGeofence.
  ///
  /// In en, this message translates to:
  /// **'Geofence verified'**
  String get gymAttRowGeofence;

  /// No description provided for @gymAttManualCheckInSuccess.
  ///
  /// In en, this message translates to:
  /// **'Check-in recorded'**
  String get gymAttManualCheckInSuccess;

  /// No description provided for @gymAttSettingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Gym settings'**
  String get gymAttSettingsTooltip;

  /// No description provided for @gymAttSignalPing.
  ///
  /// In en, this message translates to:
  /// **'Ping'**
  String get gymAttSignalPing;

  /// No description provided for @gymAttSignalPingMs.
  ///
  /// In en, this message translates to:
  /// **'{ms} ms'**
  String gymAttSignalPingMs(String ms);

  /// No description provided for @gymAttHotBadge.
  ///
  /// In en, this message translates to:
  /// **'HOT'**
  String get gymAttHotBadge;

  /// No description provided for @gymAttViewFullLog.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get gymAttViewFullLog;

  /// No description provided for @gymAttSessionInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress · {m} min so far'**
  String gymAttSessionInProgress(String m);

  /// No description provided for @gymAttInsideZone.
  ///
  /// In en, this message translates to:
  /// **'Inside zone'**
  String get gymAttInsideZone;

  /// No description provided for @gymAttManualCheckInNow.
  ///
  /// In en, this message translates to:
  /// **'Check in now'**
  String get gymAttManualCheckInNow;

  /// No description provided for @telemetryLogTag.
  ///
  /// In en, this message translates to:
  /// **'Telemetry • Log'**
  String get telemetryLogTag;

  /// No description provided for @dayTargetTelemetry.
  ///
  /// In en, this message translates to:
  /// **'Day target • fuel telemetry'**
  String get dayTargetTelemetry;

  /// No description provided for @macrosTelemetry.
  ///
  /// In en, this message translates to:
  /// **'Macros telemetry'**
  String get macrosTelemetry;

  /// No description provided for @freeformEntry.
  ///
  /// In en, this message translates to:
  /// **'Freeform meal entry'**
  String get freeformEntry;

  /// No description provided for @wordCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} words'**
  String wordCountLabel(String count);

  /// No description provided for @liveParser.
  ///
  /// In en, this message translates to:
  /// **'Live parser'**
  String get liveParser;

  /// No description provided for @clearText.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearText;

  /// No description provided for @quickMicroAdd.
  ///
  /// In en, this message translates to:
  /// **'Quick micro-add'**
  String get quickMicroAdd;

  /// No description provided for @frequentlyLogged.
  ///
  /// In en, this message translates to:
  /// **'Frequently logged'**
  String get frequentlyLogged;

  /// No description provided for @recentLogHistory.
  ///
  /// In en, this message translates to:
  /// **'Recent log history'**
  String get recentLogHistory;

  /// No description provided for @yesterdayLabel.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterdayLabel;

  /// No description provided for @nleTitle.
  ///
  /// In en, this message translates to:
  /// **'Natural language engine active'**
  String get nleTitle;

  /// No description provided for @nleBody.
  ///
  /// In en, this message translates to:
  /// **'Parses complex weights, preparation styles, restaurant brands & estimated portion volumes automatically into precise macros.'**
  String get nleBody;

  /// No description provided for @readyToListen.
  ///
  /// In en, this message translates to:
  /// **'Ready to listen'**
  String get readyToListen;

  /// No description provided for @slotActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get slotActive;

  /// No description provided for @featMacroTitle.
  ///
  /// In en, this message translates to:
  /// **'Macro extraction'**
  String get featMacroTitle;

  /// No description provided for @featMacroSub.
  ///
  /// In en, this message translates to:
  /// **'Real-time'**
  String get featMacroSub;

  /// No description provided for @featPortionTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-portion'**
  String get featPortionTitle;

  /// No description provided for @featPortionSub.
  ///
  /// In en, this message translates to:
  /// **'Contextual'**
  String get featPortionSub;

  /// No description provided for @featTypingTitle.
  ///
  /// In en, this message translates to:
  /// **'Zero typing'**
  String get featTypingTitle;

  /// No description provided for @featTypingSub.
  ///
  /// In en, this message translates to:
  /// **'Hands-free'**
  String get featTypingSub;

  /// No description provided for @opticsActive.
  ///
  /// In en, this message translates to:
  /// **'Optics • active'**
  String get opticsActive;

  /// No description provided for @loggingToMeal.
  ///
  /// In en, this message translates to:
  /// **'Logging to {meal}'**
  String loggingToMeal(String meal);

  /// No description provided for @alignBarcodeHint.
  ///
  /// In en, this message translates to:
  /// **'Align barcode within the frame to scan automatically'**
  String get alignBarcodeHint;

  /// No description provided for @readyToScan.
  ///
  /// In en, this message translates to:
  /// **'Ready to scan'**
  String get readyToScan;

  /// No description provided for @waterGoalEdit.
  ///
  /// In en, this message translates to:
  /// **'Daily water goal'**
  String get waterGoalEdit;

  /// No description provided for @waterQuickLog.
  ///
  /// In en, this message translates to:
  /// **'Quick log'**
  String get waterQuickLog;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
