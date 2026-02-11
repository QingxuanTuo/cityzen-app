import 'package:shared_preferences/shared_preferences.dart';

class LocationPreferences {
  static const _kUseCurrent = 'loc_use_current';
  static const _kCityKey = 'loc_city_key';

  static final LocationPreferences instance = LocationPreferences._();
  LocationPreferences._();

  bool useCurrentLocation = true;
  String cityKey = 'milan';

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    useCurrentLocation = sp.getBool(_kUseCurrent) ?? true;
    cityKey = sp.getString(_kCityKey) ?? 'milan';
  }

  Future<void> setUseCurrent(bool v) async {
    useCurrentLocation = v;
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kUseCurrent, v);
  }

  Future<void> setCityKey(String key) async {
    cityKey = key;
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kCityKey, key);
  }
}
