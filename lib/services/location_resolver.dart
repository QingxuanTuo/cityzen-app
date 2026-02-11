import 'package:latlong2/latlong.dart';
import 'location_preferences.dart';
import '../data/cities.dart';
import 'location_service.dart'; // 这里就是你的 AppLocation 文件路径（如果不是这个名字，换成你真实文件名）

class LocationResolver {
  static LatLng resolveLatLng() {
    final prefs = LocationPreferences.instance;
    final loc = AppLocation.instance;

    final useGps =
        prefs.useCurrentLocation && loc.lat != null && loc.lon != null;

    if (useGps) {
      return LatLng(loc.lat!, loc.lon!);
    }

    final fallbackCity = supportedCities.firstWhere(
      (c) => c.key == prefs.cityKey,
      orElse: () => supportedCities.first,
    );

    return LatLng(fallbackCity.lat, fallbackCity.lon);
  }

  static String resolveCityName() {
    final prefs = LocationPreferences.instance;
    final loc = AppLocation.instance;

    final useGps =
        prefs.useCurrentLocation && loc.lat != null && loc.lon != null;

    if (useGps) return loc.displayName;

    final fallbackCity = supportedCities.firstWhere(
      (c) => c.key == prefs.cityKey,
      orElse: () => supportedCities.first,
    );

    return fallbackCity.name;
  }
}
