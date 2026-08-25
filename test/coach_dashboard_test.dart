import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:core/features/coach/presentation/providers/coach_dashboard_providers.dart';
import 'package:core/features/coach/presentation/screens/coach_dashboard_screen.dart';
import 'package:core/l10n/app_localizations.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://mkrjvrnysuvtokqkyoll.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1rcmp2cm55c3V2dG9rcWt5b2xsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQxNDExMTgsImV4cCI6MjA4OTcxNzExOH0.Nf1xdRt2W1Ped0gulhdId2iAFC0KEp36-JD_4ey9dzg',
    );
  });

  // Network calls inside the notifiers will fail in the test environment —
  // that's expected and must surface as the dashboard's error/empty states,
  // never as a build-phase exception (red screen).
  testWidgets('CoachDashboardScreen builds without throwing',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      CoachDashboardProviders.provideAll(
        child: MaterialApp(
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          locale: const Locale('en'),
          home: const CoachDashboardScreen(),
        ),
      ),
    );

    // Let post-frame fetches fire; notifier errors are caught internally.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
  });
}
