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
  /// **'IGNITE'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'SYSTEM'**
  String get loginSubtitle;

  /// No description provided for @loginDesc.
  ///
  /// In en, this message translates to:
  /// **'ENTER CREDENTIALS TO AUTHORIZE ACCESS'**
  String get loginDesc;

  /// No description provided for @operatorId.
  ///
  /// In en, this message translates to:
  /// **'OPERATOR_ID'**
  String get operatorId;

  /// No description provided for @encryptedKey.
  ///
  /// In en, this message translates to:
  /// **'ENCRYPTED_KEY'**
  String get encryptedKey;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'user@coregym.app'**
  String get emailHint;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'••••••••••••'**
  String get passwordHint;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'FORGOT?'**
  String get forgotPassword;

  /// No description provided for @initializeSession.
  ///
  /// In en, this message translates to:
  /// **'INITIALIZE SESSION'**
  String get initializeSession;

  /// No description provided for @externalAuth.
  ///
  /// In en, this message translates to:
  /// **'EXTERNAL AUTH'**
  String get externalAuth;

  /// No description provided for @google.
  ///
  /// In en, this message translates to:
  /// **'GOOGLE'**
  String get google;

  /// No description provided for @apple.
  ///
  /// In en, this message translates to:
  /// **'APPLE'**
  String get apple;

  /// No description provided for @newOperative.
  ///
  /// In en, this message translates to:
  /// **'NEW OPERATIVE?  '**
  String get newOperative;

  /// No description provided for @enrollNow.
  ///
  /// In en, this message translates to:
  /// **'ENROLL NOW'**
  String get enrollNow;

  /// No description provided for @signupTitle.
  ///
  /// In en, this message translates to:
  /// **'ENROLL'**
  String get signupTitle;

  /// No description provided for @signupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'OPERATIVE'**
  String get signupSubtitle;

  /// No description provided for @signupDesc.
  ///
  /// In en, this message translates to:
  /// **'CREATE NEW SYSTEM ACCESS'**
  String get signupDesc;

  /// No description provided for @operativeName.
  ///
  /// In en, this message translates to:
  /// **'OPERATIVE_NAME'**
  String get operativeName;

  /// No description provided for @confirmKey.
  ///
  /// In en, this message translates to:
  /// **'CONFIRM_KEY'**
  String get confirmKey;

  /// No description provided for @createOperative.
  ///
  /// In en, this message translates to:
  /// **'CREATE OPERATIVE'**
  String get createOperative;

  /// No description provided for @alreadyEnrolled.
  ///
  /// In en, this message translates to:
  /// **'ALREADY ENROLLED?  '**
  String get alreadyEnrolled;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'SIGN IN'**
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
