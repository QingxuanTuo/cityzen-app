import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cityzen/environment_data.dart';

/// 离线缓存服务 - 实现本地数据存储和离线模式支持
/// 这是多线程编程和本地缓存的核心实现
class OfflineCacheService {
  static const String _cacheKeyPrefix = 'cityzen_cache_';
  static const String _lastUpdateKey = 'last_update_timestamp';
  static const Duration _cacheValidDuration = Duration(hours: 2);
  
  // 单例模式
  static final OfflineCacheService _instance = OfflineCacheService._internal();
  factory OfflineCacheService() => _instance;
  OfflineCacheService._internal();

  /// 缓存环境数据到本地存储
  /// 使用异步操作避免阻塞UI线程
  Future<void> cacheEnvironmentData(
    String locationKey,
    EnvironmentData data,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cacheKeyPrefix$locationKey';
      
      // 序列化数据
      final jsonData = {
        'temperatureC': data.temperatureC,
        'windKmh': data.windKmh,
        'pm25': data.pm25,
        'pm10': data.pm10,
        'weatherCode': data.weatherCode,
        'humidity': data.humidity,
        'lastUpdated': data.lastUpdated.millisecondsSinceEpoch,
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
      };
      
      await prefs.setString(cacheKey, jsonEncode(jsonData));
      await prefs.setInt(_lastUpdateKey, DateTime.now().millisecondsSinceEpoch);
      
      // 同时保存到文件系统作为备份
      await _saveToFile(locationKey, jsonData);
    } catch (e) {
      print('Error caching environment data: $e');
    }
  }

  /// 从缓存获取环境数据
  /// 支持离线模式，当网络不可用时返回缓存数据
  Future<EnvironmentData?> getCachedEnvironmentData(String locationKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cacheKeyPrefix$locationKey';
      
      // 首先尝试从SharedPreferences获取
      String? cachedJson = prefs.getString(cacheKey);
      
      // 如果SharedPreferences中没有，尝试从文件系统获取
      cachedJson ??= await _loadFromFile(locationKey);
      
      if (cachedJson == null) return null;
      
      final jsonData = jsonDecode(cachedJson) as Map<String, dynamic>;
      
      // 检查缓存是否过期
      final cachedAt = DateTime.fromMillisecondsSinceEpoch(
        jsonData['cachedAt'] as int,
      );
      
      if (DateTime.now().difference(cachedAt) > _cacheValidDuration) {
        return null; // 缓存已过期
      }
      
      // 反序列化数据
      return EnvironmentData(
        temperatureC: (jsonData['temperatureC'] as num?)?.toDouble(),
        windKmh: (jsonData['windKmh'] as num?)?.toDouble(),
        pm25: (jsonData['pm25'] as num?)?.toDouble(),
        pm10: (jsonData['pm10'] as num?)?.toDouble(),
        weatherCode: jsonData['weatherCode'] as int?,
        humidity: (jsonData['humidity'] as num?)?.toDouble(),
        lastUpdated: DateTime.fromMillisecondsSinceEpoch(
          jsonData['lastUpdated'] as int,
        ),
      );
    } catch (e) {
      print('Error loading cached environment data: $e');
      return null;
    }
  }

  /// 检查是否有可用的缓存数据
  Future<bool> hasCachedData(String locationKey) async {
    final data = await getCachedEnvironmentData(locationKey);
    return data != null;
  }

  /// 获取缓存数据的年龄
  Future<Duration?> getCacheAge(String locationKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cacheKeyPrefix$locationKey';
      final cachedJson = prefs.getString(cacheKey);
      
      if (cachedJson == null) return null;
      
      final jsonData = jsonDecode(cachedJson) as Map<String, dynamic>;
      final cachedAt = DateTime.fromMillisecondsSinceEpoch(
        jsonData['cachedAt'] as int,
      );
      
      return DateTime.now().difference(cachedAt);
    } catch (e) {
      return null;
    }
  }

  /// 清除指定位置的缓存
  Future<void> clearCache(String locationKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cacheKeyPrefix$locationKey';
      await prefs.remove(cacheKey);
      
      // 同时删除文件系统中的缓存
      await _deleteFile(locationKey);
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }

  /// 清除所有缓存
  Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      for (final key in keys) {
        if (key.startsWith(_cacheKeyPrefix)) {
          await prefs.remove(key);
        }
      }
      
      await prefs.remove(_lastUpdateKey);
      
      // 清除文件系统缓存
      await _clearAllFiles();
    } catch (e) {
      print('Error clearing all cache: $e');
    }
  }

  /// 获取缓存统计信息
  Future<CacheStats> getCacheStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      int cacheCount = 0;
      int totalSize = 0;
      DateTime? lastUpdate;
      
      for (final key in keys) {
        if (key.startsWith(_cacheKeyPrefix)) {
          cacheCount++;
          final value = prefs.getString(key);
          if (value != null) {
            totalSize += value.length;
          }
        }
      }
      
      final lastUpdateTimestamp = prefs.getInt(_lastUpdateKey);
      if (lastUpdateTimestamp != null) {
        lastUpdate = DateTime.fromMillisecondsSinceEpoch(lastUpdateTimestamp);
      }
      
      return CacheStats(
        cacheCount: cacheCount,
        totalSizeBytes: totalSize,
        lastUpdate: lastUpdate,
      );
    } catch (e) {
      return CacheStats(cacheCount: 0, totalSizeBytes: 0, lastUpdate: null);
    }
  }

  /// 保存数据到文件系统（作为SharedPreferences的备份）
  Future<void> _saveToFile(String locationKey, Map<String, dynamic> data) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/cache_$locationKey.json');
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      print('Error saving to file: $e');
    }
  }

  /// 从文件系统加载数据
  Future<String?> _loadFromFile(String locationKey) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/cache_$locationKey.json');
      
      if (await file.exists()) {
        return await file.readAsString();
      }
      return null;
    } catch (e) {
      print('Error loading from file: $e');
      return null;
    }
  }

  /// 删除指定的缓存文件
  Future<void> _deleteFile(String locationKey) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/cache_$locationKey.json');
      
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Error deleting file: $e');
    }
  }

  /// 清除所有缓存文件
  Future<void> _clearAllFiles() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final files = directory.listSync();
      
      for (final file in files) {
        if (file is File && file.path.contains('cache_') && file.path.endsWith('.json')) {
          await file.delete();
        }
      }
    } catch (e) {
      print('Error clearing all files: $e');
    }
  }

  /// 检查网络连接状态
  Future<bool> isNetworkAvailable() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  /// 批量缓存多个位置的数据（多线程处理）
  Future<void> batchCacheData(Map<String, EnvironmentData> dataMap) async {
    final futures = <Future<void>>[];
    
    for (final entry in dataMap.entries) {
      futures.add(cacheEnvironmentData(entry.key, entry.value));
    }
    
    // 并行执行所有缓存操作
    await Future.wait(futures);
  }
}

/// 缓存统计信息
class CacheStats {
  final int cacheCount;
  final int totalSizeBytes;
  final DateTime? lastUpdate;

  CacheStats({
    required this.cacheCount,
    required this.totalSizeBytes,
    required this.lastUpdate,
  });

  String get formattedSize {
    if (totalSizeBytes < 1024) {
      return '$totalSizeBytes B';
    } else if (totalSizeBytes < 1024 * 1024) {
      return '${(totalSizeBytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(totalSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  String get formattedLastUpdate {
    if (lastUpdate == null) return 'Never';
    
    final now = DateTime.now();
    final difference = now.difference(lastUpdate!);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }
}