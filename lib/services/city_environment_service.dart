import 'dart:convert';
import 'package:http/http.dart' as http;

class CityEnvironmentSnapshot {
  final double? pm25;
  final double? pm10;
  final double? temperatureC;
  final double? humidity;
  final double? windKmh;
  final DateTime fetchedAt;

  const CityEnvironmentSnapshot({
    required this.pm25,
    required this.pm10,
    required this.temperatureC,
    required this.humidity,
    required this.windKmh,
    required this.fetchedAt,
  });
}

class CityEnvironmentService {
  static final CityEnvironmentService instance = CityEnvironmentService._();
  CityEnvironmentService._();

  Future<CityEnvironmentSnapshot> fetch({
    required double lat,
    required double lon,
  }) async {
    final now = DateTime.now();

    final aqUri = Uri.parse(
      'https://air-quality-api.open-meteo.com/v1/air-quality'
      '?latitude=$lat&longitude=$lon'
      '&hourly=pm10,pm2_5'
      '&timezone=auto',
    );

    final weatherUri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$lat&longitude=$lon'
      '&current=temperature_2m,wind_speed_10m,relative_humidity_2m'
      '&timezone=auto',
    );

    final responses = await Future.wait([
      http.get(aqUri).timeout(const Duration(seconds: 12)),
      http.get(weatherUri).timeout(const Duration(seconds: 12)),
    ]);

    final aqResp = responses[0];
    final wResp = responses[1];

    if (aqResp.statusCode != 200) {
      throw Exception('AirQuality HTTP ${aqResp.statusCode}');
    }
    if (wResp.statusCode != 200) {
      throw Exception('Weather HTTP ${wResp.statusCode}');
    }

    final aqJson = jsonDecode(aqResp.body) as Map<String, dynamic>;
    final wJson = jsonDecode(wResp.body) as Map<String, dynamic>;

    final hourly = aqJson['hourly'] as Map<String, dynamic>?;
    final times = (hourly?['time'] as List?) ?? const [];
    final pm25Raw = (hourly?['pm2_5'] as List?) ?? const [];
    final pm10Raw = (hourly?['pm10'] as List?) ?? const [];

    DateTime? parseTime(dynamic t) =>
        (t is String) ? DateTime.tryParse(t) : null;

    int nearestHourIndex = 0;
    Duration best = const Duration(days: 9999);
    for (int i = 0; i < times.length; i++) {
      final dt = parseTime(times[i]);
      if (dt == null) continue;
      final d = (dt.difference(now)).abs();
      if (d < best) {
        best = d;
        nearestHourIndex = i;
      }
    }

    double? pickNumAt(List list, int idx) {
      if (idx < 0 || idx >= list.length) return null;
      final v = list[idx];
      return v is num ? v.toDouble() : null;
    }

    final pm25 = pickNumAt(pm25Raw, nearestHourIndex);
    final pm10 = pickNumAt(pm10Raw, nearestHourIndex);

    final current = wJson['current'] as Map<String, dynamic>?;
    final temperature = (current?['temperature_2m'] as num?)?.toDouble();
    final humidity = (current?['relative_humidity_2m'] as num?)?.toDouble();
    final wind = (current?['wind_speed_10m'] as num?)?.toDouble();

    return CityEnvironmentSnapshot(
      pm25: pm25,
      pm10: pm10,
      temperatureC: temperature,
      humidity: humidity,
      windKmh: wind,
      fetchedAt: DateTime.now(),
    );
  }
}
