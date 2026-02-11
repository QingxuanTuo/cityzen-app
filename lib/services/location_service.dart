import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class AppLocation extends ChangeNotifier {
  static final AppLocation instance = AppLocation._();
  AppLocation._();

  Position? _position;
  Placemark? _placemark;
  String? _error;

  Position? get position => _position;
  Placemark? get placemark => _placemark;
  String? get error => _error;

  double? get lat => _position?.latitude;
  double? get lon => _position?.longitude;

  String get displayName {
    final p = _placemark;
    if (p == null) return 'Locating...';
    final city = (p.locality?.trim().isNotEmpty ?? false)
        ? p.locality!.trim()
        : null;
    final admin = (p.administrativeArea?.trim().isNotEmpty ?? false)
        ? p.administrativeArea!.trim()
        : null;
    final country = (p.country?.trim().isNotEmpty ?? false)
        ? p.country!.trim()
        : null;

    // 优先 city，其次 admin
    final left = city ?? admin ?? 'Unknown';
    return country == null ? left : '$left, $country';
  }

  Future<void> initAndFetch() async {
    _error = null;
    notifyListeners();

    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      _error = 'Location service disabled';
      notifyListeners();
      return;
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      _error = 'Location permission denied';
      notifyListeners();
      return;
    }

    _position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 10),
    );

    // reverse geocoding：lat/lon -> 城市名
    final list = await placemarkFromCoordinates(
      _position!.latitude,
      _position!.longitude,
    );
    if (list.isNotEmpty) _placemark = list.first;

    notifyListeners();
  }
}
