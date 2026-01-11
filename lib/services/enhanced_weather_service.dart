import 'dart:convert';
import 'dart:isolate';
import 'package:http/http.dart' as http;
import 'package:cityzen/environment_data.dart';
import 'package:cityzen/services/offline_cache_service.dart';

/// 增强版天气服务 - 支持离线模式和多线程处理
/// 展示复杂的异步编程和后台任务处理能力
class EnhancedWeatherService {
  static const String _weatherBaseUrl = 'https://api.open-meteo.com/v1/forecast';
  static const String _airQualityBaseUrl = 'https://air-quality-api.open-meteo.com/v1/air-quality';
  
  final OfflineCacheService _cacheService = OfflineCacheService();

  /// 获取天气数据 - 支持离线模式
  /// 优先使用网络数据，网络不可用时使用缓存
  Future<WeatherResult> getWeatherData({
    required double latitude,
    required double longitude,
    bool forceRefresh = false,
  }) async {
    final locationKey = '${latitude.toStringAsFixed(4)}_${longitude.toStringAsFixed(4)}';
    
    // 检查网络连接
    final isOnline = await _cacheService.isNetworkAvailable();
    
    if (!forceRefresh && !isOnline) {
      // 离线模式：尝试从缓存获取数据
      final cachedData = await _cacheService.getCachedEnvironmentData(locationKey);
      if (cachedData != null) {
        return WeatherResult.fromEnvironmentData(cachedData, isFromCache: true);
      } else {
        throw Exception('No internet connection and no cached data available');
      }
    }

    try {
      // 在线模式：使用Isolate进行后台数据处理
      final weatherResult = await _fetchWeatherDataInBackground(latitude, longitude);
      
      // 缓存新数据
      final envData = EnvironmentData.fromWeatherResult(weatherResult);
      await _cacheService.cacheEnvironmentData(locationKey, envData);
      
      return weatherResult;
    } catch (e) {
      // 网络请求失败，尝试使用缓存数据
      final cachedData = await _cacheService.getCachedEnvironmentData(locationKey);
      if (cachedData != null) {
        return WeatherResult.fromEnvironmentData(cachedData, isFromCache: true);
      }
      rethrow;
    }
  }

  /// 在后台Isolate中获取天气数据
  /// 展示多线程编程能力，避免阻塞UI线程
  Future<WeatherResult> _fetchWeatherDataInBackground(
    double latitude,
    double longitude,
  ) async {
    final receivePort = ReceivePort();
    
    // 创建Isolate进行后台处理
    await Isolate.spawn(
      _weatherDataIsolate,
      IsolateData(
        sendPort: receivePort.sendPort,
        latitude: latitude,
        longitude: longitude,
      ),
    );

    // 等待Isolate返回结果
    final result = await receivePort.first;
    
    if (result is Exception) {
      throw result;
    }
    
    return result as WeatherResult;
  }

  /// 批量获取多个位置的天气数据
  /// 使用并行处理提高效率
  Future<Map<String, WeatherResult>> getBatchWeatherData(
    List<({double lat, double lon, String name})> locations,
  ) async {
    final futures = <Future<MapEntry<String, WeatherResult>>>[];
    
    for (final location in locations) {
      futures.add(
        getWeatherData(
          latitude: location.lat,
          longitude: location.lon,
        ).then((result) => MapEntry(location.name, result)),
      );
    }
    
    // 并行执行所有请求
    final results = await Future.wait(futures);
    return Map.fromEntries(results);
  }

  /// 获取历史天气趋势数据
  Future<List<WeatherTrendPoint>> getWeatherTrend({
    required double latitude,
    required double longitude,
    int days = 7,
  }) async {
    try {
      final uri = Uri.parse(
        '$_weatherBaseUrl'
        '?latitude=$latitude&longitude=$longitude'
        '&daily=temperature_2m_max,temperature_2m_min,precipitation_sum'
        '&past_days=$days'
        '&timezone=auto',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch weather trend: ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final daily = data['daily'] as Map<String, dynamic>;
      
      final dates = (daily['time'] as List).cast<String>();
      final maxTemps = (daily['temperature_2m_max'] as List).cast<double?>();
      final minTemps = (daily['temperature_2m_min'] as List).cast<double?>();
      final precipitation = (daily['precipitation_sum'] as List).cast<double?>();
      
      final trendPoints = <WeatherTrendPoint>[];
      
      for (int i = 0; i < dates.length; i++) {
        trendPoints.add(WeatherTrendPoint(
          date: DateTime.parse(dates[i]),
          maxTemperature: maxTemps[i],
          minTemperature: minTemps[i],
          precipitation: precipitation[i] ?? 0.0,
        ));
      }
      
      return trendPoints;
    } catch (e) {
      throw Exception('Failed to fetch weather trend: $e');
    }
  }

  /// 获取缓存状态信息
  Future<CacheStatus> getCacheStatus() async {
    final stats = await _cacheService.getCacheStats();
    final isOnline = await _cacheService.isNetworkAvailable();
    
    return CacheStatus(
      isOnline: isOnline,
      cacheStats: stats,
    );
  }

  /// 清除所有缓存数据
  Future<void> clearCache() async {
    await _cacheService.clearAllCache();
  }

  /// 在Isolate中运行的天气数据获取函数
  /// 这是多线程编程的核心实现
  static void _weatherDataIsolate(IsolateData data) async {
    try {
      // 构建API请求URL
      final weatherUri = Uri.parse(
        '${EnhancedWeatherService._weatherBaseUrl}'
        '?latitude=${data.latitude}&longitude=${data.longitude}'
        '&current=temperature_2m,wind_speed_10m,weathercode,relative_humidity_2m'
        '&timezone=auto',
      );

      final airQualityUri = Uri.parse(
        '${EnhancedWeatherService._airQualityBaseUrl}'
        '?latitude=${data.latitude}&longitude=${data.longitude}'
        '&current=pm2_5,pm10'
        '&timezone=auto',
      );

      // 并行请求天气和空气质量数据
      final responses = await Future.wait([
        http.get(weatherUri).timeout(const Duration(seconds: 10)),
        http.get(airQualityUri).timeout(const Duration(seconds: 10)),
      ]);

      final weatherResponse = responses[0];
      final airQualityResponse = responses[1];

      if (weatherResponse.statusCode != 200 || airQualityResponse.statusCode != 200) {
        throw Exception('API request failed');
      }

      // 解析响应数据
      final weatherData = jsonDecode(weatherResponse.body) as Map<String, dynamic>;
      final airQualityData = jsonDecode(airQualityResponse.body) as Map<String, dynamic>;

      final weatherCurrent = weatherData['current'] as Map<String, dynamic>?;
      final airQualityCurrent = airQualityData['current'] as Map<String, dynamic>?;

      // 构建结果对象
      final result = WeatherResult(
        temperatureC: (weatherCurrent?['temperature_2m'] as num?)?.toDouble(),
        windKmh: (weatherCurrent?['wind_speed_10m'] as num?)?.toDouble(),
        weatherCode: weatherCurrent?['weathercode'] as int?,
        humidity: (weatherCurrent?['relative_humidity_2m'] as num?)?.toDouble(),
        pm25: (airQualityCurrent?['pm2_5'] as num?)?.toDouble(),
        pm10: (airQualityCurrent?['pm10'] as num?)?.toDouble(),
        isFromCache: false,
      );

      // 发送结果回主线程
      data.sendPort.send(result);
    } catch (e) {
      // 发送错误回主线程
      data.sendPort.send(Exception('Isolate error: $e'));
    }
  }
}

/// Isolate数据传输类
class IsolateData {
  final SendPort sendPort;
  final double latitude;
  final double longitude;

  IsolateData({
    required this.sendPort,
    required this.latitude,
    required this.longitude,
  });
}

/// 天气趋势数据点
class WeatherTrendPoint {
  final DateTime date;
  final double? maxTemperature;
  final double? minTemperature;
  final double precipitation;

  WeatherTrendPoint({
    required this.date,
    this.maxTemperature,
    this.minTemperature,
    required this.precipitation,
  });
}

/// 缓存状态信息
class CacheStatus {
  final bool isOnline;
  final CacheStats cacheStats;

  CacheStatus({
    required this.isOnline,
    required this.cacheStats,
  });

  String get statusText {
    if (isOnline) {
      return 'Online - ${cacheStats.cacheCount} cached locations';
    } else {
      return 'Offline - Using cached data';
    }
  }
}