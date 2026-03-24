// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'CoreGym';

  @override
  String get navHome => 'Home';

  @override
  String get navNutrition => 'Nutrition';

  @override
  String get navWorkout => 'Workout';

  @override
  String get navProfile => 'Profile';

  @override
  String get goodMorning => 'Good morning';

  @override
  String get goodAfternoon => 'Good afternoon';

  @override
  String get goodEvening => 'Good evening';

  @override
  String get todayCalories => 'Calories Today';

  @override
  String get caloriesRemaining => 'remaining';

  @override
  String get caloriesOver => 'over';

  @override
  String get kcal => 'kcal';

  @override
  String get protein => 'Protein';

  @override
  String get carbs => 'Carbs';

  @override
  String get fat => 'Fat';

  @override
  String get todayMeals => 'Today\'s Meals';

  @override
  String get addFood => '+ Add Food';

  @override
  String get noMealsYet => 'No meals logged yet';

  @override
  String get logFirstMeal => 'Log your first meal today';

  @override
  String get logMeal => '+ Log Meal';

  @override
  String get breakfast => 'Breakfast';

  @override
  String get lunch => 'Lunch';

  @override
  String get dinner => 'Dinner';

  @override
  String get snack => 'Snack';

  @override
  String get notLogged => 'not logged';

  @override
  String items(int count) {
    return '$count items';
  }

  @override
  String get yourProgram => 'Your Program';

  @override
  String get activeProgram => 'ACTIVE PROGRAM';

  @override
  String get noActiveProgram => 'No active program';

  @override
  String get browsePrograms => 'Browse Programs →';

  @override
  String get startTodaysWorkout => 'Start Today\'s Workout';

  @override
  String get week => 'Week';

  @override
  String get ofWord => 'of';

  @override
  String get beginner => 'BEGINNER';

  @override
  String get intermediate => 'INTERMEDIATE';

  @override
  String get advanced => 'ADVANCED';

  @override
  String get lastWorkout => 'Last Workout';

  @override
  String get noWorkoutsYet => 'No workouts logged yet';

  @override
  String get logFirstWorkout => 'Log Your First Workout →';

  @override
  String get history => 'History';

  @override
  String get min => 'min';

  @override
  String get kgVolume => 'kg volume';

  @override
  String get water => 'Water';

  @override
  String get ofGlasses => 'of 8 glasses';

  @override
  String get steps => 'Steps';

  @override
  String get ofSteps => 'of 10,000 steps';

  @override
  String get kcalBurned => 'kcal burned';

  @override
  String get updateSteps => 'Update Steps';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get completeProfile =>
      'Complete your profile to see personalized goals.';

  @override
  String get fix => 'Fix →';

  @override
  String get nutritionTitle => 'NUTRITION';

  @override
  String get today => 'TODAY';

  @override
  String get historyTab => 'HISTORY';

  @override
  String get caloriesToday => 'CALORIES TODAY';

  @override
  String get caloriesConsumed => 'kcal consumed';

  @override
  String get searchFood => 'Search Food';

  @override
  String get searchHint => 'Search in English or Arabic...';

  @override
  String get allCategories => 'All';

  @override
  String get logFood => 'Log Food';

  @override
  String get quantity => 'Quantity';

  @override
  String get grams => 'grams';

  @override
  String get mealType => 'Meal';

  @override
  String get noFoodFound => 'Search for a food';

  @override
  String get last7Days => 'CALORIES — LAST 7 DAYS';

  @override
  String get dailyLogs => 'Daily Logs';

  @override
  String get goalMet => 'Goal met';

  @override
  String get underGoal => 'Under goal';

  @override
  String get noHistory => 'No history yet';

  @override
  String get startLogging => 'Start logging meals to see your progress';

  @override
  String get workoutTitle => 'WORKOUT';

  @override
  String get myProgram => 'My Program';

  @override
  String get programs => 'Programs';

  @override
  String get logWorkout => 'Log Workout';

  @override
  String get chooseMuscleGroup => 'Choose Muscle Group';

  @override
  String get sessionName => 'Session Name';

  @override
  String get startWorkout => 'Start Workout';

  @override
  String get chest => 'Chest';

  @override
  String get back => 'Back';

  @override
  String get shoulders => 'Shoulders';

  @override
  String get arms => 'Arms';

  @override
  String get legs => 'Legs';

  @override
  String get core => 'Core';

  @override
  String get fullBody => 'Full Body';

  @override
  String get activeWorkout => 'Active Workout';

  @override
  String get finish => 'Finish';

  @override
  String get addExercise => '+ Add Exercise';

  @override
  String get addSet => '+ Add Set';

  @override
  String get set => 'Set';

  @override
  String get kg => 'kg';

  @override
  String get reps => 'Reps';

  @override
  String lastBest(double weight, int reps) {
    return 'Last: ${weight}kg × $reps reps';
  }

  @override
  String get warmup => 'W';

  @override
  String get restTimer => 'Rest Timer';

  @override
  String get skipRest => 'Skip';

  @override
  String get restComplete => 'Rest complete!';

  @override
  String get workoutSummary => 'Workout Summary';

  @override
  String get totalVolume => 'Total Volume';

  @override
  String get totalSets => 'Total Sets';

  @override
  String get exercises => 'Exercises';

  @override
  String get duration => 'Duration';

  @override
  String get saveWorkout => 'Save Workout';

  @override
  String get discard => 'Discard';

  @override
  String get personalRecord => '🏆 PR!';

  @override
  String get searchExercise => 'Search exercises...';

  @override
  String get profileTitle => 'PROFILE';

  @override
  String get operativeData => 'OPERATIVE DATA';

  @override
  String get dailyTargets => 'DAILY TARGETS';

  @override
  String get thisMonth => 'THIS MONTH';

  @override
  String get rmProgress => '1RM PROGRESS';

  @override
  String get totalWorkouts => 'Total\nWorkouts';

  @override
  String get thisMonthWorkouts => 'This\nMonth';

  @override
  String get kcalLogged => 'kcal\nLogged';

  @override
  String get activeProgram2 => 'ACTIVE PROGRAM';

  @override
  String get age => 'Age';

  @override
  String get weight => 'Weight';

  @override
  String get height => 'Height';

  @override
  String get goal => 'Goal';

  @override
  String get calorieGoal => 'Calories';

  @override
  String get proteinGoal => 'Protein';

  @override
  String get weeklyWorkouts => 'Workouts';

  @override
  String get workoutsLabel => 'Workouts';

  @override
  String get caloriesLabel => 'Calories';

  @override
  String get estimatedOneRM => 'Estimated 1RM over time';

  @override
  String get editGoals => 'EDIT GOALS';

  @override
  String get signOut => 'SIGN OUT';

  @override
  String get editGoalsTitle => 'EDIT GOALS';

  @override
  String get dailyCalories => 'Daily Calories';

  @override
  String get dailyProtein => 'Daily Protein';

  @override
  String get signOutConfirm => 'Are you sure you want to sign out?';

  @override
  String get signOutTitle => 'Sign Out';

  @override
  String get weeklyWorkoutsLabel => 'Weekly Workouts';

  @override
  String get loginTitle => 'IGNITE';

  @override
  String get loginSubtitle => 'SYSTEM';

  @override
  String get loginDesc => 'ENTER CREDENTIALS TO AUTHORIZE ACCESS';

  @override
  String get operatorId => 'OPERATOR_ID';

  @override
  String get encryptedKey => 'ENCRYPTED_KEY';

  @override
  String get emailHint => 'user@coregym.app';

  @override
  String get passwordHint => '••••••••••••';

  @override
  String get forgotPassword => 'FORGOT?';

  @override
  String get initializeSession => 'INITIALIZE SESSION';

  @override
  String get externalAuth => 'EXTERNAL AUTH';

  @override
  String get google => 'GOOGLE';

  @override
  String get apple => 'APPLE';

  @override
  String get newOperative => 'NEW OPERATIVE?  ';

  @override
  String get enrollNow => 'ENROLL NOW';

  @override
  String get signupTitle => 'ENROLL';

  @override
  String get signupSubtitle => 'OPERATIVE';

  @override
  String get signupDesc => 'CREATE NEW SYSTEM ACCESS';

  @override
  String get operativeName => 'OPERATIVE_NAME';

  @override
  String get confirmKey => 'CONFIRM_KEY';

  @override
  String get createOperative => 'CREATE OPERATIVE';

  @override
  String get alreadyEnrolled => 'ALREADY ENROLLED?  ';

  @override
  String get signIn => 'SIGN IN';

  @override
  String get agreeTerms => 'I agree to the ';

  @override
  String get termsConditions => 'Terms & Conditions';

  @override
  String get and => ' and ';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get fullNameHint => 'Full Name';

  @override
  String get language => 'Language';

  @override
  String get arabic => 'العربية';

  @override
  String get english => 'English';

  @override
  String get changeLanguage => 'Change Language';

  @override
  String get weightLoss => 'Weight Loss';

  @override
  String get muscleGain => 'Muscle Gain';

  @override
  String get endurance => 'Endurance';

  @override
  String get flexibility => 'Flexibility';

  @override
  String get generalFitness => 'General Fitness';

  @override
  String get onboarding => 'Setup';

  @override
  String get next => 'Next';

  @override
  String get back2 => 'Back';

  @override
  String get getStarted => 'Get Started';

  @override
  String get yourAge => 'Your Age';

  @override
  String get yourWeight => 'Your Weight';

  @override
  String get yourHeight => 'Your Height';

  @override
  String get yourGoal => 'Your Goal';

  @override
  String get activityLevel => 'Activity Level';

  @override
  String get targetWeight => 'Target Weight';

  @override
  String get workoutsPerWeek => 'Workouts Per Week';

  @override
  String get sedentary => 'Sedentary';

  @override
  String get lightlyActive => 'Lightly Active';

  @override
  String get moderatelyActive => 'Moderately Active';

  @override
  String get veryActive => 'Very Active';

  @override
  String get extraActive => 'Extra Active';
}
