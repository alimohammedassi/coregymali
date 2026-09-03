import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase/supabase_config.dart';
import 'theme/app_colors.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'splashScreen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'providers/locale_provider.dart';
import 'providers/profile_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'chat/presentation/providers/chat_providers.dart';
import 'chat/data/repositories/notification_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  await initializeDateFormatting('ar', null);

  runApp(
    ProviderScope(
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ChangeNotifierProvider(create: (_) => ProfileProvider()),
          ChangeNotifierProvider(create: (_) => ChatRepoProvider()),
          ChangeNotifierProxyProvider<ChatRepoProvider, ConversationsNotifier>(
            create: (context) => ConversationsNotifier(context.read<ChatRepoProvider>().repo),
            update: (context, chatRepo, previous) => previous ?? ConversationsNotifier(chatRepo.repo),
          ),
          ChangeNotifierProxyProvider<ChatRepoProvider, UnreadCountNotifier>(
            create: (context) => UnreadCountNotifier(context.read<ChatRepoProvider>().repo),
            update: (context, chatRepo, previous) => previous ?? UnreadCountNotifier(chatRepo.repo),
          ),
          ChangeNotifierProvider(
            create: (_) => NotificationNotifier(
              NotificationRepository(Supabase.instance.client),
            ),
          ),
        ],
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localeProvider = context.watch<LocaleProvider>();
    return MaterialApp(
      locale: localeProvider.locale,
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return Directionality(
          textDirection: localeProvider.isArabic
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: child!,
        );
      },
      title: 'Core Gym',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryFixed,
          brightness: Brightness.dark,
          primary: AppColors.primaryFixed,
          onPrimary: AppColors.onPrimary,
          secondary: AppColors.secondary,
          onSecondary: AppColors.onPrimary,
          error: AppColors.error,
          surface: AppColors.surface,
          onSurface: AppColors.onSurface,
          surfaceContainerHighest: AppColors.surfaceContainerHighest,
          outlineVariant: AppColors.outlineVariant,
        ),
        splashColor: AppColors.primaryGlow,
        highlightColor: AppColors.glass1,
        // ── Component defaults — one language app-wide (Kinetic Obsidian) ──
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.onSurface,
          elevation: 0,
          centerTitle: false,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryFixed,
            foregroundColor: AppColors.onPrimary,
            minimumSize: const Size(64, 48), // ≥44px touch target
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
            textStyle: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryFixed,
            foregroundColor: AppColors.onPrimary,
            minimumSize: const Size(64, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.onSurface,
            side: const BorderSide(color: AppColors.outlineVariant),
            minimumSize: const Size(64, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          fillColor: AppColors.surfaceContainerHigh,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.primaryFixed, width: 1.5),
          ),
          hintStyle: const TextStyle(color: AppColors.textMuted),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.surfaceContainer,
          modalBarrierColor: Color(0xD9000000),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.surfaceContainerHighest,
          contentTextStyle: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.onSurface,
          ),
          actionTextColor: AppColors.primaryFixed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors.primaryFixed,
          linearTrackColor: AppColors.surfaceContainerHighest,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.surfaceContainerHigh,
          selectedColor: AppColors.lightGreen,
          labelStyle: const TextStyle(color: AppColors.onSurface),
          side: const BorderSide(color: AppColors.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        tabBarTheme: const TabBarThemeData(
          labelColor: AppColors.primaryFixed,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primaryFixed,
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.borderSubtle,
          thickness: 1,
        ),
        textTheme: localeProvider.isArabic
            ? GoogleFonts.cairoTextTheme(ThemeData.dark().textTheme)
            : GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}