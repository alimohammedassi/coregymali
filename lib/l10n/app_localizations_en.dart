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
  String get navMessages => 'Messages';

  @override
  String get navCoaches => 'Coaches';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navMore => 'More';

  @override
  String get moreMenuTitle => 'Explore CoreGym';

  @override
  String get moreMarketplaceSubtitle =>
      'Browse coaches, compare plans, manage subscriptions';

  @override
  String get moreProfileSubtitle =>
      'Your body data, goals, settings and achievements';

  @override
  String get dashboardOverview => 'Dashboard Overview';

  @override
  String get goodMorning => 'Good morning';

  @override
  String get goodAfternoon => 'Good afternoon';

  @override
  String get goodEvening => 'Good evening';

  @override
  String get readyConquer => 'Ready to conquer your fitness goals today?';

  @override
  String get calorieGoalReached => 'Calorie goal reached! Peak performance! 🔥';

  @override
  String calorieProgressMsg(int pct) {
    return 'Completed $pct% of daily energy target';
  }

  @override
  String daysStreak(int count) {
    return '$count DAYS';
  }

  @override
  String get dayStreakLabel => 'day streak';

  @override
  String get dailyMetrics => 'DAILY METRIC MATRIX';

  @override
  String get details => 'Details';

  @override
  String get todayCalories => 'Calories Today';

  @override
  String get caloriesRemaining => 'remaining';

  @override
  String get caloriesOver => 'over';

  @override
  String get kcalLeft => 'KCAL LEFT';

  @override
  String get kcalOver => 'KCAL OVER';

  @override
  String get kcal => 'kcal';

  @override
  String get eaten => 'Eaten';

  @override
  String get burned => 'Burned';

  @override
  String get protein => 'Protein';

  @override
  String get carbs => 'Carbs';

  @override
  String get fat => 'Fat';

  @override
  String get additionalNutrients => 'Additional Nutrients';

  @override
  String get macronutrients => 'Macronutrients';

  @override
  String get fiber => 'Fiber';

  @override
  String get sugars => 'Sugar';

  @override
  String get sodium => 'Sodium';

  @override
  String get potassium => 'Potassium';

  @override
  String get calcium => 'Calcium';

  @override
  String get iron => 'Iron';

  @override
  String get cholesterol => 'Cholesterol';

  @override
  String get caffeine => 'Caffeine';

  @override
  String percentOfGoal(int pct) {
    return '$pct% of goal';
  }

  @override
  String get quickAddWater => '+250ml';

  @override
  String get quickWorkout => 'Workout';

  @override
  String get setGoalsTitle => 'Personalize Your Target Goals';

  @override
  String get setGoalsSubtitle =>
      'Set calories, macros & water for tailored tracking';

  @override
  String get moodSectionTitle => 'Choose Your Mood';

  @override
  String get moodTired => 'Tired';

  @override
  String get moodLight => 'Light';

  @override
  String get moodMedium => 'Medium';

  @override
  String get moodActive => 'Active';

  @override
  String get moodFull => 'Full Power';

  @override
  String get muscleGroupsTitle => 'Muscle Groups';

  @override
  String get muscleChest => 'Chest';

  @override
  String get muscleArms => 'Arms';

  @override
  String get muscleLegs => 'Legs';

  @override
  String get muscleCore => 'Core';

  @override
  String get aiWorkoutCta => 'Generate Your AI Workout';

  @override
  String get aiWorkoutSub => 'Smart Trainer — 45 min';

  @override
  String caloriesOf(int goal) {
    return 'of $goal';
  }

  @override
  String caloriesRemainingMsg(int remaining) {
    return '$remaining kcal remaining';
  }

  @override
  String caloriesOverMsg(int over) {
    return '$over kcal over goal';
  }

  @override
  String get addMeal => '+ Add Meal';

  @override
  String get scanAi => 'AI Scan';

  @override
  String get voiceLog => 'Voice';

  @override
  String get barcodeScan => 'Barcode';

  @override
  String get quickText => 'Text';

  @override
  String get foodLogSheetTitle => 'Log your food';

  @override
  String get foodLogSheetSubtitle => 'Every way to log your food, in one place';

  @override
  String get voiceLogSubtitle => 'Say it — AI logs the macros';

  @override
  String get quickTextSubtitle => 'Describe the meal — AI analyzes it';

  @override
  String get barcodeScanSubtitle => 'Scan the package, log instantly';

  @override
  String get addMealSubtitle => 'Browse the food database';

  @override
  String get dailyQuests => 'Daily Quests';

  @override
  String get hydrationHero => 'Hydration Hero';

  @override
  String get proteinChampion => 'Protein Champion';

  @override
  String get streakMaster => 'Streak Master';

  @override
  String xpEarned(int count) {
    return '+$count XP';
  }

  @override
  String levelLabel(int lvl) {
    return 'LVL $lvl';
  }

  @override
  String get todayMeals => 'Today\'s Meals';

  @override
  String get todaysFueling => 'Today\'s Fueling';

  @override
  String get addFood => '+ Add Food';

  @override
  String get noMealsYet => 'No meals logged yet';

  @override
  String get logFirstMeal => 'Log your first meal today';

  @override
  String get logMeal => 'Log Meal';

  @override
  String loggingNotToday(String date) {
    return 'You\'re logging for $date — not today';
  }

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
  String get activeTrainingProgram => 'ACTIVE TRAINING PROGRAM';

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
  String weekOfTotal(int current, int total) {
    return 'Week $current of $total';
  }

  @override
  String percentComplete(int pct) {
    return '$pct% complete';
  }

  @override
  String get beginner => 'BEGINNER';

  @override
  String get intermediate => 'INTERMEDIATE';

  @override
  String get advanced => 'ADVANCED';

  @override
  String get lastWorkout => 'Last Workout';

  @override
  String get lastWorkoutUpper => 'LAST WORKOUT';

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
  String get glasses => 'glasses';

  @override
  String get ofGlasses => 'of 8 glasses';

  @override
  String get ofGlassesGoal => 'of 8 goal';

  @override
  String get steps => 'Steps';

  @override
  String get ofSteps => 'of 10,000 steps';

  @override
  String ofStepsGoal(int pct) {
    return '$pct% of 10k';
  }

  @override
  String get activity => 'Activity';

  @override
  String ofGlassesCount(String count) {
    return 'of $count glasses';
  }

  @override
  String ofStepsTotal(String total) {
    return 'of $total';
  }

  @override
  String get addWaterPortion => '+ Add 250 ml';

  @override
  String connectHealthToSync(String source) {
    return 'Connect $source to sync';
  }

  @override
  String get kcalBurned => 'kcal burned';

  @override
  String get burnedToday => 'burned today';

  @override
  String get updateSteps => 'Update Steps';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get coachBannerTitle => 'Level up with a Pro Coach';

  @override
  String get coachBannerSubtitle =>
      'Certified coaches available · Personalized plans';

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
  String get workoutLibrary => 'Library';

  @override
  String get programs => 'Programs';

  @override
  String get logWorkout => 'Log Workout';

  @override
  String get sectionTodaysWorkout => 'TODAY\'S WORKOUT';

  @override
  String get sectionThisWeek => 'THIS WEEK';

  @override
  String get noActiveProgramHint =>
      'Head to the Library tab to pick a program and start your journey.';

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
  String get loginTitle => 'Welcome Back';

  @override
  String get loginSubtitle => 'CoreGym';

  @override
  String get loginDesc => 'Sign in to continue your fitness journey';

  @override
  String get operatorId => 'Email Address';

  @override
  String get encryptedKey => 'Password';

  @override
  String get emailHint => 'name@example.com';

  @override
  String get passwordHint => '••••••••';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get initializeSession => 'Log In';

  @override
  String get externalAuth => 'Or continue with';

  @override
  String get google => 'Google';

  @override
  String get apple => 'Apple';

  @override
  String get newOperative => 'Don\'t have an account? ';

  @override
  String get enrollNow => 'Sign up';

  @override
  String get signupTitle => 'Create Account';

  @override
  String get signupSubtitle => 'Join Core';

  @override
  String get signupDesc => 'Start your fitness journey today';

  @override
  String get operativeName => 'Full Name';

  @override
  String get confirmKey => 'Confirm Password';

  @override
  String get createOperative => 'Create Account';

  @override
  String get alreadyEnrolled => 'Already have an account? ';

  @override
  String get signIn => 'Sign In';

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
  String get loginTab => 'Log in';

  @override
  String get signUpTab => 'Sign up';

  @override
  String get trustCalorieTracking => 'Calorie tracking';

  @override
  String get trustHydration => 'Hydration';

  @override
  String get trustWorkouts => 'Workouts';

  @override
  String get trustCoachVerified => 'Coach verified';

  @override
  String get joiningAs => 'I am joining as';

  @override
  String get athleteRole => 'Athlete';

  @override
  String get coachRole => 'Coach';

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

  @override
  String get chatTitle => 'Messages';

  @override
  String get noConversations => 'No conversations yet';

  @override
  String get noConversationsHint => 'Subscribe to a coach to start chatting';

  @override
  String get typeMessage => 'Type a message...';

  @override
  String get sayHello => 'Say hello! 👋';

  @override
  String get retry => 'Retry';

  @override
  String get coach => 'Coach';

  @override
  String get client => 'Client';

  @override
  String get scanTitle => 'AI Food Scan';

  @override
  String get scanSubtitle => 'Snap your food, we\'ll do the rest';

  @override
  String get scanSaveToMeal => 'Log this meal to';

  @override
  String get scanIdleHint =>
      'One photo is all it takes — we\'ll detect each item, its weight and calories automatically.';

  @override
  String get scanCameraCta => 'Scan your food';

  @override
  String get scanGalleryCta => 'Choose from gallery';

  @override
  String get scanAnalyzingTitle => 'Analyzing your photo…';

  @override
  String get scanAnalyzingSubtitle => 'Detecting items, weight & macros';

  @override
  String get scanItemsHeader => 'Detected items';

  @override
  String get scanConfidenceHigh => 'High accuracy';

  @override
  String get scanConfidenceMedium => 'Medium accuracy';

  @override
  String get scanConfidenceLow => 'Low accuracy';

  @override
  String scanLogToMeal(String meal) {
    return 'Log to $meal';
  }

  @override
  String get scanErrorTitle => 'Oops!';

  @override
  String get scanRetrySamePhoto => 'Retry same photo';

  @override
  String get scanNewPhoto => 'New photo';

  @override
  String get scanErrorNetwork =>
      'No internet connection. Check your network and try again.';

  @override
  String get scanErrorUnauthorized =>
      'Please sign in first to use the scanner.';

  @override
  String get scanErrorNotFood =>
      'No clear food in the photo. Try another angle.';

  @override
  String get scanErrorAnalysis =>
      'We couldn\'t analyze the photo. Please try again.';

  @override
  String get scanErrorPersist =>
      'The photo was analyzed but saving failed. Please try again.';

  @override
  String get scanErrorUnknown =>
      'Something unexpected went wrong. Please try again.';

  @override
  String get voiceTitle => 'Voice Food Log';

  @override
  String get voiceSubtitle => 'Just say what you ate';

  @override
  String get voiceIdleHint =>
      'Describe your meal in one sentence — we\'ll transcribe it and estimate the calories automatically.';

  @override
  String get voiceRecordCta => 'Start recording';

  @override
  String get voiceStopCta => 'Stop & analyze';

  @override
  String get voiceRecordingHint =>
      'Listening… tap stop when you\'re done describing your meal.';

  @override
  String get voiceAnalyzingTitle => 'Analyzing your recording…';

  @override
  String get voiceTranscriptLabel => 'You said';

  @override
  String get voiceRetrySameAudio => 'Retry same recording';

  @override
  String get voiceNewRecording => 'New recording';

  @override
  String get voiceErrorNetwork =>
      'No internet connection. Check your network and try again.';

  @override
  String get voiceErrorUnauthorized =>
      'Please sign in first to use the voice logger.';

  @override
  String get voiceErrorMicrophone =>
      'Microphone access is needed. Enable it in Settings and try again.';

  @override
  String get voiceErrorNotFood =>
      'We couldn\'t hear any food in that recording. Try describing your meal again.';

  @override
  String get voiceErrorAnalysis =>
      'We couldn\'t understand that recording. Please try again.';

  @override
  String get voiceErrorPersist =>
      'The recording was analyzed but saving failed. Please try again.';

  @override
  String get voiceErrorUnknown =>
      'Something unexpected went wrong. Please try again.';

  @override
  String get textTitle => 'Text Food Log';

  @override
  String get textSubtitle => 'Type what you ate';

  @override
  String get textInputHint => 'e.g. breakfast: 2 eggs, toast and tea…';

  @override
  String get textAnalyzeCta => 'Analyze with AI';

  @override
  String get textAnalyzingTitle => 'Analyzing your meal…';

  @override
  String get textEmptyInput => 'Type what you ate first, then tap analyze.';

  @override
  String get textWroteLabel => 'You wrote';

  @override
  String get textErrorNetwork =>
      'No internet connection. Check your network and try again.';

  @override
  String get textErrorUnauthorized =>
      'Please sign in first to use the text logger.';

  @override
  String get textErrorNotFood =>
      'We couldn\'t find any food in that text. Try describing your meal again.';

  @override
  String get textErrorAnalysis =>
      'We couldn\'t understand that description. Please try again.';

  @override
  String get textErrorPersist =>
      'The meal was analyzed but saving failed. Please try again.';

  @override
  String get textErrorUnknown =>
      'Something unexpected went wrong. Please try again.';

  @override
  String get textEditDescription => 'Edit description';

  @override
  String get textNewDescription => 'New description';

  @override
  String get profileFirstRunNudge =>
      'Log your first workout to start ranking up!';

  @override
  String get dashboardEyebrow => 'MY DASHBOARD';

  @override
  String get dashboardSubscribers => 'Subscribers';

  @override
  String subscriberCount(int count) {
    return '$count total';
  }

  @override
  String get statActiveSubscribers => 'Active\nSubscribers';

  @override
  String get statAvgRating => 'Avg\nRating';

  @override
  String get statMonthlyRevenue => 'Monthly\nRevenue';

  @override
  String get statOpenSlots => 'Open\nSlots';

  @override
  String get filterAll => 'All';

  @override
  String get filterActive => 'Active';

  @override
  String get filterPending => 'Pending';

  @override
  String get filterExpired => 'Expired';

  @override
  String get noSubscribersYet => 'No subscribers yet';

  @override
  String get completeProfileHint =>
      'Complete your coach profile so clients can find and subscribe to you.';

  @override
  String get completeProfileCta => 'Complete Your Profile';

  @override
  String failedToLoadStats(String error) {
    return 'Failed to load stats: $error';
  }

  @override
  String daysLeft(int n) {
    return '$n days left';
  }

  @override
  String daysRemaining(int n) {
    return '$n days remaining';
  }

  @override
  String get statusExpired => 'Expired';

  @override
  String get statusPaused => 'Paused';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get planPhases => 'PLAN PHASES';

  @override
  String get paymentPaid => 'Paid';

  @override
  String get paymentUnpaid => 'Unpaid';

  @override
  String get paymentRefunded => 'Refunded';

  @override
  String phaseWeek(int w) {
    return 'Week $w';
  }

  @override
  String get previousDay => 'Previous day';

  @override
  String get nextDay => 'Next day';

  @override
  String get smartwatchSync => 'Smartwatch sync';

  @override
  String get appearance => 'Appearance';

  @override
  String get themeMode => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get saveFailed =>
      'Couldn\'t save — check your connection and try again.';

  @override
  String get aiScanSubtitle => 'Snap your meal — AI logs it for you';

  @override
  String get logAnotherWay => 'Or log another way';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get markAllRead => 'Mark all read';

  @override
  String get notificationsEmpty => 'No notifications yet';

  @override
  String get onbSkip => 'Skip';

  @override
  String get onbNext => 'Next';

  @override
  String get onbInitiate => 'INITIATE ENGINE';

  @override
  String get onbAlreadyMember => 'ALREADY A MEMBER?';

  @override
  String get onbSignInLink => 'SIGN IN';

  @override
  String get onbStepLabel => 'STEP';

  @override
  String get onb1Title => 'Transform your\nbody and mind';

  @override
  String get onb1Desc =>
      'Discover the power within you. Our comprehensive fitness programs are designed to help you achieve your goals and unlock your full potential.';

  @override
  String get onb2Title => 'Snap your meal\nAI tracks it';

  @override
  String get onb2Desc =>
      'Point your camera at any plate — AI reads it and logs calories, protein, carbs and fat in seconds. You can also log by voice or text.';

  @override
  String get onb3Title => 'Nutrition built\naround you';

  @override
  String get onb3Desc =>
      'Daily calorie and macro targets calculated for your body, hydration reminders on schedule, and coaches who adapt your plan as you progress.';

  @override
  String get onbSelectYour => 'SELECT YOUR';

  @override
  String get onbIdentity => 'IDENTITY';

  @override
  String get onbPersonalize =>
      'HELP US PERSONALIZE YOUR EXPERIENCE\nWITH CONTENT THAT MATTERS TO YOU';

  @override
  String get onbFemale => 'FEMALE';

  @override
  String get onbMale => 'MALE';

  @override
  String get onbContinue => 'CONTINUE';

  @override
  String get flow1Title => 'Let\'s get to\nknow you';

  @override
  String get flow1Subtitle => 'Enter your basic info';

  @override
  String get flow2Title => 'Your current\nbody';

  @override
  String get flow2Subtitle => 'Help us tailor your plan';

  @override
  String get flow3Title => 'What\'s your\ngoal?';

  @override
  String get flow3Subtitle => 'Select your primary focus';

  @override
  String get flow4Title => 'How fast do you\nwant results?';

  @override
  String get flow4Subtitle => 'Your pace sets the calorie adjustment';

  @override
  String get flowPaceNotNeeded =>
      'Your goal is about performance — calories stay at full burn, no pace adjustment needed.';

  @override
  String get flow5Title => 'How active\nare you?';

  @override
  String get flow5Subtitle => 'Helps calculate your nutrition';

  @override
  String get flow6Title => 'Set your\ntargets';

  @override
  String get flow6Subtitle => 'Build your routine';

  @override
  String get flowAge => 'AGE';

  @override
  String get flowGender => 'GENDER';

  @override
  String get flowHeight => 'HEIGHT (CM)';

  @override
  String get flowWeight => 'WEIGHT (KG)';

  @override
  String get flowBodyFat => 'BODY FAT %';

  @override
  String get flowOptional => 'OPTIONAL';

  @override
  String get flowKnowBodyFat => 'I know my body fat %';

  @override
  String get flowBodyFatHint =>
      'Lean-mass math (Katch-McArdle) — the most precise estimate';

  @override
  String get flowTargetWeight => 'TARGET WEIGHT';

  @override
  String get flowYears => 'years';

  @override
  String get flowGoalDescGain => 'Build strength and mass';

  @override
  String get flowGoalDescLoss => 'Burn fat, feel lighter';

  @override
  String get flowGoalDescEndurance => 'Improve stamina and cardio';

  @override
  String get flowGoalDescFlex => 'Move better, recover faster';

  @override
  String get flowGoalDescGeneral => 'Stay healthy and active';

  @override
  String get flowPaceSlow => 'Steady';

  @override
  String get flowPaceStandard => 'Standard';

  @override
  String get flowPaceFast => 'Fast';

  @override
  String flowPaceDescSlow(int delta) {
    return '$delta kcal / day — gentler on your routine';
  }

  @override
  String flowPaceDescStandard(int delta) {
    return '$delta kcal / day — the classic rate';
  }

  @override
  String flowPaceDescFast(int delta) {
    return '$delta kcal / day — demanding, needs discipline';
  }

  @override
  String get flowActDescSedentary => 'Little to no exercise';

  @override
  String get flowActDescLight => '1–3 days / week';

  @override
  String get flowActDescModerate => '3–5 days / week';

  @override
  String get flowActDescVery => '6–7 days / week';

  @override
  String get flowActDescExtra => 'Twice daily / athlete';

  @override
  String get flowEstDaily => 'Est. daily calories:';

  @override
  String get flowBmiTitle => 'Your BMI';

  @override
  String get flowBmiUnder => 'Underweight';

  @override
  String get flowBmiNormal => 'Normal';

  @override
  String get flowBmiOver => 'Overweight';

  @override
  String get flowBmiObese => 'Obese';

  @override
  String flowGainInsight(String diff) {
    return 'Gain $diff kg from current weight';
  }

  @override
  String flowLoseInsight(String diff) {
    return 'Lose $diff kg from current weight';
  }

  @override
  String get flowAllSet => 'You\'re all set!';

  @override
  String get flowAllSetDesc =>
      'Here\'s the plan your numbers built — change anything and it updates live.';

  @override
  String get flowResultDaily => 'YOUR DAILY TARGET';

  @override
  String get flowResultBmr => 'Resting burn (BMR)';

  @override
  String get flowResultActivity => 'Activity burn';

  @override
  String get flowResultGoal => 'Goal adjustment';

  @override
  String get flowResultMacros => 'RECOMMENDED MACROS';

  @override
  String get flowKcalDay => 'kcal / day';

  @override
  String get flowContinue => 'Continue';

  @override
  String get flowComplete => 'Complete';

  @override
  String get pushDialogTitle => 'Enable notifications';

  @override
  String get pushDialogBody =>
      'Enable notifications so we can remind you about meals, water and your daily calorie goal.';

  @override
  String get pushDialogCta => 'Got it';

  @override
  String get splashError =>
      'Couldn\'t connect. Check your internet and try again.';

  @override
  String get splashLoading => 'Loading';

  @override
  String get rankTitle => 'Rankings';

  @override
  String get rankLast7 => 'Last 7 days';

  @override
  String get rankLast30 => 'Last 30 days';

  @override
  String get rankEmpty =>
      'No ranked clients yet. Log your meals and water to enter the board!';

  @override
  String rankDaysLogged(int n) {
    return '$n days logged';
  }

  @override
  String cpDaysLoggedN(int n) {
    return '$n days';
  }

  @override
  String get cpDaysLogged => 'Days logged';

  @override
  String get cpAvgScore => 'Avg score';

  @override
  String get cpWorkouts => 'Workouts';

  @override
  String get cpCommitment => 'Commitment activity';

  @override
  String get cpLess => 'Less';

  @override
  String get cpMore => 'More';

  @override
  String get cpTrend => 'Trend';

  @override
  String get cpDaily => 'Daily';

  @override
  String get cpWeekly => 'Weekly';

  @override
  String get cpCumulative => 'Cumulative';

  @override
  String get cpCalories => 'Calories';

  @override
  String get cpWater => 'Water';

  @override
  String get cpSteps => 'Steps';

  @override
  String get cpNoData => 'No data logged yet';

  @override
  String get cpActivityPrivate =>
      'This member keeps their daily activity private — you\'re seeing their competitive standing only.';

  @override
  String get rankCard => 'Rankings';

  @override
  String get rankCardSub => 'Weekly leaderboard';

  @override
  String get assignedWorkoutTitle => 'Today\'s Workout';

  @override
  String get assignedNutritionTitle => 'Today\'s Nutrition';

  @override
  String get assignedNutritionNoPlan => 'No nutrition plan assigned';

  @override
  String get assignedNutritionNoPlanBody =>
      'Your coach hasn\'t assigned a nutrition plan for today yet.';

  @override
  String get assignedNutritionNoMealsToday => 'No meals assigned for today';

  @override
  String get assignedNutritionStatMeals => 'Meals';

  @override
  String get assignedNutritionStatFoods => 'Foods';

  @override
  String get assignedNutritionStatusAssigned => 'Assigned';

  @override
  String get assignedNutritionStatusCompleted => 'Completed';

  @override
  String get assignedNutritionStatusSkipped => 'Skipped';

  @override
  String get assignedNutritionChanged => 'Changed';

  @override
  String get assignedNutritionMealTotal => 'Meal total';

  @override
  String get assignedNutritionMarkEaten => 'Mark as eaten';

  @override
  String get assignedNutritionMarkedEaten =>
      'Meal logged — calories added to today';

  @override
  String get assignedNutritionMarkFailed =>
      'Couldn\'t mark the meal — try again';

  @override
  String assignedNutritionNextDay(String date) {
    return 'No meals today — showing next scheduled day: $date';
  }

  @override
  String assignedCardMeta(int ex, int min) {
    return '$ex exercises · ~$min min';
  }

  @override
  String assignedSetProgress(int done, int total) {
    return '$done of $total sets done';
  }

  @override
  String assignedRestSecs(int sec) {
    return 'Rest ${sec}s';
  }

  @override
  String get assignedLogSet => 'Log Set';

  @override
  String get assignedContinue => 'Continue Workout';

  @override
  String get assignedFinish => 'Finish Workout';

  @override
  String get assignedResume => 'Resume workout';

  @override
  String get assignedReadyHint => 'Ready to go — tap to start';

  @override
  String get assignedStatExercises => 'Exercises';

  @override
  String get assignedStatSets => 'Sets';

  @override
  String get assignedStatTime => 'Est. time';

  @override
  String get assignedDoneTitle => 'Workout completed';

  @override
  String get assignedDoneBody =>
      'Nice work — your coach can see this session now.';

  @override
  String get assignedSkip => 'Skip workout';

  @override
  String get assignedSkipConfirmTitle => 'Skip this workout?';

  @override
  String get assignedSkipConfirmBody =>
      'It will be marked as skipped and your coach will see it that way.';

  @override
  String get assignedSkippedDone => 'Workout skipped';

  @override
  String get assignedHistoryTitle => 'Coach assignments';

  @override
  String get assignedStatusAssigned => 'Scheduled';

  @override
  String get assignedStatusStarted => 'In progress';

  @override
  String get assignedStatusCompleted => 'Completed';

  @override
  String get assignedStatusSkipped => 'Skipped';

  @override
  String get assignedNone => 'No workout assigned today';

  @override
  String get assignedNotes => 'Notes';

  @override
  String assignedTarget(String sets, String reps) {
    return '$sets sets × $reps reps';
  }

  @override
  String assignedTargetWeight(String sets, String reps, String weight) {
    return '$sets sets × $reps reps @ $weight kg';
  }

  @override
  String get assignedErrorStart => 'Couldn\'t start the workout — try again';

  @override
  String get assignedErrorSet =>
      'Couldn\'t log the set — check your connection';

  @override
  String get assignedErrorFinish => 'Couldn\'t finish the workout — try again';

  @override
  String get assignedEnterReps => 'Enter the reps first';

  @override
  String assignedSetsLogged(int count) {
    return '$count sets logged';
  }

  @override
  String get assignedDone => 'Done';

  @override
  String foodTargetingMeal(String meal) {
    return 'Targeting: $meal';
  }

  @override
  String get foodPopularFoods => 'POPULAR FOODS';

  @override
  String foodResultsFound(int count) {
    return '$count results found';
  }

  @override
  String get foodFilters => 'Filters';

  @override
  String get foodFilterCalories => 'Calories (kcal)';

  @override
  String get foodFilterProtein => 'Protein (g)';

  @override
  String get foodFilterAny => 'Any';

  @override
  String get foodFilterKcal => 'kcal';

  @override
  String get foodFilterGrams => 'g';

  @override
  String get foodApplyFilters => 'Apply';

  @override
  String get foodResetFilters => 'Reset filters';

  @override
  String get foodNoResultsTitle => 'No foods match your filters';

  @override
  String get foodNoResultsSubtitle =>
      'Try widening the ranges or reset the filters';

  @override
  String get foodNoFoodsTitle => 'No foods found';

  @override
  String get foodNoFoodsSubtitle => 'Try another spelling or search keyword';

  @override
  String get catArabic => 'Arabic';

  @override
  String get catProtein => 'Protein';

  @override
  String get catCarbs => 'Carbs';

  @override
  String get catVegetables => 'Veggies';

  @override
  String get catFruits => 'Fruits';

  @override
  String get catDairy => 'Dairy';

  @override
  String get catFats => 'Fats';

  @override
  String get catFastfood => 'Fast Food';

  @override
  String get catDrinks => 'Drinks';

  @override
  String get catSnacks => 'Snacks';

  @override
  String get catDesserts => 'Desserts';

  @override
  String get catStreetFood => 'Street Food';

  @override
  String get catBurgers => 'Burgers';

  @override
  String get catPizza => 'Pizza';

  @override
  String get catPasta => 'Pasta';

  @override
  String get catSandwiches => 'Sandwiches';

  @override
  String get catSushi => 'Sushi';

  @override
  String get catFriedChicken => 'Fried Chicken';

  @override
  String get catBreakfast => 'Breakfast';

  @override
  String get catOther => 'Other';

  @override
  String get foodLogSaveError =>
      '❌ An error occurred while saving — check your internet connection';

  @override
  String get foodLogPer100g => 'per 100g';

  @override
  String get foodLogCalories => 'Calories';

  @override
  String get foodLogProtein => 'Protein';

  @override
  String get foodLogCarbs => 'Carbs';

  @override
  String get foodLogFat => 'Fat';

  @override
  String get foodLogQuantity => 'Quantity';

  @override
  String get foodLogAssignMeal => 'Assign to meal';

  @override
  String get foodLogLogged => 'Logged!';

  @override
  String get foodLogConfirm => 'Log Food';

  @override
  String get suggestMeal => 'Suggest a meal';

  @override
  String get dailyMeals => 'Daily Meals';

  @override
  String itemsLoggedCount(String count) {
    return '$count items logged';
  }

  @override
  String kcalRemainingShort(String kcal) {
    return '$kcal kcal remaining';
  }

  @override
  String kcalGoalLabel(String kcal) {
    return '$kcal kcal goal';
  }

  @override
  String ofGoal(String goal) {
    return 'of $goal';
  }

  @override
  String get syncingNutrition => 'Syncing nutrition data...';

  @override
  String get addLabel => 'Add';

  @override
  String get quickLabel => 'Quick';

  @override
  String get removeLabel => 'Remove';

  @override
  String get keepGoing => 'Keep going!';

  @override
  String get suggestCardSubtitle =>
      'AI builds a meal that hits your remaining calories';

  @override
  String get suggestSheetTitle => 'Suggest a meal';

  @override
  String get suggestMealSlot => 'MEAL';

  @override
  String get suggestStyle => 'STYLE';

  @override
  String get suggestCaloriesRow => 'CALORIES';

  @override
  String get suggestCravingLabel => 'CRAVING (OPTIONAL)';

  @override
  String get suggestCravingHint =>
      'The meal in your head — e.g. koshary, burger, shawarma';

  @override
  String get suggestCaloriesLabel => 'CALORIES';

  @override
  String get suggestCaloriesHint => 'e.g. 550';

  @override
  String get suggestCaloriesInvalid => 'Enter 80–5000 kcal';

  @override
  String get suggestUseRemaining => 'Use remaining';

  @override
  String get suggestCustomCaloriesTitle => 'Your target';

  @override
  String get suggestCustomCaloriesSubtitle =>
      'Type the calories you want this meal to hit — AI builds exactly to that number';

  @override
  String get suggestGoalMetTitle => 'You\'ve hit your goal';

  @override
  String get suggestGoalMetBody =>
      'Your calories for today are covered — there\'s no room left for a suggested meal.';

  @override
  String get suggestMatchLabel => 'match';

  @override
  String get suggestRegenerate => 'Another idea';

  @override
  String get styleBalanced => 'Balanced';

  @override
  String get styleHighProtein => 'High protein';

  @override
  String get styleLight => 'Light';

  @override
  String get styleHome => 'Home-style';

  @override
  String get styleJunk => 'Junk food';

  @override
  String get suggestCta => 'Suggest for me';

  @override
  String get suggestTargetLabel => 'Target';

  @override
  String get stageReadRemaining => 'Reading your remaining macros';

  @override
  String get stageScanCatalog => 'Picking from your foods catalog';

  @override
  String get stageCompose => 'Composing your meal';

  @override
  String get stageValidate => 'Checking the numbers';

  @override
  String get tryAgain => 'Try again';

  @override
  String get suggestedMealTitle => 'Suggested meal';

  @override
  String get buildingMeal => 'Building your meal...';

  @override
  String get logThisMeal => 'Log this meal';

  @override
  String get mealLogged => 'Meal logged';

  @override
  String get servingUnitLabel => 'serving';

  @override
  String get suggestNoRemaining =>
      'You\'ve used your calories for today — no room left for a suggested meal.';

  @override
  String get suggestNoMatch =>
      'Couldn\'t build a meal that fits your remaining macros. Try again in a moment.';

  @override
  String get suggestUnavailable =>
      'The suggestion service is busy right now. Try again in a bit.';

  @override
  String get suggestFailed => 'Couldn\'t get a suggestion. Try again.';

  @override
  String removeLogConfirm(String name) {
    return 'Remove \"$name\" from today\'s log?';
  }

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get deleteAccountTitle => 'Delete Account?';

  @override
  String get deleteAccountBody =>
      'Your account and all of its data — profile, workout history, subscriptions — will be permanently deleted. This cannot be undone.';

  @override
  String get deleteAccountFailed => 'Couldn\'t delete your account. Try again.';

  @override
  String get legal => 'LEGAL';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get rankRookie => 'ROOKIE';

  @override
  String get rankIron => 'IRON';

  @override
  String get rankBronze => 'BRONZE';

  @override
  String get rankSilver => 'SILVER';

  @override
  String get rankGold => 'GOLD';

  @override
  String get lbTierDiamond => 'DIAMOND';

  @override
  String get lbWeeklyChallenge => 'WEEKLY CHALLENGE';

  @override
  String get lbMonthlyChallenge => 'MONTHLY CHALLENGE';

  @override
  String lbDaysLeft(int n) {
    return '$n days left';
  }

  @override
  String lbResetsOn(String date) {
    return 'New cycle starts $date';
  }

  @override
  String get lbWindowWeekly => 'Weekly';

  @override
  String get lbWindowMonthly => 'Monthly';

  @override
  String get lbCatOverall => 'Overall';

  @override
  String get lbCatCalories => 'Calories';

  @override
  String get lbCatWater => 'Water';

  @override
  String get lbCatWorkouts => 'Workouts';

  @override
  String get lbCatStreak => 'Streak';

  @override
  String get lbCatLongestStreak => 'Longest streak';

  @override
  String get lbYourRank => 'YOUR RANK';

  @override
  String get lbUnitPts => 'pts';

  @override
  String get lbUnitWorkouts => 'workouts';

  @override
  String get lbUnitDays => 'days';

  @override
  String lbDayStreakN(int n) {
    return '$n-day streak';
  }

  @override
  String lbLongestStreakN(int n) {
    return 'Longest: $n days';
  }

  @override
  String get lbLeadingBoard => 'You\'re leading the board';

  @override
  String lbTiedWith(int rank) {
    return 'Level with #$rank';
  }

  @override
  String lbPtsToNextRank(int n, int rank) {
    return '$n pts to #$rank';
  }

  @override
  String get lbTopTier => 'Top tier reached';

  @override
  String lbPtsToTier(int n, String tier) {
    return '$n pts to $tier';
  }

  @override
  String get lbNewHere => 'NEW';

  @override
  String get lbSameRank => 'No change';

  @override
  String lbMovedUp(int n) {
    return 'Moved up $n spots';
  }

  @override
  String lbMovedDown(int n) {
    return 'Dropped $n spots';
  }

  @override
  String get lbLastWeek => 'LAST WEEK';

  @override
  String get lbNewCycle => 'New competition started';

  @override
  String get lbDismiss => 'Dismiss';

  @override
  String get lbScoreTooltip => 'How your score is calculated';

  @override
  String get lbScoreCalcTitle => 'Your score';

  @override
  String get lbScoreFormula =>
      'Score = 60% calorie adherence + 40% water adherence over the selected window. Log consistently to climb.';

  @override
  String get lbSearchHint => 'Search a name…';

  @override
  String lbNoSearchResults(String query) {
    return 'No one named \"$query\" here';
  }

  @override
  String get lbEmptyCategory => 'No one has claimed this board yet';

  @override
  String get lbEmptyCategorySub => 'Log today and take the top spot';

  @override
  String get lbPinJump => 'Your rank — tap to jump';

  @override
  String get lbYou => 'You';

  @override
  String get lbYouBadge => 'YOU';

  @override
  String get lbCompCardTitle => 'COMPETITIVE';

  @override
  String lbRankOf(int rank, int total) {
    return '#$rank of $total';
  }

  @override
  String lbRankOfTotal(int total) {
    return 'of $total';
  }

  @override
  String lbRankJourney(int from, int to) {
    return '#$from → #$to';
  }

  @override
  String get lbRankHistoryEmpty => 'Not enough data yet';

  @override
  String get profilePhotoTitle => 'PROFILE PHOTO';

  @override
  String get editDataTitle => 'EDIT DATA';

  @override
  String get saveDataBtn => 'SAVE DATA';

  @override
  String get saveGoalsBtn => 'SAVE GOALS';

  @override
  String get viewPhoto => 'View Photo';

  @override
  String get changePhoto => 'Change Photo';

  @override
  String get uploadPhoto => 'Upload Photo';

  @override
  String get profilePhotoUpdated => 'Profile photo updated';

  @override
  String get uploadFailed => 'Upload failed. Try again.';

  @override
  String get coachDashboard => 'Coach Dashboard';

  @override
  String get coachDashboardSubtitle => 'Manage clients & programs on the web';

  @override
  String get noProgressData => 'No progress data yet';

  @override
  String get refresh => 'Refresh';

  @override
  String get refreshProfile => 'Refresh profile';

  @override
  String get profilePhotoTapOptions => 'Profile photo. Tap for options.';

  @override
  String get editBodyData => 'Edit body data';

  @override
  String get editDailyTargets => 'Edit daily targets';

  @override
  String activeProgramTapHint(String name) {
    return 'Active program: $name. Tap to view.';
  }

  @override
  String chartSessionsSemantics(int count) {
    return '1RM progress line chart — $count sessions recorded.';
  }

  @override
  String sessionsCount(int count) {
    return '$count sessions';
  }

  @override
  String get yearsShort => 'yrs';

  @override
  String get perWeekShort => '×/wk';

  @override
  String get statsLoadFailed => 'Couldn\'t load your stats.';

  @override
  String get invalidAgeRange =>
      'Age must be a whole number between 10 and 100.';

  @override
  String get invalidWeightRange =>
      'Weight must be a number between 20 and 300 kg.';

  @override
  String get invalidHeightRange =>
      'Height must be a number between 100 and 250 cm.';

  @override
  String get invalidCalories => 'Calories must be a non-negative whole number.';

  @override
  String get invalidProtein => 'Protein must be a non-negative whole number.';

  @override
  String get invalidWeeklyWorkouts =>
      'Weekly workouts must be a non-negative whole number.';

  @override
  String get motivationEmpty => 'Log your first meal to start your day! 🌟';

  @override
  String get motivationStart => 'Great start! Fuel up with clean nutrients 🌱';

  @override
  String get motivationZone => 'You are in the zone! Hit your protein target ⚡';

  @override
  String get motivationAlmost => 'Almost at your target! Finish strong 🎯';

  @override
  String get motivationBullseye => 'Bullseye! Perfect nutrition day 🎉';

  @override
  String get motivationOver => 'Over target — balance with light hydration 🧘';

  @override
  String addCaloriesTo(String meal) {
    return 'Add calories directly to $meal';
  }

  @override
  String get addToLog => 'Add to Log';

  @override
  String get foodItemFallback => 'Food item';

  @override
  String get editServingMeal => 'Edit serving & meal section';

  @override
  String get overBudget => 'Over Budget';

  @override
  String targetKcal(String kcal) {
    return 'Target: $kcal kcal';
  }

  @override
  String dailyTargetMl(String ml) {
    return 'Daily target: $ml ml';
  }

  @override
  String get waterGlassSub => 'Glass 🥛';

  @override
  String get waterBottleSub => 'Bottle 💧';

  @override
  String get dailyGoalTargets => 'Daily Goal Targets';

  @override
  String macroLeftKcal(String kcal, String grams) {
    return '$kcal kcal · ${grams}g left';
  }

  @override
  String get noFoodLogged => 'No food logged yet';

  @override
  String get mealTotals => 'Meal totals:';

  @override
  String get removeItem => 'Remove item?';

  @override
  String get avgCalories => 'Avg Calories';

  @override
  String get onTrack => 'On Track';

  @override
  String get daysInZone => 'days in zone';

  @override
  String get workouts => 'Workouts';

  @override
  String get thisWeek => 'this week';

  @override
  String get kcalPerDay => 'kcal / day';

  @override
  String get aiWaitWorking => 'Still working…';

  @override
  String aiWaitElapsed(String secs) {
    return '${secs}s';
  }

  @override
  String get aiWaitSlow =>
      'Taking a little longer than usual — still working on it. Busy moments can take up to a minute.';

  @override
  String get verifyTitle1 => 'VERIFY';

  @override
  String get verifyTitle2 => 'CODE';

  @override
  String verifySubtitle(String email) {
    return 'We\'ve sent a verification code to $email';
  }

  @override
  String get verifyButton => 'VERIFY CODE';

  @override
  String get verifyDidntReceive => 'DIDN\'T RECEIVE?';

  @override
  String verifyResendIn(int seconds) {
    return 'RESEND IN ${seconds}s';
  }

  @override
  String get verifyResend => 'RESEND';

  @override
  String get verifyRemember => 'REMEMBER PASSWORD?';

  @override
  String get verifyDidntRemember => 'DIDN\'T REMEMBER IT?';

  @override
  String get verifySignIn => 'SIGN IN';

  @override
  String get verifyErrIncomplete => 'Enter the full code from your email';

  @override
  String get verifyErrRateLimit => 'Too many attempts. Please wait a moment.';

  @override
  String get verifyErrInvalid => 'Invalid or expired code';

  @override
  String get verifyErrKeepTyping =>
      'Invalid code - if it has more digits, keep typing';

  @override
  String get verifyErrConnection =>
      'Something went wrong. Check your connection.';

  @override
  String get verifySnackResent => 'A new code was sent to your email';

  @override
  String get verifySnackWait => 'Please wait before requesting another code';

  @override
  String get verifySnackFailed => 'Could not resend the code. Try again.';

  @override
  String get forgotTitle1 => 'RESET';

  @override
  String get forgotTitle2 => 'ACCESS';

  @override
  String get forgotSubtitle => 'ENTER YOUR EMAIL TO RECEIVE A RESET CODE';

  @override
  String get forgotEmailLabel => 'OPERATOR_ID';

  @override
  String get forgotEmailEmpty => 'Please enter your email';

  @override
  String get forgotEmailInvalid => 'Please enter a valid email';

  @override
  String get forgotSendButton => 'SEND RESET CODE';

  @override
  String get resetTitle1 => 'NEW';

  @override
  String get resetTitle2 => 'PASSWORD';

  @override
  String get resetSubtitle => 'ENTER YOUR NEW ENCRYPTED KEY';

  @override
  String get resetNewKey => 'NEW_KEY';

  @override
  String get resetConfirmKey => 'CONFIRM_KEY';

  @override
  String get resetPassEmpty => 'Please enter a password';

  @override
  String get resetPassShort => 'Password must be at least 8 characters';

  @override
  String get resetPassWeak => 'Must contain uppercase, lowercase, and number';

  @override
  String get resetPassConfirmEmpty => 'Please confirm your password';

  @override
  String get resetPassMismatch => 'Passwords do not match';

  @override
  String get resetButton => 'RESET PASSWORD';

  @override
  String get resetSessionExpired =>
      'Your reset session expired. Please request a new code.';

  @override
  String get resetSuccess => 'Password reset successfully!';

  @override
  String get authLoginTitleA => 'Welcome';

  @override
  String get authLoginTitleB => 'Back';

  @override
  String get authSignupTitleA => 'Create';

  @override
  String get authSignupTitleB => 'Account';

  @override
  String get authStrengthWeak => 'Weak';

  @override
  String get authStrengthFair => 'Fair';

  @override
  String get authStrengthStrong => 'Strong';

  @override
  String get authNameError => 'Enter your name';

  @override
  String get authPassMismatch => 'Passwords do not match';

  @override
  String get authPassMatch => 'Passwords match';

  @override
  String get authEmailEmpty => 'Please enter your email';

  @override
  String get authEmailError => 'Please enter a valid email';

  @override
  String get authPassEmpty => 'Please enter your password';

  @override
  String get authPassShort => 'Password must be at least 6 characters';

  @override
  String get authAgreeTerms => 'Please agree to the Terms & Conditions';

  @override
  String get authAgreeTermsShort => 'Agree to the Terms first';

  @override
  String get authAppleSoon => 'Apple sign-in coming soon';

  @override
  String get authLegalSoon => 'Legal pages coming soon';

  @override
  String get authShowPass => 'Show password';

  @override
  String get authHidePass => 'Hide password';

  @override
  String authWelcomeBack(String email) {
    return 'Welcome back, $email!';
  }

  @override
  String authWelcomeNew(String name) {
    return 'Welcome, $name!';
  }

  @override
  String get authGoogleOk => 'Signed in with Google!';

  @override
  String get gymAttEntryTitle => 'Automatic Gym Attendance';

  @override
  String get gymAttEntryDesc => 'Track your gym visits automatically';

  @override
  String get gymAttEntryActive => 'Attendance tracking is active';

  @override
  String get gymAttIntroTitle => 'Automatic Gym Attendance';

  @override
  String get gymAttIntroBody =>
      'CoreGym detects when you arrive at your gym and logs your visit automatically — no buttons, no check-ins.';

  @override
  String get gymAttIntroRuleTitle => 'How it works';

  @override
  String get gymAttIntroRuleBody =>
      'Stay 25 minutes or more inside your gym\'s area and the visit is recorded automatically. Passing by without stopping is ignored.';

  @override
  String get gymAttIntroPrivacy =>
      'Location is used only to detect gym visits — it stays on your device and is never sold or shared.';

  @override
  String get gymAttIntroCta => 'Get Started';

  @override
  String get gymAttPromoCta => 'Enable from Profile';

  @override
  String get gymAttPermContinue => 'Continue';

  @override
  String get gymAttPermAllow => 'Allow';

  @override
  String get gymAttPermSkip => 'Not now';

  @override
  String get gymAttPermGranted => 'Enabled';

  @override
  String get gymAttOpenSettings => 'Open Settings';

  @override
  String get gymAttPermDeniedTitle => 'Permission not granted';

  @override
  String get gymAttPermDeniedBody =>
      'This permission is needed for automatic tracking. You can enable it anytime from Settings.';

  @override
  String get gymAttContinueWithout => 'Continue without it';

  @override
  String get gymAttLocTitle => 'Know when you arrive';

  @override
  String get gymAttLocBody =>
      'We use your location only to detect when you arrive at or leave your gym. Nothing else.';

  @override
  String get gymAttLocWhy =>
      'Why we need this: detection runs on your device and only near your gym.';

  @override
  String get gymAttBgTitle => 'Works even when the app is closed';

  @override
  String get gymAttBgBody =>
      'Background location lets CoreGym detect your visit without opening the app. Detection only activates near your gym to protect your battery and privacy.';

  @override
  String get gymAttBgWhy =>
      'Why we need this: without it, visits are only detected while the app is open.';

  @override
  String get gymAttActTitle => 'Optional, but smarter';

  @override
  String get gymAttActBody =>
      'Activity data like steps can optionally confirm you were actually training — attendance never depends on it. Notifications tell you when a visit is recorded.';

  @override
  String get gymAttActWhy => 'Fully optional — tracking works without it.';

  @override
  String get gymAttMapTitle => 'Choose your gym';

  @override
  String get gymAttMapSubtitle =>
      'Tap the map or search to place the pin on your gym';

  @override
  String get gymAttMapFinding => 'Finding your location...';

  @override
  String get gymAttMapLocErrorTitle => 'We couldn\'t find your location';

  @override
  String get gymAttRetry => 'Try Again';

  @override
  String get gymAttSearchHint => 'Search gym or area';

  @override
  String get gymAttSearchNoResults => 'No results found';

  @override
  String get gymAttMyLocation => 'My Location';

  @override
  String get gymAttYourGym => 'Your Gym';

  @override
  String get gymAttTrackingRadius => 'Tracking radius';

  @override
  String gymAttRadiusValue(String meters) {
    return '$meters m';
  }

  @override
  String gymAttDistanceValue(String distance) {
    return '$distance away';
  }

  @override
  String get gymAttConfirmGym => 'Confirm Gym';

  @override
  String get gymAttUnnamedGym => 'Selected location';

  @override
  String get gymAttConfirmAreaTitle => 'Tracking area';

  @override
  String get gymAttConfirmExplain =>
      'CoreGym will automatically detect when you arrive at and leave this area. Visits of 25 minutes or more are recorded.';

  @override
  String get gymAttStartTracking => 'Start Tracking';

  @override
  String get gymAttChangeGym => 'Change Gym';

  @override
  String get gymAttSuccessTitle => 'You\'re all set';

  @override
  String get gymAttSuccessBody =>
      'CoreGym will track your gym visits automatically.';

  @override
  String get gymAttMyGymTitle => 'My Gym';

  @override
  String get gymAttTrackingOn => 'Automatic tracking ON';

  @override
  String get gymAttTrackingOnDesc => 'CoreGym is watching for your gym visits.';

  @override
  String get gymAttSaving => 'Saving...';

  @override
  String get gymAttSaveError => 'Couldn\'t save your gym. Try again.';

  @override
  String get gymAttBannerInsideTitle => 'You\'re inside your gym area';

  @override
  String get gymAttBannerCountdownLabel => 'Visit will be recorded in';

  @override
  String get gymAttBannerCancel => 'Cancel';

  @override
  String get gymAttBannerConfirmed => 'Visit recorded';

  @override
  String gymAttBannerConfirmedDesc(String minutes) {
    return '$minutes min at your gym';
  }

  @override
  String get gymAttHistoryTitle => 'Attendance log';

  @override
  String get gymAttHeatmapNoVisit => 'No visit';

  @override
  String gymAttHeatmapVisited(String date, String minutes) {
    return '$date · $minutes min at the gym';
  }

  @override
  String get gymAttStatsWeek => 'This week';

  @override
  String get gymAttStatsMonth => 'This month';

  @override
  String get gymAttStatsAvgWeekly => 'Weekly avg';

  @override
  String get gymAttStatsAvgMonthly => 'Monthly avg';

  @override
  String get gymAttViewWeekly => 'Weekly';

  @override
  String get gymAttViewMonthly => 'Monthly';

  @override
  String get gymAttViewYearly => 'Yearly';

  @override
  String get gymAttStatsYear => 'This year';

  @override
  String get gymAttStatsStreak => 'Streak';

  @override
  String get gymAttStatsLastVisit => 'Last visit';

  @override
  String gymAttStatsDays(String n) {
    return '$n days';
  }

  @override
  String get gymAttGeofenceActive => 'Geofence active';

  @override
  String get gymAttFacilityLabel => 'Home facility';

  @override
  String get gymAttAutoPill => 'Auto check-in on';

  @override
  String get gymAttLastSession => 'Last session';

  @override
  String gymAttDurationH(String h) {
    return '${h}h';
  }

  @override
  String gymAttDurationHM(String h, String m) {
    return '${h}h ${m}m';
  }

  @override
  String gymAttDurationM(String m) {
    return '${m}m';
  }

  @override
  String get gymAttMetricsTitle => 'Metrics';

  @override
  String get gymAttTotalVisits => 'Total visits';

  @override
  String get gymAttPaceAvg => 'Pace avg';

  @override
  String get gymAttPerWeek => 'days/wk';

  @override
  String get gymAttPerMonth => 'days/mo';

  @override
  String get gymAttAvgDwell => 'Avg dwell';

  @override
  String get gymAttPerSession => 'per session';

  @override
  String get gymAttMatrixTitle => 'Attendance matrix';

  @override
  String get gymAttMatrixSubYear => '52-week consistency';

  @override
  String get gymAttMatrixSubMonth => 'This month\'s consistency';

  @override
  String get gymAttMatrixSubWeek => 'Last 7 days';

  @override
  String get gymAttHeatLess => 'Less';

  @override
  String get gymAttHeatMore => 'More';

  @override
  String get gymAttRecentTitle => 'Recent check-ins';

  @override
  String get gymAttRowCompleted => 'Completed';

  @override
  String get gymAttRowGeofence => 'Geofence verified';

  @override
  String get gymAttManualCheckInSuccess => 'Check-in recorded';

  @override
  String get gymAttSettingsTooltip => 'Gym settings';

  @override
  String get gymAttSignalPing => 'Ping';

  @override
  String gymAttSignalPingMs(String ms) {
    return '$ms ms';
  }

  @override
  String get gymAttHotBadge => 'HOT';

  @override
  String get gymAttViewFullLog => 'View all';

  @override
  String gymAttSessionInProgress(String m) {
    return 'In progress · $m min so far';
  }

  @override
  String get gymAttInsideZone => 'Inside zone';

  @override
  String get gymAttManualCheckInNow => 'Check in now';

  @override
  String get telemetryLogTag => 'Telemetry • Log';

  @override
  String get dayTargetTelemetry => 'Day target • fuel telemetry';

  @override
  String get macrosTelemetry => 'Macros telemetry';

  @override
  String get freeformEntry => 'Freeform meal entry';

  @override
  String wordCountLabel(String count) {
    return '$count words';
  }

  @override
  String get liveParser => 'Live parser';

  @override
  String get clearText => 'Clear';

  @override
  String get quickMicroAdd => 'Quick micro-add';

  @override
  String get frequentlyLogged => 'Frequently logged';

  @override
  String get recentLogHistory => 'Recent log history';

  @override
  String get yesterdayLabel => 'Yesterday';

  @override
  String get nleTitle => 'Natural language engine active';

  @override
  String get nleBody =>
      'Parses complex weights, preparation styles, restaurant brands & estimated portion volumes automatically into precise macros.';

  @override
  String get readyToListen => 'Ready to listen';

  @override
  String get slotActive => 'Active';

  @override
  String get featMacroTitle => 'Macro extraction';

  @override
  String get featMacroSub => 'Real-time';

  @override
  String get featPortionTitle => 'Auto-portion';

  @override
  String get featPortionSub => 'Contextual';

  @override
  String get featTypingTitle => 'Zero typing';

  @override
  String get featTypingSub => 'Hands-free';

  @override
  String get opticsActive => 'Optics • active';

  @override
  String loggingToMeal(String meal) {
    return 'Logging to $meal';
  }

  @override
  String get alignBarcodeHint =>
      'Align barcode within the frame to scan automatically';

  @override
  String get readyToScan => 'Ready to scan';

  @override
  String get waterGoalEdit => 'Daily water goal';

  @override
  String get waterQuickLog => 'Quick log';
}
