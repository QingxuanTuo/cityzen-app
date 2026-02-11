import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleService extends ChangeNotifier {
  static final LocaleService _instance = LocaleService._internal();
  factory LocaleService() => _instance;
  LocaleService._internal();

  static const _kLocaleCode = 'app_locale_code';

  Locale _locale = const Locale('en');
  Locale get locale => _locale;

  Future<void> init() async {
    final sp = await SharedPreferences.getInstance();
    final code = sp.getString(_kLocaleCode);
    if (code != null && code.isNotEmpty) {
      _locale = Locale(code);
    }
  }

  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kLocaleCode, locale.languageCode);
  }
}
