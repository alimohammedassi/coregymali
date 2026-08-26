// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'كور جيم';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navNutrition => 'التغذية';

  @override
  String get navWorkout => 'التمرين';

  @override
  String get navProfile => 'الملف الشخصي';

  @override
  String get navMessages => 'الرسائل';

  @override
  String get navCoaches => 'المدربون';

  @override
  String get navDashboard => 'لوحة التحكم';

  @override
  String get dashboardOverview => 'نظرة عامة على لوحة التحكم';

  @override
  String get goodMorning => 'صباح الخير';

  @override
  String get goodAfternoon => 'مساء الخير';

  @override
  String get goodEvening => 'مساء النور';

  @override
  String get readyConquer => 'جاهز لتحقيق أهدافك الرياضية اليوم؟';

  @override
  String get calorieGoalReached => 'تم الوصول لهدف السعرات! أداء مذهل! 🔥';

  @override
  String calorieProgressMsg(int pct) {
    return 'أنجزت $pct٪ من هدف الطاقة اليومي';
  }

  @override
  String daysStreak(int count) {
    return '$count أيام';
  }

  @override
  String get dailyMetrics => 'مؤشرات اليوم';

  @override
  String get details => 'التفاصيل';

  @override
  String get todayCalories => 'سعرات اليوم';

  @override
  String get caloriesRemaining => 'متبقي';

  @override
  String get caloriesOver => 'فائض';

  @override
  String get kcalLeft => 'سعرة متبقية';

  @override
  String get kcalOver => 'سعرة فائضة';

  @override
  String get kcal => 'سعرة';

  @override
  String get eaten => 'المستهلك';

  @override
  String get burned => 'المحروق';

  @override
  String get protein => 'البروتين';

  @override
  String get carbs => 'الكربوهيدرات';

  @override
  String get fat => 'الدهون';

  @override
  String get quickAddWater => '+٢٥٠ مل';

  @override
  String get quickWorkout => 'تمرين';

  @override
  String get setGoalsTitle => 'تحديد أهدافك الرياضية';

  @override
  String get setGoalsSubtitle => 'خصص السعرات والماكروز لمتابعة أدق';

  @override
  String get moodSectionTitle => 'اختار مزاجك';

  @override
  String get moodTired => 'تعبان';

  @override
  String get moodLight => 'خفيف';

  @override
  String get moodMedium => 'متوسط';

  @override
  String get moodActive => 'نشيط';

  @override
  String get moodFull => 'فل باور';

  @override
  String get muscleGroupsTitle => 'مجموعات العضلات';

  @override
  String get muscleChest => 'الصدر';

  @override
  String get muscleArms => 'الذراعين';

  @override
  String get muscleLegs => 'الأرجل';

  @override
  String get muscleCore => 'الكور';

  @override
  String get aiWorkoutCta => 'ولّد تمرينك بالذكاء الاصطناعي';

  @override
  String get aiWorkoutSub => 'Smart Trainer — ٤٥ دقيقة';

  @override
  String caloriesOf(int goal) {
    return 'من $goal';
  }

  @override
  String caloriesRemainingMsg(int remaining) {
    return 'باقي $remaining سعرة للهدف';
  }

  @override
  String caloriesOverMsg(int over) {
    return 'تجاوزت الهدف بـ $over سعرة';
  }

  @override
  String get addMeal => '+ تسجيل وجبة';

  @override
  String get scanAi => 'مسح ذكي';

  @override
  String get voiceLog => 'صوتي';

  @override
  String get barcodeScan => 'باركود';

  @override
  String get quickText => 'نصي';

  @override
  String get dailyQuests => 'مهام وتحديات اليوم';

  @override
  String get hydrationHero => 'بطل الترطيب';

  @override
  String get proteinChampion => 'بطل البروتين';

  @override
  String get streakMaster => 'سيد الاستمرارية';

  @override
  String xpEarned(int count) {
    return '+$count نقطة';
  }

  @override
  String levelLabel(int lvl) {
    return 'مستوى $lvl';
  }

  @override
  String get todayMeals => 'وجبات اليوم';

  @override
  String get todaysFueling => 'وجبات وتغذية اليوم';

  @override
  String get addFood => '+ إضافة طعام';

  @override
  String get noMealsYet => 'لم تسجّل أي وجبة بعد';

  @override
  String get logFirstMeal => 'سجّل أول وجبة لك اليوم';

  @override
  String get logMeal => 'تسجيل وجبة';

  @override
  String get breakfast => 'الإفطار';

  @override
  String get lunch => 'الغداء';

  @override
  String get dinner => 'العشاء';

  @override
  String get snack => 'سناك';

  @override
  String get notLogged => 'لم تُسجَّل';

  @override
  String items(int count) {
    return '$count عناصر';
  }

  @override
  String get yourProgram => 'برنامجك التدريبي';

  @override
  String get activeProgram => 'البرنامج النشط';

  @override
  String get activeTrainingProgram => 'البرنامج التدريبي النشط';

  @override
  String get noActiveProgram => 'لا يوجد برنامج نشط';

  @override
  String get browsePrograms => 'تصفّح البرامج ←';

  @override
  String get startTodaysWorkout => 'ابدأ تمرين اليوم';

  @override
  String get week => 'الأسبوع';

  @override
  String get ofWord => 'من';

  @override
  String weekOfTotal(int current, int total) {
    return 'الأسبوع $current من $total';
  }

  @override
  String percentComplete(int pct) {
    return 'مكتمل بنسبة $pct٪';
  }

  @override
  String get beginner => 'مبتدئ';

  @override
  String get intermediate => 'متوسط';

  @override
  String get advanced => 'متقدم';

  @override
  String get lastWorkout => 'آخر تمرين';

  @override
  String get lastWorkoutUpper => 'آخر تمرين';

  @override
  String get noWorkoutsYet => 'لم تسجّل أي تمرين بعد';

  @override
  String get logFirstWorkout => 'سجّل أول تمرين ←';

  @override
  String get history => 'السجل';

  @override
  String get min => 'دقيقة';

  @override
  String get kgVolume => 'كجم حجم';

  @override
  String get water => 'الماء';

  @override
  String get glasses => 'أكواب';

  @override
  String get ofGlasses => 'من ٨ أكواب';

  @override
  String get ofGlassesGoal => 'من هدف ٨';

  @override
  String get steps => 'الخطوات';

  @override
  String get ofSteps => 'من ١٠٬٠٠٠ خطوة';

  @override
  String ofStepsGoal(int pct) {
    return '$pct٪ من ١٠ آلاف';
  }

  @override
  String get kcalBurned => 'سعرة محروقة';

  @override
  String get burnedToday => 'محروقة اليوم';

  @override
  String get updateSteps => 'تحديث الخطوات';

  @override
  String get cancel => 'إلغاء';

  @override
  String get save => 'حفظ';

  @override
  String get coachBannerTitle => 'ارتقِ بمستواك مع مدرب محترف';

  @override
  String get coachBannerSubtitle => 'مدربون معتمدون · برامج تدريب وتغذية مخصصة';

  @override
  String get completeProfile => 'أكمل ملفك الشخصي لعرض أهداف مخصصة.';

  @override
  String get fix => 'إصلاح ←';

  @override
  String get nutritionTitle => 'التغذية';

  @override
  String get today => 'اليوم';

  @override
  String get historyTab => 'السجل';

  @override
  String get caloriesToday => 'سعرات اليوم';

  @override
  String get caloriesConsumed => 'سعرة مستهلكة';

  @override
  String get searchFood => 'البحث عن طعام';

  @override
  String get searchHint => 'ابحث بالعربي أو الإنجليزي...';

  @override
  String get allCategories => 'الكل';

  @override
  String get logFood => 'تسجيل الطعام';

  @override
  String get quantity => 'الكمية';

  @override
  String get grams => 'جرام';

  @override
  String get mealType => 'الوجبة';

  @override
  String get noFoodFound => 'ابحث عن طعام';

  @override
  String get last7Days => 'السعرات — آخر ٧ أيام';

  @override
  String get dailyLogs => 'سجلات يومية';

  @override
  String get goalMet => 'تحقّق الهدف';

  @override
  String get underGoal => 'أقل من الهدف';

  @override
  String get noHistory => 'لا يوجد سجل بعد';

  @override
  String get startLogging => 'ابدأ تسجيل وجباتك لعرض تقدمك';

  @override
  String get workoutTitle => 'التمرين';

  @override
  String get myProgram => 'برنامجي';

  @override
  String get programs => 'البرامج';

  @override
  String get logWorkout => 'سجّل تمرين';

  @override
  String get chooseMuscleGroup => 'اختر المجموعة العضلية';

  @override
  String get sessionName => 'اسم الجلسة';

  @override
  String get startWorkout => 'ابدأ التمرين';

  @override
  String get chest => 'صدر';

  @override
  String get back => 'ظهر';

  @override
  String get shoulders => 'أكتاف';

  @override
  String get arms => 'أذرع';

  @override
  String get legs => 'أرجل';

  @override
  String get core => 'عضلات البطن';

  @override
  String get fullBody => 'كامل الجسم';

  @override
  String get activeWorkout => 'التمرين الحالي';

  @override
  String get finish => 'إنهاء';

  @override
  String get addExercise => '+ إضافة تمرين';

  @override
  String get addSet => '+ إضافة مجموعة';

  @override
  String get set => 'مجموعة';

  @override
  String get kg => 'كجم';

  @override
  String get reps => 'تكرار';

  @override
  String lastBest(double weight, int reps) {
    return 'الأفضل: $weightكجم × $reps تكرار';
  }

  @override
  String get warmup => 'إحماء';

  @override
  String get restTimer => 'وقت الراحة';

  @override
  String get skipRest => 'تخطّي';

  @override
  String get restComplete => 'انتهت الراحة!';

  @override
  String get workoutSummary => 'ملخص التمرين';

  @override
  String get totalVolume => 'إجمالي الحجم';

  @override
  String get totalSets => 'إجمالي المجموعات';

  @override
  String get exercises => 'تمارين';

  @override
  String get duration => 'المدة';

  @override
  String get saveWorkout => 'حفظ التمرين';

  @override
  String get discard => 'تجاهل';

  @override
  String get personalRecord => '🏆 رقم قياسي!';

  @override
  String get searchExercise => 'البحث عن تمرين...';

  @override
  String get profileTitle => 'الملف الشخصي';

  @override
  String get operativeData => 'بياناتي';

  @override
  String get dailyTargets => 'الأهداف اليومية';

  @override
  String get thisMonth => 'هذا الشهر';

  @override
  String get rmProgress => 'تقدم الـ 1RM';

  @override
  String get totalWorkouts => 'إجمالي\nالتمارين';

  @override
  String get thisMonthWorkouts => 'هذا\nالشهر';

  @override
  String get kcalLogged => 'سعرة\nمسجّلة';

  @override
  String get activeProgram2 => 'البرنامج النشط';

  @override
  String get age => 'العمر';

  @override
  String get weight => 'الوزن';

  @override
  String get height => 'الطول';

  @override
  String get goal => 'الهدف';

  @override
  String get calorieGoal => 'السعرات';

  @override
  String get proteinGoal => 'البروتين';

  @override
  String get weeklyWorkouts => 'تمارين أسبوعية';

  @override
  String get workoutsLabel => 'تمارين';

  @override
  String get caloriesLabel => 'سعرات';

  @override
  String get estimatedOneRM => 'تقدير الـ 1RM عبر الزمن';

  @override
  String get editGoals => 'تعديل الأهداف';

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String get editGoalsTitle => 'تعديل الأهداف';

  @override
  String get dailyCalories => 'السعرات اليومية';

  @override
  String get dailyProtein => 'البروتين اليومي';

  @override
  String get signOutConfirm => 'هل أنت متأكد من تسجيل الخروج؟';

  @override
  String get signOutTitle => 'تسجيل الخروج';

  @override
  String get weeklyWorkoutsLabel => 'التمارين الأسبوعية';

  @override
  String get loginTitle => 'مرحباً';

  @override
  String get loginSubtitle => 'بعودتك';

  @override
  String get loginDesc => 'أدخل بياناتك للوصول إلى حسابك';

  @override
  String get operatorId => 'البريد الإلكتروني';

  @override
  String get encryptedKey => 'كلمة المرور';

  @override
  String get emailHint => 'user@coregym.app';

  @override
  String get passwordHint => '••••••••••••';

  @override
  String get forgotPassword => 'نسيت؟';

  @override
  String get initializeSession => 'تسجيل الدخول';

  @override
  String get externalAuth => 'أو تابع بـ';

  @override
  String get google => 'جوجل';

  @override
  String get apple => 'آبل';

  @override
  String get newOperative => 'مستخدم جديد؟  ';

  @override
  String get enrollNow => 'أنشئ حساباً';

  @override
  String get signupTitle => 'إنشاء';

  @override
  String get signupSubtitle => 'حساب جديد';

  @override
  String get signupDesc => 'سجّل بيانات حساب جديد';

  @override
  String get operativeName => 'الاسم الكامل';

  @override
  String get confirmKey => 'تأكيد كلمة المرور';

  @override
  String get createOperative => 'إنشاء الحساب';

  @override
  String get alreadyEnrolled => 'لديك حساب؟  ';

  @override
  String get signIn => 'تسجيل الدخول';

  @override
  String get agreeTerms => 'أوافق على ';

  @override
  String get termsConditions => 'الشروط والأحكام';

  @override
  String get and => ' و';

  @override
  String get privacyPolicy => 'سياسة الخصوصية';

  @override
  String get fullNameHint => 'الاسم الكامل';

  @override
  String get language => 'اللغة';

  @override
  String get arabic => 'العربية';

  @override
  String get english => 'English';

  @override
  String get changeLanguage => 'تغيير اللغة';

  @override
  String get weightLoss => 'خسارة الوزن';

  @override
  String get muscleGain => 'بناء العضلات';

  @override
  String get endurance => 'التحمل';

  @override
  String get flexibility => 'المرونة';

  @override
  String get generalFitness => 'اللياقة العامة';

  @override
  String get onboarding => 'الإعداد';

  @override
  String get next => 'التالي';

  @override
  String get back2 => 'رجوع';

  @override
  String get getStarted => 'ابدأ الآن';

  @override
  String get yourAge => 'عمرك';

  @override
  String get yourWeight => 'وزنك';

  @override
  String get yourHeight => 'طولك';

  @override
  String get yourGoal => 'هدفك';

  @override
  String get activityLevel => 'مستوى النشاط';

  @override
  String get targetWeight => 'الوزن المستهدف';

  @override
  String get workoutsPerWeek => 'تمارين في الأسبوع';

  @override
  String get sedentary => 'خامل';

  @override
  String get lightlyActive => 'نشاط خفيف';

  @override
  String get moderatelyActive => 'نشاط متوسط';

  @override
  String get veryActive => 'نشيط جداً';

  @override
  String get extraActive => 'نشاط مكثف';

  @override
  String get chatTitle => 'الرسائل';

  @override
  String get noConversations => 'لا توجد محادثات بعد';

  @override
  String get noConversationsHint => 'اشترك في مدرب لبدء المحادثة';

  @override
  String get typeMessage => 'اكتب رسالة...';

  @override
  String get sayHello => 'قل مرحباً! 👋';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get coach => 'المدرب';

  @override
  String get client => 'العميل';

  @override
  String get scanTitle => 'المسح الذكي للطعام';

  @override
  String get scanSubtitle => 'صوّر أكلك وسيبه علينا';

  @override
  String get scanSaveToMeal => 'هتحفظ الوجبة في';

  @override
  String get scanIdleHint =>
      'صورة واحدة تكفي — هنحدد الأصناف والوزن والسعرات تلقائيًا';

  @override
  String get scanCameraCta => 'صوّر الأكل';

  @override
  String get scanGalleryCta => 'اختر من المعرض';

  @override
  String get scanAnalyzingTitle => 'بحلل الصورة…';

  @override
  String get scanAnalyzingSubtitle => 'بنحدد الأصناف والوزن والماكروز';

  @override
  String get scanItemsHeader => 'الأصناف المكتشفة';

  @override
  String get scanConfidenceHigh => 'دقة عالية';

  @override
  String get scanConfidenceMedium => 'دقة متوسطة';

  @override
  String get scanConfidenceLow => 'دقة منخفضة';

  @override
  String scanLogToMeal(String meal) {
    return 'سجّل في $meal';
  }

  @override
  String get scanErrorTitle => 'عذرًا!';

  @override
  String get scanRetrySamePhoto => 'جرب تاني بنفس الصورة';

  @override
  String get scanNewPhoto => 'صورة جديدة';

  @override
  String get scanErrorNetwork =>
      'مفيش اتصال بالإنترنت، اتأكد من الشبكة وجرب تاني';

  @override
  String get scanErrorUnauthorized =>
      'لازم تسجل دخول الأول قبل ما تستخدم السكانر';

  @override
  String get scanErrorNotFood =>
      'مش شايف أكل واضح في الصورة، جرب صورة تانية من زاوية أحسن';

  @override
  String get scanErrorAnalysis => 'حصلت مشكلة في تحليل الصورة، جرب تاني';

  @override
  String get scanErrorPersist =>
      'الصورة اتحللت بس حصلت مشكلة في الحفظ، جرب تاني';

  @override
  String get scanErrorUnknown => 'حصلت مشكلة غير متوقعة، جرب تاني';

  @override
  String get voiceTitle => 'تسجيل الأكل بالصوت';

  @override
  String get voiceSubtitle => 'قول بس أكلت إيه وإحنا نعمل الباقي';

  @override
  String get voiceIdleHint =>
      'اوصف وجبتك في جملة واحدة — هنحول كلامك لنص ونحسب السعرات تلقائيًا';

  @override
  String get voiceRecordCta => 'ابدأ التسجيل';

  @override
  String get voiceStopCta => 'وقف وحلّل';

  @override
  String get voiceRecordingHint => 'بسمعك… دوس وقف لما تخلص توصيف الوجبة';

  @override
  String get voiceAnalyzingTitle => 'بحلل التسجيل…';

  @override
  String get voiceTranscriptLabel => 'إنت قلت';

  @override
  String get voiceRetrySameAudio => 'جرب تاني بنفس التسجيل';

  @override
  String get voiceNewRecording => 'تسجيل جديد';

  @override
  String get voiceErrorNetwork =>
      'مفيش اتصال بالإنترنت، اتأكد من الشبكة وجرب تاني';

  @override
  String get voiceErrorUnauthorized =>
      'لازم تسجل دخول الأول قبل ما تستخدم تسجيل الصوت';

  @override
  String get voiceErrorMicrophone =>
      'محتاجين إذن المايك، فعّله من الإعدادات وجرب تاني';

  @override
  String get voiceErrorNotFood =>
      'مسمعناش وصف أكل واضح في التسجيل، جرب توصف وجبتك تاني';

  @override
  String get voiceErrorAnalysis => 'حصلت مشكلة في فهم التسجيل، جرب تاني';

  @override
  String get voiceErrorPersist =>
      'التسجيل اتحلل بس حصلت مشكلة في الحفظ، جرب تاني';

  @override
  String get voiceErrorUnknown => 'حصلت مشكلة غير متوقعة، جرب تاني';

  @override
  String get textTitle => 'تسجيل الأكل بالنص';

  @override
  String get textSubtitle => 'اكتب أكلت إيه وإحنا نعمل الباقي';

  @override
  String get textInputHint => 'مثال: فطار 2 عيش وجبنة وشاي…';

  @override
  String get textAnalyzeCta => 'حلّل بالذكاء الاصطناعي';

  @override
  String get textAnalyzingTitle => 'بنحلل وجبتك…';

  @override
  String get textEmptyInput => 'اكتب أكلت إيه الأول وبعدين دوس تحليل';

  @override
  String get textWroteLabel => 'إنت كتبت';

  @override
  String get textErrorNetwork =>
      'مفيش اتصال بالإنترنت، اتأكد من الشبكة وجرب تاني';

  @override
  String get textErrorUnauthorized =>
      'لازم تسجل دخول الأول قبل ما تستخدم تسجيل النص';

  @override
  String get textErrorNotFood => 'ملقيناش أكل في النص ده، جرب توصف وجبتك تاني';

  @override
  String get textErrorAnalysis => 'حصلت مشكلة في فهم الوصف، جرب تاني';

  @override
  String get textErrorPersist =>
      'الوجبة اتحللت بس حصلت مشكلة في الحفظ، جرب تاني';

  @override
  String get textErrorUnknown => 'حصلت مشكلة غير متوقعة، جرب تاني';

  @override
  String get textEditDescription => 'عدّل الوصف';

  @override
  String get textNewDescription => 'وصف جديد';

  @override
  String get profileFirstRunNudge => 'سجّل أول تمرين لتبدأ في جمع الرانك!';

  @override
  String get dashboardEyebrow => 'لوحتي';

  @override
  String get dashboardSubscribers => 'المشتركون';

  @override
  String subscriberCount(int count) {
    return 'الإجمالي $count';
  }

  @override
  String get statActiveSubscribers => 'المشتركون\nالنشطون';

  @override
  String get statAvgRating => 'متوسط\nالتقييم';

  @override
  String get statMonthlyRevenue => 'الإيراد\nالشهري';

  @override
  String get statOpenSlots => 'الأماكن\nالمتاحة';

  @override
  String get filterAll => 'الكل';

  @override
  String get filterActive => 'نشط';

  @override
  String get filterPending => 'معلق';

  @override
  String get filterExpired => 'منتهي';

  @override
  String get noSubscribersYet => 'لا يوجد مشتركون بعد';

  @override
  String get completeProfileHint =>
      'أكمل ملفك كمدرب ليجدك العملاء ويشتركوا معك.';

  @override
  String get completeProfileCta => 'أكمل ملفك الشخصي';

  @override
  String failedToLoadStats(String error) {
    return 'فشل تحميل الإحصائيات: $error';
  }

  @override
  String daysLeft(int n) {
    return 'باقي $n أيام';
  }

  @override
  String daysRemaining(int n) {
    return 'متبقي $n يوم';
  }

  @override
  String get statusExpired => 'منتهي';

  @override
  String get statusPaused => 'متوقف مؤقتاً';

  @override
  String get statusCancelled => 'ملغي';

  @override
  String get planPhases => 'مراحل الخطة';

  @override
  String get paymentPaid => 'مدفوع';

  @override
  String get paymentUnpaid => 'غير مدفوع';

  @override
  String get paymentRefunded => 'مسترجع';

  @override
  String phaseWeek(int w) {
    return 'الأسبوع $w';
  }

  @override
  String get previousDay => 'اليوم السابق';

  @override
  String get nextDay => 'اليوم التالي';

  @override
  String get smartwatchSync => 'مزامنة الساعة الذكية';
}
