import 'package:flutter_test/flutter_test.dart';
import 'package:cityzen/environment_data.dart';

void main() {
  group('EnvironmentDataManager Tests', () {
    test('should create WeatherResult from valid data', () {
      // Arrange
      const temperatureC = 22.5;
      const windKmh = 15.2;
      const weatherCode = 0;
      const pm25 = 12.3;
      const pm10 = 18.7;
      const humidity = 65.0;

      // Act
      final result = WeatherResult(
        temperatureC: temperatureC,
        windKmh: windKmh,
        weatherCode: weatherCode,
        pm25: pm25,
        pm10: pm10,
        humidity: humidity,
      );

      // Assert
      expect(result.temperatureC, equals(temperatureC));
      expect(result.windKmh, equals(windKmh));
      expect(result.weatherCode, equals(weatherCode));
      expect(result.pm25, equals(pm25));
      expect(result.pm10, equals(pm10));
      expect(result.humidity, equals(humidity));
    });

    test('should handle null values in WeatherResult', () {
      // Act
      final result = WeatherResult(
        temperatureC: null,
        windKmh: null,
        weatherCode: null,
        pm25: null,
        pm10: null,
        humidity: null,
      );

      // Assert
      expect(result.temperatureC, isNull);
      expect(result.windKmh, isNull);
      expect(result.weatherCode, isNull);
      expect(result.pm25, isNull);
      expect(result.pm10, isNull);
      expect(result.humidity, isNull);
    });

    test('should create EnvironmentData from WeatherResult', () {
      // Arrange
      final weatherResult = WeatherResult(
        temperatureC: 25.0,
        windKmh: 10.5,
        weatherCode: 1,
        pm25: 15.2,
        pm10: 22.8,
        humidity: 70.0,
      );

      // Act
      final envData = EnvironmentData.fromWeatherResult(weatherResult);

      // Assert
      expect(envData.temperatureC, equals(25.0));
      expect(envData.windKmh, equals(10.5));
      expect(envData.weatherCode, equals(1));
      expect(envData.pm25, equals(15.2));
      expect(envData.pm10, equals(22.8));
      expect(envData.humidity, equals(70.0));
      expect(envData.lastUpdated, isA<DateTime>());
    });

    test('should update current data and notify listeners', () {
      // Arrange
      final manager = EnvironmentDataManager();
      var notificationCount = 0;
      manager.addListener(() {
        notificationCount++;
      });

      final envData = EnvironmentData(
        temperatureC: 20.0,
        windKmh: 8.0,
        weatherCode: 2,
        pm25: 10.0,
        pm10: 15.0,
        humidity: 60.0,
        lastUpdated: DateTime.now(),
      );

      // Act
      manager.updateData(envData);

      // Assert
      expect(manager.currentData, equals(envData));
      expect(notificationCount, equals(1));
    });

    test('should detect stale data correctly', () {
      // Arrange
      final manager = EnvironmentDataManager();
      final oldTimestamp = DateTime.now().subtract(const Duration(hours: 2));
      final staleData = EnvironmentData(
        temperatureC: 20.0,
        windKmh: 8.0,
        weatherCode: 2,
        pm25: 10.0,
        pm10: 15.0,
        humidity: 60.0,
        lastUpdated: oldTimestamp,
      );

      // Act
      manager.updateData(staleData);

      // Assert
      expect(manager.isDataStale, isTrue);
    });

    test('should detect fresh data correctly', () {
      // Arrange
      final manager = EnvironmentDataManager();
      final freshTimestamp = DateTime.now().subtract(const Duration(minutes: 10));
      final freshData = EnvironmentData(
        temperatureC: 20.0,
        windKmh: 8.0,
        weatherCode: 2,
        pm25: 10.0,
        pm10: 15.0,
        humidity: 60.0,
        lastUpdated: freshTimestamp,
      );

      // Act
      manager.updateData(freshData);

      // Assert
      expect(manager.isDataStale, isFalse);
    });
  });

  group('EnvironmentData Tests', () {
    test('should create EnvironmentData with all parameters', () {
      // Arrange
      final timestamp = DateTime.now();
      
      // Act
      final envData = EnvironmentData(
        temperatureC: 23.5,
        windKmh: 12.0,
        weatherCode: 1,
        pm25: 8.5,
        pm10: 14.2,
        humidity: 68.0,
        lastUpdated: timestamp,
      );

      // Assert
      expect(envData.temperatureC, equals(23.5));
      expect(envData.windKmh, equals(12.0));
      expect(envData.weatherCode, equals(1));
      expect(envData.pm25, equals(8.5));
      expect(envData.pm10, equals(14.2));
      expect(envData.humidity, equals(68.0));
      expect(envData.lastUpdated, equals(timestamp));
    });

    test('should handle null values in EnvironmentData', () {
      // Arrange
      final timestamp = DateTime.now();
      
      // Act
      final envData = EnvironmentData(
        temperatureC: null,
        windKmh: null,
        weatherCode: null,
        pm25: null,
        pm10: null,
        humidity: null,
        lastUpdated: timestamp,
      );

      // Assert
      expect(envData.temperatureC, isNull);
      expect(envData.windKmh, isNull);
      expect(envData.weatherCode, isNull);
      expect(envData.pm25, isNull);
      expect(envData.pm10, isNull);
      expect(envData.humidity, isNull);
      expect(envData.lastUpdated, equals(timestamp));
    });

    test('should create WeatherResult from EnvironmentData', () {
      // Arrange
      final envData = EnvironmentData(
        temperatureC: 18.5,
        windKmh: 7.2,
        weatherCode: 3,
        pm25: 22.1,
        pm10: 35.8,
        humidity: 75.0,
        lastUpdated: DateTime.now(),
      );

      // Act
      final weatherResult = WeatherResult.fromEnvironmentData(envData, isFromCache: true);

      // Assert
      expect(weatherResult.temperatureC, equals(18.5));
      expect(weatherResult.windKmh, equals(7.2));
      expect(weatherResult.weatherCode, equals(3));
      expect(weatherResult.pm25, equals(22.1));
      expect(weatherResult.pm10, equals(35.8));
      expect(weatherResult.humidity, equals(75.0));
      expect(weatherResult.isFromCache, isTrue);
    });
  });
}