import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;

enum HealthZoneType {
  park,        // 公园绿地
  residential, // 居住区
  commercial,  // 商业区
  traffic,     // 交通繁忙区
  industrial,  // 工业区
  mixed,       // 混合区域
}

class HealthZone {
  final String id;
  final String name;
  final LatLng center;
  final double radius; // 半径（米）
  final int healthScore; // 健康评分 0-100
  final HealthZoneType type;
  final String description;
  final List<String> bestTimes; // 最佳活动时间
  final List<String> recommendations; // 建议
  final List<String> warnings; // 警告
  final Map<String, dynamic>? airQualityData;

  const HealthZone({
    required this.id,
    required this.name,
    required this.center,
    required this.radius,
    required this.healthScore,
    required this.type,
    required this.description,
    required this.bestTimes,
    this.recommendations = const [],
    this.warnings = const [],
    this.airQualityData,
  });

  // 根据健康评分获取颜色
  Color get color {
    if (healthScore >= 80) return const Color(0xFF4CAF50); // 绿色 - 优秀
    if (healthScore >= 60) return const Color(0xFFFFEB3B); // 黄色 - 良好
    if (healthScore >= 40) return const Color(0xFFFF9800); // 橙色 - 一般
    return const Color(0xFFF44336); // 红色 - 较差
  }

  // 获取健康等级描述
  String get healthLevel {
    if (healthScore >= 80) return 'Excellent';
    if (healthScore >= 60) return 'Good';
    if (healthScore >= 40) return 'Moderate';
    return 'Poor';
  }

  // 获取区域类型图标
  IconData get typeIcon {
    switch (type) {
      case HealthZoneType.park:
        return Icons.park;
      case HealthZoneType.residential:
        return Icons.home;
      case HealthZoneType.commercial:
        return Icons.business;
      case HealthZoneType.traffic:
        return Icons.traffic;
      case HealthZoneType.industrial:
        return Icons.factory;
      case HealthZoneType.mixed:
        return Icons.location_city;
    }
  }

  // 检查当前时间是否是最佳活动时间
  bool isOptimalTime(DateTime dateTime) {
    final currentTime = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    
    for (final timeRange in bestTimes) {
      final parts = timeRange.split('-');
      if (parts.length == 2) {
        final start = parts[0];
        final end = parts[1];
        
        // 简单的时间比较（这里可以改进为更精确的时间范围检查）
        if (currentTime.compareTo(start) >= 0 && currentTime.compareTo(end) <= 0) {
          return true;
        }
      }
    }
    
    return false;
  }
}