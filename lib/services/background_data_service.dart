import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:cityzen/environment_data.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Background data service that demonstrates multi-threading capabilities
/// Uses Isolates for CPU-intensive operations and prevents UI blocking
class BackgroundDataService {
  static BackgroundDataService? _instance;
  static BackgroundDataService get instance => _instance ??= BackgroundDataService._();
  
  BackgroundDataService._();

  Timer? _backgroundTimer;
  StreamController<EnvironmentData>? _dataStreamController;
  Isolate? _backgroundIsolate;
  ReceivePort? _receivePort;

  Stream<EnvironmentData> get dataStream => _dataStreamController?.stream ?? const Stream.empty();

  /// Start background data fetching with configurable interval
  Future<void> startBackgroundFetching({Duration interval = const Duration(minutes: 15)}) async {
    await stopBackgroundFetching();
    
    _dataStreamController = StreamController<EnvironmentData>.broadcast();
    
    // Start periodic timer for background data fetching
    _backgroundTimer = Timer.periodic(interval, (timer) {
      _fetchDataInBackground();
    });
    
    // Initial fetch
    _fetchDataInBackground();
    
    debugPrint('Background data service started with ${interval.inMinutes}min interval');
  }

  /// Stop background data fetching and cleanup resources
  Future<void> stopBackgroundFetching() async {
    _backgroundTimer?.cancel();
    _backgroundTimer = null;
    
    await _dataStreamController?.close();
    _dataStreamController = null;
    
    _backgroundIsolate?.kill(priority: Isolate.immediate);
    _backgroundIsolate = null;
    
    _receivePort?.close();
    _receivePort = null;
    
    debugPrint('Background data service stopped');
  }

  /// Fetch environmental data in background isolate to prevent UI blocking
  Future<void> _fetchDataInBackground() async {
    try {
      // Create receive port for isolate communication
      _receivePort = ReceivePort();
      
      // Spawn isolate for background processing
      _backgroundIsolate = await Isolate.spawn(
        _isolateEntryPoint,
        _receivePort!.sendPort,
      );
      
      // Listen for data from isolate
      _receivePort!.listen((dynamic data) {
        if (data is Map<String, dynamic>) {
          try {
            final envData = _parseEnvironmentData(data);
            _dataStreamController?.add(envData);
            debugPrint('Background data updated: PM2.5=${envData.pm25?.toStringAsFixed(1)}');
          } catch (e) {
            debugPrint('Error parsing background data: $e');
          }
        }
        
        // Cleanup isolate after processing
        _backgroundIsolate?.kill(priority: Isolate.immediate);
        _backgroundIsolate = null;
        _receivePort?.close();
        _receivePort = null;
      });
      
    } catch (e) {
      debugPrint('Background fetch error: $e');
    }
  }

  /// Isolate entry point for background data processing
  static void _isolateEntryPoint(SendPort sendPort) async {
    try {
      // Perform network requests in isolate
      const lat = 45.4809167;
      const lon = 9.2251111;

      final weatherUri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$lat&longitude=$lon'
        '&current=temperature_2m,wind_speed_10m,weathercode,relative_humidity_2m'
        '&timezone=auto',
      );

      final aqUri = Uri.parse(
        'https://air-quality-api.open-meteo.com/v1/air-quality'
        '?latitude=$lat&longitude=$lon'
        '&hourly=pm10,pm2_5'
        '&timezone=auto',
      );

      // Concurrent API calls for better performance
      final responses = await Future.wait([
        http.get(weatherUri).timeout(const Duration(seconds: 15)),
        http.get(aqUri).timeout(const Duration(seconds: 15)),
      ]);

      if (responses[0].statusCode == 200 && responses[1].statusCode == 200) {
        final weatherData = jsonDecode(responses[0].body);
        final aqData = jsonDecode(responses[1].body);
        
        // Process data in isolate (CPU-intensive operations)
        final processedData = _processDataInIsolate(weatherData, aqData);
        
        // Send processed data back to main isolate
        sendPort.send(processedData);
      } else {
        sendPort.send({'error': 'API request failed'});
      }
    } catch (e) {
      sendPort.send({'error': e.toString()});
    }
  }

  /// CPU-intensive data processing in isolate
  static Map<String, dynamic> _processDataInIsolate(
    Map<String, dynamic> weatherData,
    Map<String, dynamic> aqData,
  ) {
    final current = weatherData['current'] as Map<String, dynamic>?;
    final aqHourly = aqData['hourly'] as Map<String, dynamic>?;

    // Simulate CPU-intensive processing
    final pm25List = (aqHourly?['pm2_5'] as List?) ?? [];
    final pm10List = (aqHourly?['pm10'] as List?) ?? [];
    
    // Calculate moving averages (CPU-intensive)
    final pm25Avg = _calculateMovingAverage(pm25List.cast<num>(), 6);
    final pm10Avg = _calculateMovingAverage(pm10List.cast<num>(), 6);
    
    // Calculate air quality trends
    final pm25Trend = _calculateTrend(pm25List.cast<num>());
    final pm10Trend = _calculateTrend(pm10List.cast<num>());
    
    // Get latest values
    final pm25 = _getLatestValue(pm25List);
    final pm10 = _getLatestValue(pm10List);
    
    return {
      'temperatureC': (current?['temperature_2m'] as num?)?.toDouble(),
      'windKmh': (current?['wind_speed_10m'] as num?)?.toDouble(),
      'weatherCode': current?['weathercode'] as int?,
      'humidity': (current?['relative_humidity_2m'] as num?)?.toDouble(),
      'pm25': pm25,
      'pm10': pm10,
      'pm25Average': pm25Avg,
      'pm10Average': pm10Avg,
      'pm25Trend': pm25Trend,
      'pm10Trend': pm10Trend,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Calculate moving average (CPU-intensive operation)
  static double? _calculateMovingAverage(List<num> values, int windowSize) {
    if (values.isEmpty) return null;
    
    final validValues = values.where((v) => v is num && !v.isNaN).toList();
    if (validValues.isEmpty) return null;
    
    final window = validValues.length >= windowSize 
        ? validValues.sublist(validValues.length - windowSize)
        : validValues;
    
    final sum = window.fold<double>(0.0, (sum, value) => sum + value.toDouble());
    return sum / window.length;
  }

  /// Calculate trend direction (CPU-intensive operation)
  static String _calculateTrend(List<num> values) {
    if (values.length < 2) return 'stable';
    
    final validValues = values.where((v) => v is num && !v.isNaN).toList();
    if (validValues.length < 2) return 'stable';
    
    final recent = validValues.sublist((validValues.length * 0.7).round());
    final older = validValues.sublist(0, (validValues.length * 0.3).round());
    
    if (recent.isEmpty || older.isEmpty) return 'stable';
    
    final recentAvg = recent.fold<double>(0.0, (sum, v) => sum + v.toDouble()) / recent.length;
    final olderAvg = older.fold<double>(0.0, (sum, v) => sum + v.toDouble()) / older.length;
    
    final difference = recentAvg - olderAvg;
    const threshold = 2.0; // Threshold for trend detection
    
    if (difference > threshold) return 'increasing';
    if (difference < -threshold) return 'decreasing';
    return 'stable';
  }

  /// Get latest non-null value from list
  static double? _getLatestValue(List<dynamic> values) {
    for (var i = values.length - 1; i >= 0; i--) {
      final v = values[i];
      if (v is num && !v.isNaN) return v.toDouble();
    }
    return null;
  }

  /// Parse processed data from isolate into EnvironmentData
  EnvironmentData _parseEnvironmentData(Map<String, dynamic> data) {
    return EnvironmentData(
      temperatureC: data['temperatureC'] as double?,
      windKmh: data['windKmh'] as double?,
      weatherCode: data['weatherCode'] as int?,
      humidity: data['humidity'] as double?,
      pm25: data['pm25'] as double?,
      pm10: data['pm10'] as double?,
      lastUpdated: DateTime.parse(data['timestamp'] as String),
    );
  }

  /// Perform heavy computation in compute function (another threading approach)
  Future<Map<String, double>> calculateHealthMetrics(EnvironmentData data) async {
    return await compute(_computeHealthMetrics, data);
  }

  /// Heavy computation function for compute isolate
  static Map<String, double> _computeHealthMetrics(EnvironmentData data) {
    // Simulate complex health calculations
    final pm25 = data.pm25 ?? 0;
    final pm10 = data.pm10 ?? 0;
    final temp = data.temperatureC ?? 20;
    final humidity = data.humidity ?? 50;
    final wind = data.windKmh ?? 10;

    // Complex health score calculations (CPU-intensive)
    double airQualityScore = 100;
    if (pm25 > 0) {
      airQualityScore -= (pm25 * 2.5);
    }
    if (pm10 > 0) {
      airQualityScore -= (pm10 * 1.5);
    }
    airQualityScore = airQualityScore.clamp(0, 100);

    // Weather comfort score
    double comfortScore = 100;
    final tempDiff = (temp - 22).abs();
    comfortScore -= (tempDiff * 3);
    
    final humidityDiff = (humidity - 50).abs();
    comfortScore -= (humidityDiff * 0.5);
    
    comfortScore = comfortScore.clamp(0, 100);

    // Activity recommendation score
    double activityScore = (airQualityScore + comfortScore) / 2;
    if (wind > 20) activityScore -= 10; // High wind penalty
    if (temp < 5 || temp > 35) activityScore -= 20; // Extreme temperature penalty
    
    activityScore = activityScore.clamp(0, 100);

    // Overall health index (weighted average)
    final healthIndex = (airQualityScore * 0.5) + (comfortScore * 0.3) + (activityScore * 0.2);

    return {
      'airQualityScore': airQualityScore,
      'comfortScore': comfortScore,
      'activityScore': activityScore,
      'healthIndex': healthIndex,
    };
  }

  /// Batch process multiple data points concurrently
  Future<List<Map<String, double>>> batchProcessHealthMetrics(
    List<EnvironmentData> dataList,
  ) async {
    // Process multiple data points concurrently using Future.wait
    final futures = dataList.map((data) => calculateHealthMetrics(data));
    return await Future.wait(futures);
  }

  /// Stream-based data processing with backpressure handling
  Stream<Map<String, double>> processDataStream(Stream<EnvironmentData> inputStream) {
    return inputStream
        .asyncMap((data) => calculateHealthMetrics(data))
        .handleError((error) {
          debugPrint('Stream processing error: $error');
          return <String, double>{};
        });
  }
}