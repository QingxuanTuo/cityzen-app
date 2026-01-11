import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;

enum RouteType {
  walking,
  cycling,
  jogging,
  commuting,
}

class SafeRoute {
  final String id;
  final String name;
  final List<LatLng> points;
  final RouteType type;
  final int healthScore; // 健康评分 0-100
  final String description;
  final String estimatedTime;
  final String airQualityLevel;
  final List<String> highlights; // 路线亮点
  final List<String> warnings; // 注意事项
  final Map<String, String> timeRecommendations; // 时间段建议

  const SafeRoute({
    required this.id,
    required this.name,
    required this.points,
    required this.type,
    required this.healthScore,
    required this.description,
    required this.estimatedTime,
    required this.airQualityLevel,
    this.highlights = const [],
    this.warnings = const [],
    this.timeRecommendations = const {},
  });

  // 根据健康评分获取路线颜色
  Color get routeColor {
    if (healthScore >= 80) return const Color(0xFF4CAF50); // 绿色 - 推荐
    if (healthScore >= 60) return const Color(0xFFFFEB3B); // 黄色 - 可选
    if (healthScore >= 40) return const Color(0xFFFF9800); // 橙色 - 谨慎
    return const Color(0xFFF44336); // 红色 - 不推荐
  }

  // 获取路线类型图标
  IconData get typeIcon {
    switch (type) {
      case RouteType.walking:
        return Icons.directions_walk;
      case RouteType.cycling:
        return Icons.directions_bike;
      case RouteType.jogging:
        return Icons.directions_run;
      case RouteType.commuting:
        return Icons.commute;
    }
  }

  // 获取路线类型名称
  String get typeName {
    switch (type) {
      case RouteType.walking:
        return 'Walking';
      case RouteType.cycling:
        return 'Cycling';
      case RouteType.jogging:
        return 'Jogging';
      case RouteType.commuting:
        return 'Commuting';
    }
  }

  // 获取当前时间的建议
  String? getCurrentTimeRecommendation() {
    final now = DateTime.now();
    final currentHour = now.hour;
    
    // 根据当前时间返回相应建议
    if (currentHour >= 6 && currentHour < 9) {
      return timeRecommendations['morning'] ?? 'Good time for outdoor activities';
    } else if (currentHour >= 9 && currentHour < 12) {
      return timeRecommendations['midMorning'] ?? 'Moderate air quality expected';
    } else if (currentHour >= 12 && currentHour < 15) {
      return timeRecommendations['afternoon'] ?? 'Peak pollution hours, consider alternatives';
    } else if (currentHour >= 15 && currentHour < 18) {
      return timeRecommendations['lateAfternoon'] ?? 'Traffic increasing, use caution';
    } else if (currentHour >= 18 && currentHour < 21) {
      return timeRecommendations['evening'] ?? 'Good time for evening activities';
    } else {
      return timeRecommendations['night'] ?? 'Quiet hours, minimal traffic';
    }
  }

  // 计算路线长度（简单估算）
  double get estimatedDistance {
    if (points.length < 2) return 0.0;
    
    double totalDistance = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      totalDistance += _calculateDistance(points[i], points[i + 1]);
    }
    return totalDistance;
  }

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

// 活动建议
class ActivityRecommendation {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String timeRange;
  final List<String> locations;
  final int priority; // 1-5, 5最高

  const ActivityRecommendation({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.timeRange,
    required this.locations,
    required this.priority,
  });
}