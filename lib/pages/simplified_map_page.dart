import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;
import '../services/milan_health_service.dart';
import '../models/health_zone.dart';
import '../models/safe_route.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import 'dart:async';

import '../data/cities.dart';
import '../services/location_preferences.dart';
import '../services/other_cities_health_zone_service.dart';

class SimplifiedMapPage extends StatefulWidget {
  const SimplifiedMapPage({super.key});

  @override
  State<SimplifiedMapPage> createState() => _SimplifiedMapPageState();
}

class _SimplifiedMapPageState extends State<SimplifiedMapPage> {
  final _mapController = MapController();
  final _milanHealthService = MilanHealthService.instance;

  StreamSubscription<Position>? _gpsSub;
  LatLng? _gps; // 实时GPS点（永远更新）——你原来没用到，我也不动

  static const double _gpsModeThresholdKm =
      2.0; // resolver中心和GPS差 <2km 视为“GPS模式”（保留）

  final _milan = LatLng(45.4809167, 9.2251111); // ✅ 不改
  late LatLng _center = _milan;

  bool _loading = false;
  String? _error;
  double _currentZoom = 13.0;
  LatLng _currentCenter = const LatLng(45.4809167, 9.2251111);

  List<HealthZone> _healthZones = [];
  List<ActivityRecommendation> _recommendations = [];

  HealthZone? _selectedZone;

  // ✅ 新增：轮询 Settings 变化（城市 / GPS 开关）
  Timer? _prefsPollTimer;
  bool _lastUseGps = false;
  String _lastCityKey = 'milan';
  // ✅ 演示稳定版：本地缓存（不走 Overpass）
  final Map<String, List<HealthZone>> _zonesCache = {};

  @override
  void initState() {
    super.initState();

    // ✅ 先把所有城市圈圈缓存好（不联网）
    _precacheAllZones();

    _initFromPrefsThenLoad();

    _prefsPollTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      _syncIfPrefsChanged();
    });
  }

  @override
  void dispose() {
    _prefsPollTimer?.cancel();
    _gpsSub?.cancel();
    super.dispose();
  }

  // ------------------------
  // ✅ 启动：先读 prefs -> 设中心 -> load zones
  // ------------------------
  Future<void> _initFromPrefsThenLoad() async {
    await LocationPreferences.instance.load();
    _lastUseGps = LocationPreferences.instance.useCurrentLocation;
    _lastCityKey = LocationPreferences.instance.cityKey;

    // 根据 prefs 设中心：GPS 开关开着 -> 不主动抢定位（保持你原来的按钮行为）
    // 关着 -> 用选中城市坐标
    if (!LocationPreferences.instance.useCurrentLocation) {
      final city = supportedCities.firstWhere(
        (c) => c.key == LocationPreferences.instance.cityKey,
        orElse: () => supportedCities.firstWhere(
          (c) => c.key == 'milan',
          orElse: () => supportedCities.first,
        ),
      );
      setState(() {
        _center = LatLng(city.lat, city.lon);
        _currentCenter = _center;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _mapController.move(_center, _currentZoom);
      });
    }

    await _loadHealthData(); // ✅ 保持你的刷新逻辑入口不变
  }

  // ------------------------
  // ✅ 如果 Settings 改了：同步中心 + 重新加载圈圈
  // ------------------------
  Future<void> _syncIfPrefsChanged() async {
    await LocationPreferences.instance.load();
    final useGps = LocationPreferences.instance.useCurrentLocation;
    final cityKey = LocationPreferences.instance.cityKey;

    if (useGps == _lastUseGps && cityKey == _lastCityKey) return;

    _lastUseGps = useGps;
    _lastCityKey = cityKey;

    // 1) 如果关了 GPS：中心切到选中城市
    if (!useGps) {
      final city = supportedCities.firstWhere(
        (c) => c.key == cityKey,
        orElse: () => supportedCities.firstWhere(
          (c) => c.key == 'milan',
          orElse: () => supportedCities.first,
        ),
      );
      final target = LatLng(city.lat, city.lon);
      if (!mounted) return;
      setState(() {
        _center = target;
        _currentCenter = target;
      });
      _mapController.move(target, _currentZoom);
    }

    // 2) 如果开了 GPS：不自动跳你当前位置（保持你原来“点按钮才定位”的行为）
    //    ✅ 但圈圈：我们会在 _zonesForCurrentSelection() 里强制返回 milan 圈圈
    await _loadHealthData();
  }

  void _precacheAllZones() {
    // Milan：用你现成的
    _zonesCache['milan'] = _milanHealthService.getHealthZones();

    // 其它城市：用你现成的模板生成器（就是你写的 _zonesForCurrentSelection 逻辑）
    for (final c in supportedCities) {
      if (c.key == 'milan') continue;

      final base = LatLng(c.lat, c.lon);
      LatLng o(double dLat, double dLon) =>
          LatLng(base.latitude + dLat, base.longitude + dLon);

      _zonesCache[c.key] = [
        HealthZone(
          id: '${c.key}_park_1',
          name: '${c.name.split(",").first} Park A',
          center: o(0.010, -0.010),
          radius: 900.0,
          healthScore: 88,
          type: HealthZoneType.park,
          description: 'Green area (demo template).',
          bestTimes: const ['06:00-09:00', '17:00-20:00'],
          recommendations: const ['Good for walking', 'Prefer morning/evening'],
        ),
        HealthZone(
          id: '${c.key}_park_2',
          name: '${c.name.split(",").first} Park B',
          center: o(-0.012, 0.008),
          radius: 700.0,
          healthScore: 84,
          type: HealthZoneType.park,
          description: 'Secondary green space (demo template).',
          bestTimes: const ['07:00-10:00', '16:00-19:00'],
          recommendations: const ['Light exercise', 'Avoid rush hours'],
        ),
        HealthZone(
          id: '${c.key}_residential',
          name: '${c.name.split(",").first} Residential',
          center: o(0.006, 0.012),
          radius: 650.0,
          healthScore: 70,
          type: HealthZoneType.residential,
          description: 'Residential area (demo template).',
          bestTimes: const ['07:00-10:00', '15:00-18:00'],
          recommendations: const ['Nice for slow walks'],
        ),
        HealthZone(
          id: '${c.key}_commercial',
          name: '${c.name.split(",").first} Center',
          center: o(-0.004, -0.002),
          radius: 550.0,
          healthScore: 55,
          type: HealthZoneType.commercial,
          description: 'Commercial center (demo template).',
          bestTimes: const ['08:00-10:00', '14:00-16:00'],
          recommendations: const ['Short visits recommended'],
        ),
        HealthZone(
          id: '${c.key}_traffic',
          name: '${c.name.split(",").first} Traffic Hub',
          center: o(0.014, 0.004),
          radius: 700.0,
          healthScore: 42,
          type: HealthZoneType.traffic,
          description: 'High traffic area (demo template).',
          bestTimes: const ['22:00-06:00'],
          recommendations: const ['Minimize exposure time', 'Consider a mask'],
          warnings: const ['Likely crowded at peak hours'],
        ),
      ];
    }
  }

  // ------------------------
  // ✅ 关键：根据当前 cityKey 返回圈圈数据
  // ✅ 你要求：GPS 开时直接显示米兰圈圈（不动定位逻辑）
  // ------------------------
  List<HealthZone> _zonesForCurrentSelection() {
    final prefs = LocationPreferences.instance;

    // ✅ GPS 开：强制使用米兰圈圈
    if (prefs.useCurrentLocation) {
      return _milanHealthService.getHealthZones();
    }

    final cityKey = prefs.cityKey;

    // ✅ 米兰：完全保持原样
    if (cityKey == 'milan') {
      return _milanHealthService.getHealthZones();
    }

    // ✅ 其它城市：先用模板 zones（你以后把每个 center 换成真实坐标即可）
    final city = supportedCities.firstWhere(
      (c) => c.key == cityKey,
      orElse: () => supportedCities.firstWhere(
        (c) => c.key == 'milan',
        orElse: () => supportedCities.first,
      ),
    );
    final base = LatLng(city.lat, city.lon);

    LatLng o(double dLat, double dLon) =>
        LatLng(base.latitude + dLat, base.longitude + dLon);

    return [
      HealthZone(
        id: '${cityKey}_park_1',
        name: '${city.name.split(",").first} Park A',
        center: o(0.010, -0.010),
        radius: 900.0, // ✅ double
        healthScore: 88,
        type: HealthZoneType.park,
        description: 'Green area (template). Replace with real location later.',
        bestTimes: const ['06:00-09:00', '17:00-20:00'],
        recommendations: const ['Good for walking', 'Prefer morning/evening'],
      ),
      HealthZone(
        id: '${cityKey}_park_2',
        name: '${city.name.split(",").first} Park B',
        center: o(-0.012, 0.008),
        radius: 700.0,
        healthScore: 84,
        type: HealthZoneType.park,
        description: 'Secondary green space (template).',
        bestTimes: const ['07:00-10:00', '16:00-19:00'],
        recommendations: const ['Light exercise', 'Avoid rush hours'],
      ),
      HealthZone(
        id: '${cityKey}_residential',
        name: '${city.name.split(",").first} Residential',
        center: o(0.006, 0.012),
        radius: 650.0,
        healthScore: 70,
        type: HealthZoneType.residential,
        description: 'Residential area (template).',
        bestTimes: const ['07:00-10:00', '15:00-18:00'],
        recommendations: const ['Nice for slow walks'],
      ),
      HealthZone(
        id: '${cityKey}_commercial',
        name: '${city.name.split(",").first} Center',
        center: o(-0.004, -0.002),
        radius: 550.0,
        healthScore: 55,
        type: HealthZoneType.commercial,
        description: 'Commercial center (template).',
        bestTimes: const ['08:00-10:00', '14:00-16:00'],
        recommendations: const ['Short visits recommended'],
      ),
      HealthZone(
        id: '${cityKey}_traffic',
        name: '${city.name.split(",").first} Traffic Hub',
        center: o(0.014, 0.004),
        radius: 700.0,
        healthScore: 42,
        type: HealthZoneType.traffic,
        description: 'High traffic area (template).',
        bestTimes: const ['22:00-06:00'],
        recommendations: const ['Minimize exposure time', 'Consider a mask'],
        warnings: const ['Likely crowded at peak hours'],
      ),
    ];
  }

  Future<void> _loadHealthData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await LocationPreferences.instance.load();
      final prefs = LocationPreferences.instance;

      // ✅ GPS 开：圈圈固定米兰（你要求的）
      if (prefs.useCurrentLocation) {
        _healthZones = _milanHealthService.getHealthZones();
        _recommendations = _milanHealthService.getCurrentRecommendations();
        setState(() => _loading = false);
        return;
      }

      // ✅ GPS 关：根据选中城市
      final city = supportedCities.firstWhere(
        (c) => c.key == prefs.cityKey,
        orElse: () => supportedCities.firstWhere(
          (c) => c.key == 'milan',
          orElse: () => supportedCities.first,
        ),
      );

      if (city.key == 'milan') {
        _healthZones = _milanHealthService.getHealthZones();
        _recommendations = _milanHealthService.getCurrentRecommendations();
      } else {
        // ✅ 演示稳定版：不走 Overpass，不联网，直接用缓存模板
        _healthZones = _zonesCache[city.key] ?? <HealthZone>[];
        _recommendations = const <ActivityRecommendation>[];
      }

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = 'Data temporarily unavailable. Please tap refresh.';
        _loading = false;
      });
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    for (final zone in _healthZones) {
      final distance = _calculateDistance(point, zone.center);
      if (distance <= zone.radius / 1000) {
        _showZoneDetails(zone);
        return;
      }
    }
  }

  void _showZoneDetails(HealthZone zone) {
    setState(() {
      _selectedZone = zone;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildZoneBottomSheet(zone),
    );
  }

  Widget _buildZoneBottomSheet(HealthZone zone) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final bottomPadding = mediaQuery.padding.bottom;
    final sheetHeight = screenHeight * 0.5;

    return Container(
      height: sheetHeight + bottomPadding,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () {
                    setState(() {
                      _selectedZone = null;
                    });
                    Navigator.of(context).pop();
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(zone.typeIcon, size: 24, color: zone.color),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              zone.name,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              zone.healthLevel,
                              style: TextStyle(
                                color: zone.color,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: zone.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: zone.color),
                        ),
                        child: Text(
                          '${zone.healthScore}/100',
                          style: TextStyle(
                            color: zone.color,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    zone.description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (zone.bestTimes.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Best Times',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: zone.bestTimes
                          .map(
                            (time) => Chip(
                              label: Text(
                                time,
                                style: const TextStyle(fontSize: 12),
                              ),
                              backgroundColor:
                                  zone.isOptimalTime(DateTime.now())
                                  ? Colors.green.withOpacity(0.2)
                                  : Colors.grey.withOpacity(0.2),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  if (zone.recommendations.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Recommendations',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...zone.recommendations.map(
                      (recommendation) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: zone.color,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                recommendation,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          SizedBox(height: bottomPadding),
        ],
      ),
    );
  }

  Widget _buildInfoPanel() {
    if (_recommendations.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Text(
                'Current Recommendations',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._recommendations
              .take(2)
              .map(
                (rec) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(rec.icon, color: rec.color, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rec.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              rec.description,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371.0;

    final lat1Rad = point1.latitude * math.pi / 180;
    final lat2Rad = point2.latitude * math.pi / 180;
    final deltaLatRad = (point2.latitude - point1.latitude) * math.pi / 180;
    final deltaLonRad = (point2.longitude - point1.longitude) * math.pi / 180;

    final a =
        math.pow(math.sin(deltaLatRad / 2), 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.pow(math.sin(deltaLonRad / 2), 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  Widget _buildLegendPanel() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.legend_toggle, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  'Legend',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: _buildHealthZonesLegend(),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthZonesLegend() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Health Zones',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
        ),
        const SizedBox(height: 6),
        _buildLegendItem(
          color: const Color(0xFF4CAF50),
          icon: Icons.park,
          title: 'Excellent',
          description: 'Parks',
        ),
        _buildLegendItem(
          color: const Color(0xFF8BC34A),
          icon: Icons.home,
          title: 'Good',
          description: 'Residential',
        ),
        _buildLegendItem(
          color: const Color(0xFFFFEB3B),
          icon: Icons.location_city,
          title: 'Moderate',
          description: 'Mixed Use',
        ),
        _buildLegendItem(
          color: const Color(0xFFFF9800),
          icon: Icons.business,
          title: 'Poor',
          description: 'Commercial',
        ),
        _buildLegendItem(
          color: const Color(0xFFF44336),
          icon: Icons.traffic,
          title: 'Very Poor',
          description: 'High Traffic',
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.info_outline, size: 12, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Tap zones for details',
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color.withOpacity(0.3),
              border: Border.all(color: color, width: 1.5),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 7, color: color),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(fontSize: 8, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)?.environmentalHealthMap ??
              'Environmental Health Map',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadHealthData,
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: _currentZoom,
              minZoom: 10,
              maxZoom: 18,
              onTap: _onMapTap,
              onPositionChanged: (position, _) {
                final z = position.zoom;
                final c = position.center;
                if (z != null) _currentZoom = z;
                if (c != null) _currentCenter = c;
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.example.cityzen',
              ),

              CircleLayer(
                circles: _healthZones
                    .map(
                      (zone) => CircleMarker(
                        point: zone.center,
                        color: zone.color.withOpacity(0.3),
                        borderColor: zone.color,
                        borderStrokeWidth: 2,
                        radius: zone.radius / 10,
                      ),
                    )
                    .toList(),
              ),

              MarkerLayer(
                markers: [
                  Marker(
                    point: _center,
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  ..._healthZones.map(
                    (zone) => Marker(
                      point: zone.center,
                      width: 30,
                      height: 30,
                      child: GestureDetector(
                        onTap: () => _showZoneDetails(zone),
                        child: Container(
                          decoration: BoxDecoration(
                            color: zone.color,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Icon(
                            zone.typeIcon,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          if (_loading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading health data...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          if (_error != null && !_loading)
            Positioned(
              top: 80,
              left: 16,
              right: 16,
              child: Card(
                color: Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Error: $_error',
                    style: TextStyle(color: Colors.red[900]),
                  ),
                ),
              ),
            ),

          Positioned(bottom: 100, left: 0, right: 0, child: _buildInfoPanel()),
          Positioned(bottom: 16, right: 16, child: _buildLegendPanel()),

          // ✅ 你的定位按钮：完全保留（点了才去真实当前位置）
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'location',
              mini: true,
              backgroundColor: Colors.white,
              onPressed: () async {
                try {
                  final position = await Geolocator.getCurrentPosition();
                  final userLocation = LatLng(
                    position.latitude,
                    position.longitude,
                  );

                  setState(() {
                    _center = userLocation;
                    _currentCenter = userLocation;
                  });

                  _mapController.move(userLocation, _currentZoom);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Location updated'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to get location: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Icon(Icons.my_location, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
