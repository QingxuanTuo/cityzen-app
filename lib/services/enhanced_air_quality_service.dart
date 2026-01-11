import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

// 增强的空气质量服务
class EnhancedAirQualityService {
  static const String openAQBaseUrl = 'https://api.openaq.org/v2';
  static const String waqiBaseUrl = 'https://api.waqi.info';
  
  // 获取指定位置周围的多个监测站数据
  Future<List<AirQualityStation>> getNearbyStations(
    LatLng location, 
    double radiusKm
  ) async {
    final stations = <AirQualityStation>[];
    
    try {
      // 1. 获取OpenAQ监测站数据 - 增加限制数量
      final openAQStations = await _getOpenAQStations(location, radiusKm);
      stations.addAll(openAQStations);
      
      // 2. 获取Open-Meteo空气质量数据作为补充
      final openMeteoStations = await _getOpenMeteoAirQualityStations(location, radiusKm);
      stations.addAll(openMeteoStations);
      
      // 3. 数据去重和质量控制
      return _deduplicateAndValidate(stations);
    } catch (e) {
      debugPrint('Error fetching nearby stations: $e');
      return [];
    }
  }
  
  // 使用空间插值获取精确位置的空气质量
  Future<InterpolatedAirQuality> getInterpolatedAirQuality(
    LatLng location,
    double radiusKm
  ) async {
    final stations = await getNearbyStations(location, radiusKm);
    
    if (stations.isEmpty) {
      // 如果没有附近的监测站，回退到OpenMeteo数据
      return _getFallbackData(location);
    }
    
    // 使用反距离权重插值
    final interpolatedPM25 = _interpolateIDW(
      stations.where((s) => s.pm25 != null).toList(),
      location,
      (station) => station.pm25!,
    );
    
    final interpolatedPM10 = _interpolateIDW(
      stations.where((s) => s.pm10 != null).toList(),
      location,
      (station) => station.pm10!,
    );
    
    final interpolatedO3 = _interpolateIDW(
      stations.where((s) => s.ozone != null).toList(),
      location,
      (station) => station.ozone!,
    );
    
    return InterpolatedAirQuality(
      location: location,
      pm25: interpolatedPM25,
      pm10: interpolatedPM10,
      ozone: interpolatedO3,
      sourceStations: stations,
      interpolationMethod: 'IDW',
      confidence: _calculateConfidence(stations, location),
      timestamp: DateTime.now(),
    );
  }
  
  // 获取空气质量网格数据（用于热力图）
  Future<AirQualityGrid> getAirQualityGrid(
    LatLngBounds bounds,
    double resolution, // 网格分辨率 (km)
  ) async {
    final gridPoints = <GridPoint>[];
    
    // 生成网格点
    final latStep = resolution / 111.0; // 1度纬度约111km
    final lonStep = resolution / (111.0 * math.cos(bounds.center.latitude * math.pi / 180));
    
    for (double lat = bounds.south; lat <= bounds.north; lat += latStep) {
      for (double lon = bounds.west; lon <= bounds.east; lon += lonStep) {
        final point = LatLng(lat, lon);
        final airQuality = await getInterpolatedAirQuality(point, resolution * 2);
        
        gridPoints.add(GridPoint(
          location: point,
          pm25: airQuality.pm25,
          pm10: airQuality.pm10,
          ozone: airQuality.ozone,
        ));
      }
    }
    
    return AirQualityGrid(
      bounds: bounds,
      resolution: resolution,
      gridPoints: gridPoints,
      timestamp: DateTime.now(),
    );
  }
  
  // OpenAQ API调用 - 优化获取更多监测站
  Future<List<AirQualityStation>> _getOpenAQStations(
    LatLng location, 
    double radiusKm
  ) async {
    final uri = Uri.parse(
      '$openAQBaseUrl/locations'
      '?coordinates=${location.latitude},${location.longitude}'
      '&radius=${radiusKm * 1000}' // 转换为米
      '&limit=100' // 增加到100个监测站
      '&order_by=distance'
      '&has_geo=true' // 确保有地理坐标
    );
    
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        debugPrint('OpenAQ API returned status: ${response.statusCode}');
        return [];
      }
      
      final data = jsonDecode(response.body);
      final results = data['results'] as List?;
      if (results == null) return [];
      
      final stations = <AirQualityStation>[];
      for (final result in results) {
        final station = _parseOpenAQStation(result);
        if (station != null) stations.add(station);
      }
      
      debugPrint('OpenAQ returned ${stations.length} stations');
      return stations;
    } catch (e) {
      debugPrint('OpenAQ API error: $e');
      return [];
    }
  }
  
  // WAQI API调用
  Future<List<AirQualityStation>> _getWAQIStations(
    LatLng location, 
    double radiusKm
  ) async {
    // 注意：WAQI API需要API key，这里提供示例实现
    // 实际使用时需要注册获取API key
    
    final uri = Uri.parse(
      '$waqiBaseUrl/map/bounds'
      '?latlng=${location.latitude - radiusKm/111},${location.longitude - radiusKm/111},'
      '${location.latitude + radiusKm/111},${location.longitude + radiusKm/111}'
      '&token=YOUR_WAQI_TOKEN' // 需要替换为实际的API token
    );
    
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return [];
      
      final data = jsonDecode(response.body);
      final stations = data['data'] as List?;
      if (stations == null) return [];
      
      return stations
          .map((s) => _parseWAQIStation(s))
          .where((s) => s != null)
          .cast<AirQualityStation>()
          .toList();
    } catch (e) {
      debugPrint('WAQI API error: $e');
      return [];
    }
  }
  
  // 使用Open-Meteo API获取网格化空气质量数据
  Future<List<AirQualityStation>> _getOpenMeteoAirQualityStations(
    LatLng location, 
    double radiusKm
  ) async {
    final stations = <AirQualityStation>[];
    
    // 在米兰周围创建网格点来获取空气质量数据
    final gridSize = 0.05; // 约5km间隔
    final steps = (radiusKm / 5.5).round(); // 根据半径计算步数
    
    for (int i = -steps; i <= steps; i++) {
      for (int j = -steps; j <= steps; j++) {
        final lat = location.latitude + (i * gridSize);
        final lon = location.longitude + (j * gridSize);
        final gridPoint = LatLng(lat, lon);
        
        // 检查是否在指定半径内
        final distance = _calculateDistance(location, gridPoint);
        if (distance > radiusKm) continue;
        
        try {
          final station = await _fetchOpenMeteoAirQuality(gridPoint, i, j);
          if (station != null) stations.add(station);
        } catch (e) {
          // 忽略单个点的错误，继续处理其他点
          continue;
        }
      }
    }
    
    debugPrint('Open-Meteo returned ${stations.length} grid points');
    return stations;
  }
  
  // 获取单个点的Open-Meteo空气质量数据
  Future<AirQualityStation?> _fetchOpenMeteoAirQuality(LatLng point, int gridX, int gridY) async {
    final uri = Uri.parse(
      'https://air-quality-api.open-meteo.com/v1/air-quality'
      '?latitude=${point.latitude}&longitude=${point.longitude}'
      '&current=pm10,pm2_5,ozone'
      '&timezone=auto'
    );
    
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      
      final data = jsonDecode(response.body);
      final current = data['current'] as Map<String, dynamic>?;
      if (current == null) return null;
      
      final pm25 = (current['pm2_5'] as num?)?.toDouble();
      final pm10 = (current['pm10'] as num?)?.toDouble();
      final ozone = (current['ozone'] as num?)?.toDouble();
      
      // 只有当至少有一个有效数据时才创建站点
      if (pm25 == null && pm10 == null && ozone == null) return null;
      
      return AirQualityStation(
        id: 'openmeteo_${gridX}_${gridY}',
        name: 'Grid Point (${point.latitude.toStringAsFixed(2)}, ${point.longitude.toStringAsFixed(2)})',
        location: point,
        pm25: pm25,
        pm10: pm10,
        ozone: ozone,
        aqi: pm25 != null ? _calculateSimpleAQI(pm25).toDouble() : null,
        source: 'Open-Meteo',
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }
  
  // 简单的AQI计算
  int _calculateSimpleAQI(double pm25) {
    if (pm25 <= 12) return (pm25 / 12 * 50).round();
    if (pm25 <= 35.4) return (50 + (pm25 - 12) / 23.4 * 50).round();
    if (pm25 <= 55.4) return (100 + (pm25 - 35.4) / 20 * 50).round();
    if (pm25 <= 150.4) return (150 + (pm25 - 55.4) / 95 * 50).round();
    return 200;
  }

  // 反距离权重插值算法
  double? _interpolateIDW(
    List<AirQualityStation> stations,
    LatLng targetLocation,
    double Function(AirQualityStation) getValue, {
    double power = 2.0,
  }) {
    if (stations.isEmpty) return null;
    if (stations.length == 1) return getValue(stations.first);
    
    double weightedSum = 0.0;
    double weightSum = 0.0;
    
    for (final station in stations) {
      final distance = _calculateDistance(station.location, targetLocation);
      
      // 如果距离非常近，直接返回该站点的值
      if (distance < 0.001) return getValue(station);
      
      final weight = 1.0 / math.pow(distance, power);
      weightedSum += getValue(station) * weight;
      weightSum += weight;
    }
    
    return weightSum > 0 ? weightedSum / weightSum : null;
  }
  
  // 计算两点间距离 (km)
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371.0; // 地球半径 (km)
    
    final lat1Rad = point1.latitude * math.pi / 180;
    final lat2Rad = point2.latitude * math.pi / 180;
    final deltaLatRad = (point2.latitude - point1.latitude) * math.pi / 180;
    final deltaLonRad = (point2.longitude - point1.longitude) * math.pi / 180;
    
    final a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
        math.sin(deltaLonRad / 2) * math.sin(deltaLonRad / 2);
    
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }
  
  // 计算插值置信度
  double _calculateConfidence(List<AirQualityStation> stations, LatLng location) {
    if (stations.isEmpty) return 0.0;
    if (stations.length == 1) return 0.5;
    
    // 基于站点数量和距离计算置信度
    final avgDistance = stations
        .map((s) => _calculateDistance(s.location, location))
        .reduce((a, b) => a + b) / stations.length;
    
    final stationCount = stations.length;
    final distanceFactor = math.exp(-avgDistance / 10); // 距离衰减因子
    final countFactor = math.min(stationCount / 5.0, 1.0); // 站点数量因子
    
    return (distanceFactor * countFactor).clamp(0.0, 1.0);
  }
  
  // 解析OpenAQ数据
  AirQualityStation? _parseOpenAQStation(Map<String, dynamic> data) {
    try {
      final coordinates = data['coordinates'] as Map<String, dynamic>?;
      if (coordinates == null) return null;
      
      final lat = coordinates['latitude'] as double?;
      final lon = coordinates['longitude'] as double?;
      if (lat == null || lon == null) return null;
      
      final measurements = data['measurements'] as List?;
      if (measurements == null) return null;
      
      double? pm25, pm10, ozone;
      
      for (final measurement in measurements) {
        final parameter = measurement['parameter'] as String?;
        final value = (measurement['value'] as num?)?.toDouble();
        
        switch (parameter) {
          case 'pm25':
            pm25 = value;
            break;
          case 'pm10':
            pm10 = value;
            break;
          case 'o3':
            ozone = value;
            break;
        }
      }
      
      return AirQualityStation(
        id: data['id']?.toString() ?? '',
        name: data['name'] as String? ?? 'Unknown',
        location: LatLng(lat, lon),
        pm25: pm25,
        pm10: pm10,
        ozone: ozone,
        source: 'OpenAQ',
        lastUpdated: DateTime.tryParse(data['lastUpdated'] as String? ?? '') ?? DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error parsing OpenAQ station: $e');
      return null;
    }
  }
  
  // 解析WAQI数据
  AirQualityStation? _parseWAQIStation(Map<String, dynamic> data) {
    try {
      final lat = (data['lat'] as num?)?.toDouble();
      final lon = (data['lon'] as num?)?.toDouble();
      if (lat == null || lon == null) return null;
      
      final aqi = (data['aqi'] as num?)?.toDouble();
      
      return AirQualityStation(
        id: data['uid']?.toString() ?? '',
        name: data['station']['name'] as String? ?? 'Unknown',
        location: LatLng(lat, lon),
        aqi: aqi,
        source: 'WAQI',
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error parsing WAQI station: $e');
      return null;
    }
  }
  
  // 数据去重和验证
  List<AirQualityStation> _deduplicateAndValidate(List<AirQualityStation> stations) {
    final validStations = stations.where((s) => 
      s.location.latitude.abs() <= 90 && 
      s.location.longitude.abs() <= 180
    ).toList();
    
    // 简单的去重逻辑：如果两个站点距离很近，保留数据更完整的那个
    final deduped = <AirQualityStation>[];
    
    for (final station in validStations) {
      final isDuplicate = deduped.any((existing) => 
        _calculateDistance(existing.location, station.location) < 0.5 // 500m内认为是重复
      );
      
      if (!isDuplicate) {
        deduped.add(station);
      }
    }
    
    return deduped;
  }
  
  // 回退到OpenMeteo数据
  Future<InterpolatedAirQuality> _getFallbackData(LatLng location) async {
    // 这里可以调用原有的OpenMeteo API
    return InterpolatedAirQuality(
      location: location,
      pm25: null,
      pm10: null,
      ozone: null,
      sourceStations: [],
      interpolationMethod: 'Fallback',
      confidence: 0.3,
      timestamp: DateTime.now(),
    );
  }
}

// 数据模型
class AirQualityStation {
  final String id;
  final String name;
  final LatLng location;
  final double? pm25;
  final double? pm10;
  final double? ozone;
  final double? no2;
  final double? so2;
  final double? aqi;
  final String source;
  final DateTime lastUpdated;
  
  const AirQualityStation({
    required this.id,
    required this.name,
    required this.location,
    this.pm25,
    this.pm10,
    this.ozone,
    this.no2,
    this.so2,
    this.aqi,
    required this.source,
    required this.lastUpdated,
  });
}

class InterpolatedAirQuality {
  final LatLng location;
  final double? pm25;
  final double? pm10;
  final double? ozone;
  final List<AirQualityStation> sourceStations;
  final String interpolationMethod;
  final double confidence; // 0.0 - 1.0
  final DateTime timestamp;
  
  const InterpolatedAirQuality({
    required this.location,
    this.pm25,
    this.pm10,
    this.ozone,
    required this.sourceStations,
    required this.interpolationMethod,
    required this.confidence,
    required this.timestamp,
  });
}

class AirQualityGrid {
  final LatLngBounds bounds;
  final double resolution;
  final List<GridPoint> gridPoints;
  final DateTime timestamp;
  
  const AirQualityGrid({
    required this.bounds,
    required this.resolution,
    required this.gridPoints,
    required this.timestamp,
  });
}

class GridPoint {
  final LatLng location;
  final double? pm25;
  final double? pm10;
  final double? ozone;
  
  const GridPoint({
    required this.location,
    this.pm25,
    this.pm10,
    this.ozone,
  });
}