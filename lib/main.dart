import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase/supabase_config.dart';
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
        scaffoldBackgroundColor: const Color(0xFFF7F9F8),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF18A957),
          primary: const Color(0xFF18A957),
          surface: const Color(0xFFFFFFFF),
        ),
        textTheme: localeProvider.isArabic
            ? GoogleFonts.cairoTextTheme()
            : GoogleFonts.poppinsTextTheme(),
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}