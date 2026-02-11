import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../models/health_zone.dart';
import '../models/safe_route.dart';

class DynamicHealthService {
  static DynamicHealthService? _instance;
  static DynamicHealthService get instance =>
      _instance ??= DynamicHealthService._();

  DynamicHealthService._();

  /// 根据 center 动态生成 5 个健康圈（park/residential/mixed/commercial/traffic）
  List<HealthZone> getHealthZones({
    required LatLng center,
    double? pm25,
    double? temperature,
    int? weatherCode,
  }) {
    final severity = _envSeverity(
      pm25: pm25,
      temperature: temperature,
      weatherCode: weatherCode,
    );

    final rnd = math.Random(_seedFromLatLng(center));

    HealthZone z({
      required String id,
      required String name,
      required LatLng c,
      required double radius,
      required int score,
      required HealthZoneType type,
      required String description,
      required List<String> bestTimes,
      List<String> recommendations = const [],
      List<String> warnings = const [],
    }) {
      final clampedScore = score.clamp(0, 100);
      return HealthZone(
        id: id,
        name: name,
        center: c,
        radius: radius,
        healthScore: clampedScore,
        type: type,
        description: description,
        bestTimes: bestTimes,
        recommendations: recommendations,
        warnings: warnings,
        airQualityData: const <String, dynamic>{'source': 'dynamic'},
      );
    }

    // 生成 5 个圈：分数会随 severity 变差而下降
    final zones = <HealthZone>[
      z(
        id: 'green_zone',
        name: 'Green Zone',
        c: _offset(center, rnd, 0.006, 0.006),
        radius: 900,
        score: (90 - severity * 20).round(),
        type: HealthZoneType.park,
        description: 'Best outdoor area near you. Prefer parks/green streets.',
        bestTimes: _bestTimes(severity, best: true),
        recommendations: const [
          'Great for jogging and walking',
          'Prefer green routes away from traffic',
        ],
      ),
      z(
        id: 'residential_zone',
        name: 'Residential Zone',
        c: _offset(center, rnd, 0.007, 0.007),
        radius: 800,
        score: (76 - severity * 24).round(),
        type: HealthZoneType.residential,
        description: 'Generally okay for light outdoor activities.',
        bestTimes: _bestTimes(severity),
        recommendations: const [
          'Light exercise recommended',
          'Avoid rush hours if possible',
        ],
      ),
      z(
        id: 'mixed_zone',
        name: 'Mixed Zone',
        c: _offset(center, rnd, 0.009, 0.009),
        radius: 1000,
        score: (64 - severity * 28).round(),
        type: HealthZoneType.mixed,
        description: 'Moderate exposure. Use caution during peak hours.',
        bestTimes: _bestTimes(severity),
        recommendations: const [
          'Short outdoor time is OK',
          'Choose side streets',
        ],
      ),
      z(
        id: 'commercial_zone',
        name: 'Busy Zone',
        c: _offset(center, rnd, 0.010, 0.010),
        radius: 750,
        score: (54 - severity * 30).round(),
        type: HealthZoneType.commercial,
        description: 'Crowded/busy area. Avoid intense exercise here.',
        bestTimes: _bestTimes(severity),
        recommendations: const [
          'Minimize outdoor exposure time',
          'Take breaks indoors',
        ],
        warnings: const ['Crowded area possible'],
      ),
      z(
        id: 'traffic_hotspot',
        name: 'Traffic Hotspot',
        c: _offset(center, rnd, 0.012, 0.012),
        radius: 850,
        score: (42 - severity * 32).round(),
        type: HealthZoneType.traffic,
        description: 'High traffic zone with higher exposure risk.',
        bestTimes: const ['22:00-06:00'],
        recommendations: const [
          'Prefer indoor routes',
          'Wear a mask if needed',
        ],
        warnings: const [
          'Higher pollution risk during rush hours',
          'Avoid intense exercise here',
        ],
      ),
    ];

    return zones;
  }

  /// Map 页 info panel 用的推荐（不依赖 SafeRoute）
  List<ActivityRecommendation> getCurrentRecommendations({
    required LatLng center,
    double? pm25,
    double? temperature,
    int? weatherCode,
  }) {
    final now = DateTime.now();
    final severity = _envSeverity(
      pm25: pm25,
      temperature: temperature,
      weatherCode: weatherCode,
    );

    final recs = <ActivityRecommendation>[];

    if (now.hour >= 6 && now.hour < 9) {
      recs.add(
        ActivityRecommendation(
          title: 'Morning Walk',
          description: 'Cool air + fewer crowds (usually best time).',
          icon: Icons.directions_walk,
          color: Colors.green,
          timeRange: '06:00-09:00',
          locations: const ['Near your location'],
          priority: 5,
        ),
      );
    }

    if (now.hour >= 17 && now.hour < 20) {
      recs.add(
        ActivityRecommendation(
          title: 'Evening Activity',
          description: 'Good for light exercise after work.',
          icon: Icons.directions_run,
          color: Colors.blue,
          timeRange: '17:00-20:00',
          locations: const ['Near your location'],
          priority: 4,
        ),
      );
    }

    if (pm25 != null) {
      if (pm25 < 15) {
        recs.add(
          ActivityRecommendation(
            title: 'Outdoor Exercise',
            description: 'Air looks good — suitable for outdoor activity.',
            icon: Icons.fitness_center,
            color: Colors.green,
            timeRange: 'All day',
            locations: const ['Parks / Green streets'],
            priority: 5,
          ),
        );
      } else if (pm25 >= 35) {
        recs.add(
          ActivityRecommendation(
            title: 'Prefer Indoor',
            description: 'PM2.5 is high — consider indoor alternatives.',
            icon: Icons.home,
            color: Colors.orange,
            timeRange: 'Until air improves',
            locations: const ['Indoor gym / Home'],
            priority: 4,
          ),
        );
      } else {
        recs.add(
          ActivityRecommendation(
            title: 'Outdoor with Caution',
            description: 'Avoid busy roads and rush hours.',
            icon: Icons.warning,
            color: Colors.amber,
            timeRange: 'Today',
            locations: const ['Side streets / Parks'],
            priority: 3,
          ),
        );
      }
    } else {
      // 没有 pm25 数据时，按 severity 给个通用建议
      recs.add(
        ActivityRecommendation(
          title: 'Check Data',
          description: severity > 0.6
              ? 'Consider indoor today.'
              : 'Outdoor is OK with caution.',
          icon: Icons.info_outline,
          color: Colors.grey,
          timeRange: 'Today',
          locations: const ['Home / Nearby'],
          priority: 2,
        ),
      );
    }

    recs.sort((a, b) => (b.priority).compareTo(a.priority));
    return recs.take(3).toList();
  }

  // ---------------- helpers ----------------

  double _envSeverity({double? pm25, double? temperature, int? weatherCode}) {
    // 0~1：越大越差
    double s = 0.25;

    if (pm25 != null) {
      s += (pm25 / 80.0).clamp(0.0, 1.0) * 0.6;
    }

    if (weatherCode != null) {
      final isRain =
          (weatherCode >= 51 && weatherCode <= 67) ||
          (weatherCode >= 80 && weatherCode <= 82);
      final isFog = weatherCode == 45 || weatherCode == 48;
      final isSnow = (weatherCode >= 71 && weatherCode <= 77);
      if (isFog) s += 0.15;
      if (isRain) s += 0.10;
      if (isSnow) s += 0.10;
    }

    if (temperature != null) {
      if (temperature <= 0) s += 0.08;
      if (temperature >= 33) s += 0.08;
    }

    return s.clamp(0.0, 1.0);
  }

  int _seedFromLatLng(LatLng c) {
    final a = (c.latitude * 1000).round();
    final b = (c.longitude * 1000).round();
    return a * 100000 + b;
  }

  LatLng _offset(LatLng center, math.Random rnd, double dLat, double dLon) {
    final lat = center.latitude + (rnd.nextDouble() * 2 - 1) * dLat;
    final lon = center.longitude + (rnd.nextDouble() * 2 - 1) * dLon;
    return LatLng(lat, lon);
  }

  List<String> _bestTimes(double severity, {bool best = false}) {
    if (best) {
      if (severity < 0.35) return const ['06:00-10:00', '17:00-20:00'];
      return const ['06:00-09:00'];
    }
    if (severity < 0.35) return const ['07:00-10:00', '16:00-19:00'];
    if (severity < 0.65) return const ['07:00-09:00', '19:00-21:00'];
    return const ['06:00-08:00'];
  }
}
