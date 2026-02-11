import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class OsmPoiResult {
  final List<LatLng> parks;
  final List<LatLng> commercial;
  final List<LatLng> residential;
  final List<LatLng> traffic;

  const OsmPoiResult({
    required this.parks,
    required this.commercial,
    required this.residential,
    required this.traffic,
  });
}

class OsmPoiService {
  static final OsmPoiService instance = OsmPoiService._();
  OsmPoiService._();

  // Overpass 官方有多个 endpoint；这个最常用
  static const _endpoint = 'https://overpass-api.de/api/interpreter';

  // 简单缓存：同一城市中心附近 10 分钟内不重复拉
  final Map<String, (_CacheEntry entry, DateTime at)> _cache = {};
  final Duration _ttl = const Duration(minutes: 10);

  Future<OsmPoiResult> fetchAround({
    required String cacheKey, // 建议传 cityKey
    required LatLng center,
    double radiusMeters = 2500,
    int timeoutSeconds = 25,
  }) async {
    final now = DateTime.now();
    final hit = _cache[cacheKey];
    if (hit != null && now.difference(hit.$2) < _ttl) {
      return hit.$1.data;
    }

    final query = _buildQuery(
      center: center,
      radiusMeters: radiusMeters,
      timeoutSeconds: timeoutSeconds,
    );

    final resp = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
      },
      body: 'data=${Uri.encodeQueryComponent(query)}',
    );

    if (resp.statusCode != 200) {
      throw Exception('Overpass error ${resp.statusCode}: ${resp.body}');
    }

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final elements = (json['elements'] as List).cast<Map<String, dynamic>>();

    final parks = <LatLng>[];
    final commercial = <LatLng>[];
    final residential = <LatLng>[];
    final traffic = <LatLng>[];

    for (final e in elements) {
      final type = e['type'];
      final tags = (e['tags'] as Map?)?.cast<String, dynamic>() ?? const {};
      LatLng? p;

      // node: 直接 lat/lon
      if (type == 'node' && e['lat'] != null && e['lon'] != null) {
        p = LatLng((e['lat'] as num).toDouble(), (e['lon'] as num).toDouble());
      }

      // way/rel: 我们在 query 里用了 out center; 会有 center 字段
      final centerObj = e['center'];
      if (p == null &&
          centerObj is Map &&
          centerObj['lat'] != null &&
          centerObj['lon'] != null) {
        p = LatLng(
          (centerObj['lat'] as num).toDouble(),
          (centerObj['lon'] as num).toDouble(),
        );
      }

      if (p == null) continue;

      final leisure = tags['leisure']?.toString();
      final landuse = tags['landuse']?.toString();
      final highway = tags['highway']?.toString();
      final shop = tags['shop']?.toString();
      final amenity = tags['amenity']?.toString();

      // park
      if (leisure == 'park' ||
          leisure == 'garden' ||
          leisure == 'nature_reserve') {
        parks.add(p);
        continue;
      }

      // commercial（零售/商业区/市场）
      final isRetailLanduse = landuse == 'retail' || landuse == 'commercial';
      final isShop = shop != null; // 任意 shop tag
      final isMarketplace = amenity == 'marketplace';
      if (isRetailLanduse || isShop || isMarketplace) {
        commercial.add(p);
        continue;
      }

      // residential（住宅用地）
      if (landuse == 'residential') {
        residential.add(p);
        continue;
      }

      // traffic：主干道/快速路/环路等
      final isTrafficRoad =
          highway == 'motorway' ||
          highway == 'trunk' ||
          highway == 'primary' ||
          highway == 'secondary' ||
          highway == 'tertiary';
      if (isTrafficRoad) {
        traffic.add(p);
        continue;
      }
    }

    final data = OsmPoiResult(
      parks: parks,
      commercial: commercial,
      residential: residential,
      traffic: traffic,
    );

    _cache[cacheKey] = (_CacheEntry(data), now);
    return data;
  }

  String _buildQuery({
    required LatLng center,
    required double radiusMeters,
    required int timeoutSeconds,
  }) {
    // 用 around:radius,lat,lon 会比 bbox 更精确
    // out center; 对 way/rel 也给中心点
    return '''
[out:json][timeout:$timeoutSeconds];
(
  // parks
  node(around:$radiusMeters,${center.latitude},${center.longitude})[leisure~"park|garden|nature_reserve"];
  way(around:$radiusMeters,${center.latitude},${center.longitude})[leisure~"park|garden|nature_reserve"];
  relation(around:$radiusMeters,${center.latitude},${center.longitude})[leisure~"park|garden|nature_reserve"];

  // residential landuse
  way(around:$radiusMeters,${center.latitude},${center.longitude})[landuse="residential"];
  relation(around:$radiusMeters,${center.latitude},${center.longitude})[landuse="residential"];

  // commercial/retail
  node(around:$radiusMeters,${center.latitude},${center.longitude})[shop];
  way(around:$radiusMeters,${center.latitude},${center.longitude})[landuse~"commercial|retail"];
  relation(around:$radiusMeters,${center.latitude},${center.longitude})[landuse~"commercial|retail"];
  node(around:$radiusMeters,${center.latitude},${center.longitude})[amenity="marketplace"];

  // traffic roads (ways)
  way(around:$radiusMeters,${center.latitude},${center.longitude})[highway~"motorway|trunk|primary|secondary|tertiary"];
);
out center;
''';
  }
}

class _CacheEntry {
  final OsmPoiResult data;
  _CacheEntry(this.data);
}
