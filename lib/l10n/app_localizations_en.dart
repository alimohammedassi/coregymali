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
}
