import 'package:flutter/material.dart';

// 全局环境数据模型
class EnvironmentData {
  final double? temperatureC;
  final double? windKmh;
  final int? weatherCode;
  final double? pm25;
  final double? pm10;
  final double? humidity;
  final DateTime lastUpdated;

  EnvironmentData({
    required this.temperatureC,
    required this.windKmh,
    required this.weatherCode,
    required this.pm25,
    required this.pm10,
    required this.humidity,
    required this.lastUpdated,
  });

  // 从WeatherResult转换
  factory EnvironmentData.fromWeatherResult(WeatherResult result) {
    return EnvironmentData(
      temperatureC: result.temperatureC,
      windKmh: result.windKmh,
      weatherCode: result.weatherCode,
      pm25: result.pm25,
      pm10: result.pm10,
      humidity: result.humidity,
      lastUpdated: DateTime.now(),
    );
  }
}

// 全局环境数据管理器
class EnvironmentDataManager extends ChangeNotifier {
  static final EnvironmentDataManager _instance = EnvironmentDataManager._internal();
  factory EnvironmentDataManager() => _instance;
  EnvironmentDataManager._internal();

  EnvironmentData? _currentData;
  
  EnvironmentData? get currentData => _currentData;
  
  void updateData(EnvironmentData data) {
    _currentData = data;
    notifyListeners();
  }
  
  // 检查数据是否过期（超过30分钟）
  bool get isDataStale {
    if (_currentData == null) return true;
    final now = DateTime.now();
    final difference = now.difference(_currentData!.lastUpdated);
    return difference.inMinutes > 30;
  }
}

// WeatherResult类定义（从main.dart移动到这里）
class WeatherResult {
  final double? temperatureC;
  final double? windKmh;
  final int? weatherCode;
  final double? pm25;
  final double? pm10;
  final double? humidity;
  final bool isFromCache;

  WeatherResult({
    required this.temperatureC,
    required this.windKmh,
    required this.weatherCode,
    required this.pm25,
    required this.pm10,
    required this.humidity,
    this.isFromCache = false,
  });

  factory WeatherResult.fromEnvironmentData(
    EnvironmentData data, {
    bool isFromCache = false,
  }) {
    return WeatherResult(
      temperatureC: data.temperatureC,
      windKmh: data.windKmh,
      weatherCode: data.weatherCode,
      humidity: data.humidity,
      pm25: data.pm25,
      pm10: data.pm10,
      isFromCache: isFromCache,
    );
  }
}