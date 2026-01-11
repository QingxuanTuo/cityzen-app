import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;
import '../models/health_zone.dart';
import '../models/safe_route.dart';

class MilanHealthService {
  static MilanHealthService? _instance;
  static MilanHealthService get instance => _instance ??= MilanHealthService._();
  
  MilanHealthService._();

  // 米兰健康区域数据（基于真实情况）
  List<HealthZone> getHealthZones() {
    return [
      // 公园和绿地 - 健康评分高
      HealthZone(
        id: 'parco_sempione',
        name: 'Parco Sempione',
        center: LatLng(45.4742, 9.1717),
        radius: 800,
        healthScore: 90,
        type: HealthZoneType.park,
        description: 'Large central park with excellent air quality and green spaces',
        bestTimes: ['06:00-09:00', '17:00-20:00'],
        recommendations: [
          'Perfect for morning jogs and evening walks',
          'Clean air, ideal for outdoor exercise',
          'Multiple walking paths and open areas',
        ],
      ),
      
      HealthZone(
        id: 'giardini_pubblici',
        name: 'Giardini Pubblici Indro Montanelli',
        center: LatLng(45.4719, 9.2017),
        radius: 600,
        healthScore: 85,
        type: HealthZoneType.park,
        description: 'Historic public gardens with museums and clean environment',
        bestTimes: ['07:00-10:00', '16:00-19:00'],
        recommendations: [
          'Great for family activities',
          'Cultural attractions nearby',
          'Well-maintained paths for walking',
        ],
      ),

      HealthZone(
        id: 'parco_lambro',
        name: 'Parco Lambro',
        center: LatLng(45.5167, 9.2500),
        radius: 1200,
        healthScore: 88,
        type: HealthZoneType.park,
        description: 'Large park along the Lambro river with cycling paths',
        bestTimes: ['06:30-09:30', '17:30-20:00'],
        recommendations: [
          'Excellent for cycling and jogging',
          'River views and natural environment',
          'Less crowded than central parks',
        ],
      ),

      // 居住区 - 中等健康评分
      HealthZone(
        id: 'brera',
        name: 'Brera District',
        center: LatLng(45.4719, 9.1881),
        radius: 500,
        healthScore: 72,
        type: HealthZoneType.residential,
        description: 'Historic residential area with moderate air quality',
        bestTimes: ['07:00-10:00', '15:00-18:00'],
        recommendations: [
          'Charming streets for leisurely walks',
          'Avoid peak traffic hours',
          'Many cafes and cultural sites',
        ],
      ),

      HealthZone(
        id: 'navigli',
        name: 'Navigli District',
        center: LatLng(45.4484, 9.1767),
        radius: 700,
        healthScore: 68,
        type: HealthZoneType.mixed,
        description: 'Canal district with nightlife, moderate pollution levels',
        bestTimes: ['10:00-16:00', '20:00-23:00'],
        recommendations: [
          'Evening walks along the canals',
          'Avoid during rush hours',
          'Good for social activities',
        ],
      ),

      // 商业区 - 较低健康评分
      HealthZone(
        id: 'duomo_center',
        name: 'Duomo & City Center',
        center: LatLng(45.4642, 9.1900),
        radius: 400,
        healthScore: 55,
        type: HealthZoneType.commercial,
        description: 'Historic city center with high pedestrian traffic',
        bestTimes: ['08:00-10:00', '14:00-16:00'],
        recommendations: [
          'Short visits recommended',
          'Use pedestrian areas when possible',
          'Avoid during peak tourist hours',
        ],
      ),

      // 交通繁忙区 - 低健康评分
      HealthZone(
        id: 'porta_garibaldi',
        name: 'Porta Garibaldi',
        center: LatLng(45.4853, 9.1889),
        radius: 600,
        healthScore: 45,
        type: HealthZoneType.traffic,
        description: 'Major transport hub with high traffic and pollution',
        bestTimes: ['22:00-06:00'],
        recommendations: [
          'Use face masks during peak hours',
          'Minimize exposure time',
          'Use underground passages when available',
        ],
        warnings: [
          'High pollution levels during rush hours',
          'Heavy traffic 7-9 AM and 5-7 PM',
        ],
      ),

      HealthZone(
        id: 'centrale_station',
        name: 'Milano Centrale Area',
        center: LatLng(45.4864, 9.2058),
        radius: 500,
        healthScore: 42,
        type: HealthZoneType.traffic,
        description: 'Main railway station area with heavy traffic',
        bestTimes: ['23:00-06:00'],
        recommendations: [
          'Transit area - minimize stay time',
          'Use indoor passages',
          'Wear protective masks',
        ],
      ),
    ];
  }

  // 安全路线数据 - 基于真实米兰道路网络
  List<SafeRoute> getSafeRoutes() {
    return [
      // 1. 从中心到Parco Sempione的步行路线（沿Via Dante）
      SafeRoute(
        id: 'to_parco_sempione',
        name: 'Via Dante to Parco Sempione',
        points: [
          LatLng(45.4809, 9.2251), // 起点
          LatLng(45.4798, 9.2180), // Via Brera
          LatLng(45.4785, 9.2100), // Via Dante
          LatLng(45.4770, 9.1950), // Largo Cairoli
          LatLng(45.4742, 9.1717), // Parco Sempione入口
        ],
        type: RouteType.walking,
        healthScore: 82,
        description: 'Pedestrian-friendly route through historic center to the park',
        estimatedTime: '18 min walk',
        airQualityLevel: 'Good',
        highlights: [
          'Wide pedestrian sidewalks',
          'Historic architecture along Via Dante',
          'Minimal traffic exposure',
          'Direct access to park entrance',
        ],
        timeRecommendations: {
          'morning': 'Perfect for morning walks - fresh air and fewer crowds',
          'afternoon': 'Good, but busier with tourists',
          'evening': 'Excellent for sunset walks in the park',
        },
      ),

      // 2. 沿Navigli运河的骑行路线
      SafeRoute(
        id: 'navigli_cycle',
        name: 'Navigli Canal Cycling Path',
        points: [
          LatLng(45.4809, 9.2251), // 起点
          LatLng(45.4750, 9.2050), // Via Torino
          LatLng(45.4650, 9.1850), // Porta Ticinese
          LatLng(45.4550, 9.1750), // Naviglio Grande
          LatLng(45.4484, 9.1767), // Navigli区域
          LatLng(45.4400, 9.1650), // 沿运河继续
        ],
        type: RouteType.cycling,
        healthScore: 75,
        description: 'Scenic cycling route along historic canals with dedicated bike lanes',
        estimatedTime: '25 min cycle',
        airQualityLevel: 'Moderate',
        highlights: [
          'Dedicated cycling paths along canals',
          'Historic Navigli district',
          'Waterside views and fresh air',
          'Many cafes and rest stops',
        ],
        warnings: [
          'Busy area in evenings',
          'Watch for pedestrians near restaurants',
        ],
        timeRecommendations: {
          'morning': 'Quiet and peaceful cycling',
          'afternoon': 'Good for sightseeing',
          'evening': 'Crowded but vibrant atmosphere',
        },
      ),

      // 3. 地铁站之间的安全步行路线
      SafeRoute(
        id: 'metro_connection',
        name: 'Duomo to Cadorna (Underground)',
        points: [
          LatLng(45.4642, 9.1900), // Duomo地铁站
          LatLng(45.4650, 9.1880), // Via Orefici (地下通道)
          LatLng(45.4680, 9.1850), // Cordusio地铁站
          LatLng(45.4720, 9.1820), // Via Dante
          LatLng(45.4742, 9.1717), // Cadorna地铁站
        ],
        type: RouteType.commuting,
        healthScore: 65,
        description: 'Protected route using metro tunnels and covered walkways',
        estimatedTime: '15 min walk',
        airQualityLevel: 'Good (Indoor)',
        highlights: [
          'Weather-protected route',
          'Underground passages available',
          'Direct metro connections',
          'Minimal air pollution exposure',
        ],
        warnings: [
          'Can be crowded during rush hours',
          'Some sections require metro ticket',
        ],
      ),

      // 4. 公园连接路线（绿色走廊）
      SafeRoute(
        id: 'green_corridor',
        name: 'Green Parks Corridor',
        points: [
          LatLng(45.4742, 9.1717), // Parco Sempione
          LatLng(45.4750, 9.1850), // Via Brera (树荫街道)
          LatLng(45.4720, 9.1950), // Via Manzoni
          LatLng(45.4719, 9.2017), // Giardini Pubblici
          LatLng(45.4750, 9.2100), // Via Palestro
          LatLng(45.4780, 9.2200), // Porta Venezia公园
        ],
        type: RouteType.jogging,
        healthScore: 88,
        description: 'Tree-lined route connecting major parks and green spaces',
        estimatedTime: '35 min jog',
        airQualityLevel: 'Excellent',
        highlights: [
          'Connects 3 major parks',
          'Tree-lined streets for shade',
          'Excellent air quality',
          'Dedicated jogging paths in parks',
        ],
        timeRecommendations: {
          'morning': 'Best time - cool and fresh air',
          'evening': 'Good for after-work exercise',
        },
      ),

      // 5. 避开交通的居民区路线
      SafeRoute(
        id: 'residential_safe',
        name: 'Quiet Residential Streets',
        points: [
          LatLng(45.4809, 9.2251), // 起点
          LatLng(45.4820, 9.2200), // Via Moscova (居民区)
          LatLng(45.4850, 9.2150), // Via Solferino
          LatLng(45.4880, 9.2100), // Corso Garibaldi (步行区)
          LatLng(45.4900, 9.2050), // Isola区域
        ],
        type: RouteType.walking,
        healthScore: 78,
        description: 'Quiet residential streets with minimal traffic and good air quality',
        estimatedTime: '22 min walk',
        airQualityLevel: 'Good',
        highlights: [
          'Low traffic residential areas',
          'Local neighborhood atmosphere',
          'Safe pedestrian crossings',
          'Good air circulation',
        ],
        warnings: [
          'Some narrow sidewalks',
          'Less lighting at night',
        ],
      ),
    ];
  }

  // 根据当前时间和环境条件获取活动建议
  List<ActivityRecommendation> getCurrentRecommendations({
    double? pm25,
    double? temperature,
    int? weatherCode,
  }) {
    final now = DateTime.now();
    final recommendations = <ActivityRecommendation>[];

    // 基于时间的建议
    if (now.hour >= 6 && now.hour < 9) {
      recommendations.add(ActivityRecommendation(
        title: 'Morning Park Walk',
        description: 'Fresh air and fewer crowds in Parco Sempione',
        icon: Icons.directions_walk,
        color: Colors.green,
        timeRange: '06:00-09:00',
        locations: ['Parco Sempione', 'Giardini Pubblici'],
        priority: 5,
      ));
    }

    if (now.hour >= 17 && now.hour < 20) {
      recommendations.add(ActivityRecommendation(
        title: 'Evening Cycling',
        description: 'Perfect time for cycling along the Lambro River',
        icon: Icons.directions_bike,
        color: Colors.blue,
        timeRange: '17:00-20:00',
        locations: ['Parco Lambro', 'Cycling paths'],
        priority: 4,
      ));
    }

    // 基于空气质量的建议
    if (pm25 != null) {
      if (pm25 < 15) {
        recommendations.add(ActivityRecommendation(
          title: 'Outdoor Exercise',
          description: 'Excellent air quality - perfect for any outdoor activity',
          icon: Icons.fitness_center,
          color: Colors.green,
          timeRange: 'All day',
          locations: ['All parks', 'Outdoor areas'],
          priority: 5,
        ));
      } else if (pm25 > 35) {
        recommendations.add(ActivityRecommendation(
          title: 'Indoor Activities',
          description: 'High pollution - consider indoor alternatives',
          icon: Icons.home,
          color: Colors.orange,
          timeRange: 'Until air improves',
          locations: ['Indoor gyms', 'Shopping centers'],
          priority: 3,
        ));
      }
    }

    // 基于天气的建议
    if (weatherCode != null) {
      if (weatherCode == 0) { // Clear sky
        recommendations.add(ActivityRecommendation(
          title: 'Outdoor Photography',
          description: 'Clear skies perfect for exploring the city',
          icon: Icons.camera_alt,
          color: Colors.amber,
          timeRange: 'Daylight hours',
          locations: ['Duomo', 'Navigli', 'Brera'],
          priority: 3,
        ));
      }
    }

    // 排序并返回
    recommendations.sort((a, b) => b.priority.compareTo(a.priority));
    return recommendations;
  }

  // 获取特定区域的详细信息
  HealthZone? getZoneById(String id) {
    try {
      return getHealthZones().firstWhere((zone) => zone.id == id);
    } catch (e) {
      return null;
    }
  }

  // 获取特定路线的详细信息
  SafeRoute? getRouteById(String id) {
    try {
      return getSafeRoutes().firstWhere((route) => route.id == id);
    } catch (e) {
      return null;
    }
  }

  // 根据位置获取最近的健康区域
  HealthZone? getNearestZone(LatLng location) {
    final zones = getHealthZones();
    if (zones.isEmpty) return null;

    HealthZone? nearest;
    double minDistance = double.infinity;

    for (final zone in zones) {
      final distance = _calculateDistance(location, zone.center);
      if (distance < minDistance) {
        minDistance = distance;
        nearest = zone;
      }
    }

    return nearest;
  }

  // 计算两点间距离（公里）
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371.0;
    
    final lat1Rad = point1.latitude * math.pi / 180;
    final lat2Rad = point2.latitude * math.pi / 180;
    final deltaLatRad = (point2.latitude - point1.latitude) * math.pi / 180;
    final deltaLonRad = (point2.longitude - point1.longitude) * math.pi / 180;
    
    final a = math.pow(math.sin(deltaLatRad / 2), 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
        math.pow(math.sin(deltaLonRad / 2), 2);
    
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }
}