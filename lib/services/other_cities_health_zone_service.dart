import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../models/health_zone.dart';
import 'city_environment_service.dart';
import 'osm_poi_service.dart';

class OtherCitiesHealthZoneService {
  static final OtherCitiesHealthZoneService instance =
      OtherCitiesHealthZoneService._();
  OtherCitiesHealthZoneService._();

  Future<List<HealthZone>> buildZones({
    required String cityKey,
    required String cityName,
    required LatLng center,
  }) async {
    final results = await Future.wait<dynamic>([
      CityEnvironmentService.instance.fetch(
        lat: center.latitude,
        lon: center.longitude,
      ),
      OsmPoiService.instance.fetchAround(
        cacheKey: 'poi_$cityKey',
        center: center,
        radiusMeters: 2200, // 稍微大一点，给分散算法更多候选点
      ),
    ]);

    final dynamic snap = results[0];
    final dynamic poi = results[1];

    final double? pm25 = snap.pm25 as double?;
    final double? pm10 = snap.pm10 as double?;

    // -----------------------
    // 1) 取 POI 列表（容错）
    // -----------------------
    List<LatLng> safeList(String field) {
      try {
        final dynamic v = poi;
        final dynamic list = switch (field) {
          'parks' => v.parks,
          'residential' => v.residential,
          'mixed' => v.mixed,
          'commercial' => v.commercial,
          'traffic' => v.traffic,
          'industrial' => v.industrial,
          _ => null,
        };
        if (list is List) return list.cast<LatLng>();
      } catch (_) {}
      return const <LatLng>[];
    }

    final parksSrc = safeList('parks');
    final residentialSrc = safeList('residential');
    final mixedSrc = safeList('mixed');
    final commercialSrc = safeList('commercial');
    final trafficSrc = safeList('traffic');
    final industrialSrc = safeList('industrial');

    // mixed 的候选池：城市里经常 mixed 不够，合并一些候选点当备胎
    final mixedPool = <LatLng>[
      ...mixedSrc,
      ...residentialSrc,
      ...commercialSrc,
    ];

    // ---------------------------------------
    // 2) 全局避让：跨类型也要分散
    // ---------------------------------------
    final globalPicked = <LatLng>[];

    // ⚠️ minKm 是“中心点最小间距”
    // 因为圈半径普遍 650~900m，要像米兰那样“散开”，minKm 必须更大
    final parks = pickSpreadGlobal(
      center: center,
      candidates: parksSrc,
      count: 2,
      seed: cityKey.hashCode + 11,
      globalPicked: globalPicked,
      minKm: 1.25, // park 半径大
    );

    final residential = pickSpreadGlobal(
      center: center,
      candidates: residentialSrc,
      count: 2,
      seed: cityKey.hashCode + 22,
      globalPicked: globalPicked,
      minKm: 1.05,
    );

    final mixed = pickSpreadGlobal(
      center: center,
      candidates: mixedPool,
      count: 2,
      seed: cityKey.hashCode + 33,
      globalPicked: globalPicked,
      minKm: 1.10,
    );

    final commercial = pickSpreadGlobal(
      center: center,
      candidates: commercialSrc,
      count: 1,
      seed: cityKey.hashCode + 44,
      globalPicked: globalPicked,
      minKm: 1.30,
    );

    final traffic = pickSpreadGlobal(
      center: center,
      candidates: trafficSrc,
      count: 1,
      seed: cityKey.hashCode + 55,
      globalPicked: globalPicked,
      minKm: 1.35,
    );

    final industrial = pickSpreadGlobal(
      center: center,
      candidates: industrialSrc,
      count: 1,
      seed: cityKey.hashCode + 66,
      globalPicked: globalPicked,
      minKm: 1.35,
    );

    // ---------------------------------------
    // 3) 分数/半径：对齐你的图例（和米兰一致）
    //    目标：颜色区间和图例一致，不再“颜色乱”
    // ---------------------------------------
    int scoreForType(HealthZoneType type, math.Random rnd, double? pm25) {
      int airPenalty;
      final v = pm25 ?? 20.0;
      if (v <= 15) {
        airPenalty = 0;
      } else if (v <= 35) {
        airPenalty = 3;
      } else {
        airPenalty = 8;
      }

      int minScore, maxScore;
      switch (type) {
        case HealthZoneType.park:
          minScore = 85; // Excellent -> Green
          maxScore = 95;
          break;
        case HealthZoneType.residential:
          minScore = 75; // Good -> Light green
          maxScore = 84;
          break;
        case HealthZoneType.mixed:
          minScore = 60; // Moderate -> Yellow
          maxScore = 74;
          break;
        case HealthZoneType.commercial:
          minScore = 45; // Poor -> Orange
          maxScore = 59;
          break;
        case HealthZoneType.traffic:
          minScore = 25; // Very poor -> Red
          maxScore = 44;
          break;
        case HealthZoneType.industrial:
          minScore = 20; // 归到 Very poor（红）
          maxScore = 40;
          break;
      }

      final base = minScore + rnd.nextInt((maxScore - minScore) + 1);
      final withAir = (base - airPenalty).clamp(minScore, maxScore);
      return withAir;
    }

    double radiusForType(HealthZoneType type, math.Random rnd) {
      double base;
      switch (type) {
        case HealthZoneType.park:
          base = 900;
          break;
        case HealthZoneType.residential:
          base = 650;
          break;
        case HealthZoneType.mixed:
          base = 700;
          break;
        case HealthZoneType.commercial:
          base = 550;
          break;
        case HealthZoneType.traffic:
          base = 700;
          break;
        case HealthZoneType.industrial:
          base = 750;
          break;
      }

      final jitter = (rnd.nextInt(301) - 150).toDouble();
      return (base + jitter).clamp(350.0, 1400.0).toDouble();
    }

    // ---------------------------------------
    // 4) 生成 zones（数量结构像米兰）
    // ---------------------------------------
    final zones = <HealthZone>[];

    zones.addAll(
      _zonesFromPoints(
        points: parks,
        type: HealthZoneType.park,
        namePrefix: '$cityName Park',
        citySeed: cityKey.hashCode + 101,
        pm25: pm25,
        scoreForType: scoreForType,
        radiusForType: radiusForType,
        description: 'Park area from OpenStreetMap POI.',
      ),
    );

    zones.addAll(
      _zonesFromPoints(
        points: residential,
        type: HealthZoneType.residential,
        namePrefix: '$cityName Residential',
        citySeed: cityKey.hashCode + 202,
        pm25: pm25,
        scoreForType: scoreForType,
        radiusForType: radiusForType,
        description: 'Residential area from OpenStreetMap landuse.',
      ),
    );

    zones.addAll(
      _zonesFromPoints(
        points: mixed,
        type: HealthZoneType.mixed,
        namePrefix: '$cityName Mixed',
        citySeed: cityKey.hashCode + 303,
        pm25: pm25,
        scoreForType: scoreForType,
        radiusForType: radiusForType,
        description: 'Mixed-use area derived from OSM cluster.',
      ),
    );

    zones.addAll(
      _zonesFromPoints(
        points: commercial,
        type: HealthZoneType.commercial,
        namePrefix: '$cityName Commercial',
        citySeed: cityKey.hashCode + 404,
        pm25: pm25,
        scoreForType: scoreForType,
        radiusForType: radiusForType,
        description: 'Commercial/retail POI from OpenStreetMap.',
      ),
    );

    zones.addAll(
      _zonesFromPoints(
        points: traffic,
        type: HealthZoneType.traffic,
        namePrefix: '$cityName Traffic',
        citySeed: cityKey.hashCode + 505,
        pm25: pm25,
        scoreForType: scoreForType,
        radiusForType: radiusForType,
        description: 'Major road area from OpenStreetMap highway.',
      ),
    );

    // 工业点有才显示（没有就算）
    zones.addAll(
      _zonesFromPoints(
        points: industrial,
        type: HealthZoneType.industrial,
        namePrefix: '$cityName Industrial',
        citySeed: cityKey.hashCode + 606,
        pm25: pm25,
        scoreForType: scoreForType,
        radiusForType: radiusForType,
        description: 'Industrial area from OpenStreetMap.',
      ),
    );

    // 如果 POI 实在太少，至少放一个 mixed 兜底
    if (zones.isEmpty) {
      zones.addAll(
        _zonesFromPoints(
          points: [center],
          type: HealthZoneType.mixed,
          namePrefix: '$cityName Mixed',
          citySeed: cityKey.hashCode + 707,
          pm25: pm25,
          scoreForType: scoreForType,
          radiusForType: radiusForType,
          description: 'Fallback zone (no POI returned).',
        ),
      );
    }

    final extra = <String>[
      'Live PM2.5: ${pm25?.toStringAsFixed(1) ?? '—'} µg/m³',
      'Live PM10: ${pm10?.toStringAsFixed(1) ?? '—'} µg/m³',
      'POI source: OpenStreetMap (Overpass)',
    ];

    for (final z in zones) {
      z.bestTimes.addAll(_bestTimesFromPm(pm25));
      z.recommendations.addAll(_recsFromPm(pm25));
      z.recommendations.addAll(extra);
      if ((pm25 ?? 0) > 35) {
        z.warnings.add('High PM2.5 right now — consider indoor activities.');
      }
    }

    return zones;
  }

  // ============================================================
  // 选点：按距离分桶 + 同类型 minKm + 跨类型 globalPicked 避让
  // ============================================================
  List<LatLng> pickSpreadGlobal({
    required LatLng center,
    required List<LatLng> candidates,
    required int count,
    required int seed,
    required List<LatLng> globalPicked,
    required double minKm,
  }) {
    if (candidates.isEmpty || count <= 0) return const <LatLng>[];

    // 去掉重复点（很多 POI 会重复）
    final uniq = <String, LatLng>{};
    for (final p in candidates) {
      final key =
          '${(p.latitude * 1e6).round()}_${(p.longitude * 1e6).round()}';
      uniq[key] = p;
    }
    final pts = uniq.values.toList();

    // 分桶（近/中/远），为了看起来更像“层次分布”
    final buckets = <List<LatLng>>[[], [], []];
    for (final p in pts) {
      final d = _haversineKm(center, p);
      if (d < 0.9) {
        buckets[0].add(p);
      } else if (d < 1.6) {
        buckets[1].add(p);
      } else {
        buckets[2].add(p);
      }
    }

    final rnd = math.Random(seed);
    for (final b in buckets) {
      b.shuffle(rnd);
    }

    bool okAgainst(List<LatLng> picked, LatLng cand) {
      // 同类型避让 + 跨类型避让
      for (final p in picked) {
        if (_haversineKm(p, cand) < minKm) return false;
      }
      for (final p in globalPicked) {
        if (_haversineKm(p, cand) < minKm) return false;
      }
      return true;
    }

    final picked = <LatLng>[];
    int guard = 0;

    // 先尝试按桶轮换拿点
    while (picked.length < count && guard < 3000) {
      guard++;
      final idx = guard % 3;
      if (buckets[idx].isEmpty) continue;

      final cand = buckets[idx].removeLast();
      if (okAgainst(picked, cand)) {
        picked.add(cand);
        globalPicked.add(cand);
      }
    }

    // 不够就从全量里补（仍满足 minKm）
    if (picked.length < count) {
      final rest = [...pts]..shuffle(math.Random(seed + 999));
      for (final cand in rest) {
        if (picked.length >= count) break;
        if (picked.contains(cand)) continue;
        if (okAgainst(picked, cand)) {
          picked.add(cand);
          globalPicked.add(cand);
        }
      }
    }

    // 实在还不够（POI 太少），允许稍微放宽一点点（不至于全挤在中心）
    if (picked.length < count) {
      final rest = [...pts]..shuffle(math.Random(seed + 1999));
      final relaxed = (minKm * 0.75).clamp(0.4, minKm);
      for (final cand in rest) {
        if (picked.length >= count) break;
        bool ok = true;
        for (final p in picked) {
          if (_haversineKm(p, cand) < relaxed) {
            ok = false;
            break;
          }
        }
        for (final p in globalPicked) {
          if (_haversineKm(p, cand) < relaxed) {
            ok = false;
            break;
          }
        }
        if (ok) {
          picked.add(cand);
          globalPicked.add(cand);
        }
      }
    }

    return picked.take(count).toList();
  }

  // ============================================================
  // zones 生成
  // ============================================================
  List<HealthZone> _zonesFromPoints({
    required List<LatLng> points,
    required HealthZoneType type,
    required String namePrefix,
    required int citySeed,
    required double? pm25,
    required int Function(HealthZoneType, math.Random, double?) scoreForType,
    required double Function(HealthZoneType, math.Random) radiusForType,
    required String description,
  }) {
    if (points.isEmpty) return const <HealthZone>[];

    final rnd = math.Random(citySeed);

    final out = <HealthZone>[];
    for (int i = 0; i < points.length; i++) {
      final score = scoreForType(type, rnd, pm25);
      final radius = radiusForType(type, rnd);

      out.add(
        HealthZone(
          id: '${namePrefix.toLowerCase().replaceAll(' ', '_')}_$i',
          name: '$namePrefix ${i + 1}',
          center: points[i],
          radius: radius,
          healthScore: score,
          type: type,
          description: description,
          bestTimes: <String>[],
          recommendations: <String>[],
          warnings: <String>[],
        ),
      );
    }
    return out;
  }

  // ============================================================
  // util
  // ============================================================
  static double _haversineKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final x =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(x), math.sqrt(1 - x));
    return r * c;
  }

  List<String> _bestTimesFromPm(double? pm25) {
    final v = pm25 ?? 20.0;
    if (v <= 15) return const ['06:00-10:00', '16:00-20:00'];
    if (v <= 35) return const ['07:00-09:30', '18:00-20:00'];
    return const ['06:00-08:30', '22:00-06:00'];
  }

  List<String> _recsFromPm(double? pm25) {
    final v = pm25 ?? 20.0;
    if (v <= 15) {
      return const [
        'Great air quality: outdoor activities recommended.',
        'Good day for jogging / cycling.',
      ];
    }
    if (v <= 35) {
      return const [
        'Moderate air quality: avoid heavy traffic streets.',
        'Sensitive individuals: reduce prolonged outdoor exercise.',
      ];
    }
    return const [
      'Poor air quality: prefer indoor activities.',
      'If you must go out, consider an FFP2/N95 mask.',
    ];
  }
}
