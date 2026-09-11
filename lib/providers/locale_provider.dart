import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('en');

  Locale get locale => _locale;
  bool get isArabic => _locale.languageCode == 'ar';

  LocaleProvider() {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('locale');
    if (saved != null) {
      // User explicitly picked a language (toggle) — respect it.
      _locale = Locale(saved);
    } else {
      // First launch: follow the device language. The app ships en/ar only,
      // so anything else falls back to English.
      final device = WidgetsBinding.instance.platformDispatcher.locale;
      _locale = Locale(device.languageCode == 'ar' ? 'ar' : 'en');
    }
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', locale.languageCode);
    notifyListeners();
  }

  Future<void> toggle() async {
    await setLocale(isArabic ? const Locale('en') : const Locale('ar'));
  }
}
