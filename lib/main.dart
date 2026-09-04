import 'dart:async';
import 'package:flutter/foundation.dart';
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
import 'providers/theme_mode_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'chat/presentation/providers/chat_providers.dart';
import 'chat/data/repositories/notification_repository.dart';
import 'services/notification_service.dart';
import 'services/water_reminder_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Release builds stay quiet: debug logs (user IDs, errors) must not reach
  // the device log store in production.
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  await initializeDateFormatting('ar', null);

  await NotificationService.instance.init();
  unawaited(WaterReminderService.instance.refresh());

  runApp(
    ProviderScope(
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ChangeNotifierProvider(create: (_) => ThemeModeProvider()),
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
    final themeProvider = context.watch<ThemeModeProvider>();
    return MaterialApp(
      locale: localeProvider.locale,
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: _buildTheme(Brightness.light, localeProvider.isArabic),
      darkTheme: _buildTheme(Brightness.dark, localeProvider.isArabic),
      themeMode: themeProvider.mode,
      builder: (context, child) {
        // Re-resolve the static AppColors palette for the brightness that is
        // about to paint, then key the tree on it so every widget re-reads the
        // tokens when the mode flips (statics aren't inherited).
        final Brightness effective = switch (themeProvider.mode) {
          ThemeMode.light => Brightness.light,
          ThemeMode.dark => Brightness.dark,
          ThemeMode.system =>
            MediaQuery.maybePlatformBrightnessOf(context) ??
                View.of(context).platformDispatcher.platformBrightness,
        };
        AppColors.apply(effective);
        return Directionality(
          textDirection: localeProvider.isArabic
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: KeyedSubtree(
            key: ValueKey<Brightness>(effective),
            child: child!,
          ),
        );
      },
      title: 'Core Gym',
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }

  ThemeData _buildTheme(Brightness brightness, bool isArabic) {
    final base = brightness == Brightness.light
        ? ThemeData.light()
        : ThemeData.dark();
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryFixed,
        brightness: brightness,
        primary: brightness == Brightness.light
            ? AppColors.primary
            : AppColors.primaryFixed,
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
          side: BorderSide(color: AppColors.outlineVariant),
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
          borderSide: BorderSide(color: AppColors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.primaryFixed, width: 1.5),
        ),
        hintStyle: TextStyle(color: AppColors.textMuted),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surfaceContainer,
        modalBarrierColor: brightness == Brightness.light
            ? const Color(0x66000000)
            : const Color(0xD9000000),
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
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.primaryFixed,
        linearTrackColor: AppColors.surfaceContainerHighest,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceContainerHigh,
        selectedColor: AppColors.lightGreen,
        labelStyle: TextStyle(color: AppColors.onSurface),
        side: BorderSide(color: AppColors.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primaryFixed,
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.borderSubtle,
        thickness: 1,
      ),
      textTheme: isArabic
          ? GoogleFonts.cairoTextTheme(base.textTheme)
          : GoogleFonts.poppinsTextTheme(base.textTheme),
    );
  }
}