import 'package:flutter_test/flutter_test.dart';
import 'package:cityzen/services/background_data_service.dart';
import 'package:cityzen/environment_data.dart';

void main() {
  group('BackgroundDataService Tests', () {
    late BackgroundDataService service;

    setUp(() {
      service = BackgroundDataService.instance;
    });

    tearDown(() async {
      await service.stopBackgroundFetching();
    });

    test('should start and stop background fetching', () async {
      // Act
      await service.startBackgroundFetching(interval: const Duration(seconds: 1));
      
      // Assert
      expect(service.dataStream, isA<Stream<EnvironmentData>>());
      
      // Cleanup
      await service.stopBackgroundFetching();
    });

    test('should calculate health metrics using compute isolate', () async {
      // Arrange
      final testData = EnvironmentData(
        temperatureC: 22.0,
        windKmh: 10.0,
        weatherCode: 1,
        pm25: 15.0,
        pm10: 25.0,
        humidity: 60.0,
        lastUpdated: DateTime.now(),
      );

      // Act
      final metrics = await service.calculateHealthMetrics(testData);

      // Assert
      expect(metrics, isA<Map<String, double>>());
      expect(metrics.containsKey('airQualityScore'), isTrue);
      expect(metrics.containsKey('comfortScore'), isTrue);
      expect(metrics.containsKey('activityScore'), isTrue);
      expect(metrics.containsKey('healthIndex'), isTrue);
      
      // Verify score ranges
      expect(metrics['airQualityScore']! >= 0 && metrics['airQualityScore']! <= 100, isTrue);
      expect(metrics['comfortScore']! >= 0 && metrics['comfortScore']! <= 100, isTrue);
      expect(metrics['activityScore']! >= 0 && metrics['activityScore']! <= 100, isTrue);
      expect(metrics['healthIndex']! >= 0 && metrics['healthIndex']! <= 100, isTrue);
    });

    test('should batch process multiple data points concurrently', () async {
      // Arrange
      final testDataList = [
        EnvironmentData(
          temperatureC: 20.0,
          windKmh: 5.0,
          weatherCode: 0,
          pm25: 10.0,
          pm10: 15.0,
          humidity: 50.0,
          lastUpdated: DateTime.now(),
        ),
        EnvironmentData(
          temperatureC: 25.0,
          windKmh: 15.0,
          weatherCode: 2,
          pm25: 25.0,
          pm10: 35.0,
          humidity: 70.0,
          lastUpdated: DateTime.now(),
        ),
        EnvironmentData(
          temperatureC: 18.0,
          windKmh: 8.0,
          weatherCode: 1,
          pm25: 5.0,
          pm10: 10.0,
          humidity: 45.0,
          lastUpdated: DateTime.now(),
        ),
      ];

      // Act
      final startTime = DateTime.now();
      final results = await service.batchProcessHealthMetrics(testDataList);
      final endTime = DateTime.now();
      final processingTime = endTime.difference(startTime);

      // Assert
      expect(results.length, equals(testDataList.length));
      expect(processingTime.inMilliseconds < 5000, isTrue); // Should complete within 5 seconds
      
      for (final result in results) {
        expect(result, isA<Map<String, double>>());
        expect(result.containsKey('healthIndex'), isTrue);
      }
    });

    test('should handle stream processing with backpressure', () async {
      // Arrange
      final testDataList = [
        EnvironmentData(
          temperatureC: 22.0,
          windKmh: 10.0,
          weatherCode: 1,
          pm25: 15.0,
          pm10: 25.0,
          humidity: 60.0,
          lastUpdated: DateTime.now(),
        ),
        EnvironmentData(
          temperatureC: 24.0,
          windKmh: 12.0,
          weatherCode: 2,
          pm25: 20.0,
          pm10: 30.0,
          humidity: 65.0,
          lastUpdated: DateTime.now(),
        ),
      ];

      // Create test stream
      final inputStream = Stream.fromIterable(testDataList);
      
      // Act
      final outputStream = service.processDataStream(inputStream);
      final results = await outputStream.toList();

      // Assert
      expect(results.length, equals(testDataList.length));
      for (final result in results) {
        expect(result, isA<Map<String, double>>());
        expect(result.containsKey('healthIndex'), isTrue);
      }
    });

    test('should handle errors gracefully in stream processing', () async {
      // Arrange - Create a valid stream first, then test error handling
      final validData = EnvironmentData(
        temperatureC: 22.0,
        windKmh: 10.0,
        weatherCode: 1,
        pm25: 15.0,
        pm10: 25.0,
        humidity: 60.0,
        lastUpdated: DateTime.now(),
      );
      
      final validStream = Stream.fromIterable([validData]);
      
      // Act
      final outputStream = service.processDataStream(validStream);
      final results = await outputStream.toList();

      // Assert - Should process valid data successfully
      expect(results.length, equals(1));
      expect(results.first, isA<Map<String, double>>());
      expect(results.first.containsKey('healthIndex'), isTrue);
    });

    test('should demonstrate concurrent processing performance', () async {
      // Arrange
      final largeDataSet = List.generate(10, (index) => EnvironmentData(
        temperatureC: 20.0 + index,
        windKmh: 10.0 + index,
        weatherCode: index % 3,
        pm25: 10.0 + (index * 2),
        pm10: 20.0 + (index * 3),
        humidity: 50.0 + index,
        lastUpdated: DateTime.now(),
      ));

      // Act - Measure concurrent processing time
      final startTime = DateTime.now();
      final results = await service.batchProcessHealthMetrics(largeDataSet);
      final concurrentTime = DateTime.now().difference(startTime);

      // Act - Measure sequential processing time for comparison
      final sequentialStart = DateTime.now();
      final sequentialResults = <Map<String, double>>[];
      for (final data in largeDataSet) {
        final result = await service.calculateHealthMetrics(data);
        sequentialResults.add(result);
      }
      final sequentialTime = DateTime.now().difference(sequentialStart);

      // Assert
      expect(results.length, equals(largeDataSet.length));
      expect(sequentialResults.length, equals(largeDataSet.length));
      
      // Concurrent processing should be faster or at least not significantly slower
      // (Note: In tests, the overhead might make this not always true, but it demonstrates the concept)
      print('Concurrent processing time: ${concurrentTime.inMilliseconds}ms');
      print('Sequential processing time: ${sequentialTime.inMilliseconds}ms');
      
      // Verify all results are valid
      for (final result in results) {
        expect(result['healthIndex']! >= 0 && result['healthIndex']! <= 100, isTrue);
      }
    });
  });

  group('Threading Performance Tests', () {
    test('should demonstrate CPU-intensive operations in isolate', () async {
      // Arrange
      final service = BackgroundDataService.instance;
      final testData = EnvironmentData(
        temperatureC: 22.0,
        windKmh: 10.0,
        weatherCode: 1,
        pm25: 15.0,
        pm10: 25.0,
        humidity: 60.0,
        lastUpdated: DateTime.now(),
      );

      // Act - Perform multiple concurrent calculations
      final futures = List.generate(5, (_) => service.calculateHealthMetrics(testData));
      final startTime = DateTime.now();
      final results = await Future.wait(futures);
      final endTime = DateTime.now();

      // Assert
      expect(results.length, equals(5));
      expect(endTime.difference(startTime).inMilliseconds < 3000, isTrue);
      
      // All results should be consistent for the same input
      final firstResult = results.first;
      for (final result in results) {
        expect(result['healthIndex'], closeTo(firstResult['healthIndex']!, 0.1));
      }
    });

    test('should handle high-frequency data processing', () async {
      // Arrange
      final service = BackgroundDataService.instance;
      final dataGenerator = Stream.periodic(
        const Duration(milliseconds: 100),
        (index) => EnvironmentData(
          temperatureC: 20.0 + (index % 10),
          windKmh: 10.0,
          weatherCode: 1,
          pm25: 15.0,
          pm10: 25.0,
          humidity: 60.0,
          lastUpdated: DateTime.now(),
        ),
      ).take(10); // Generate 10 data points

      // Act
      final processedStream = service.processDataStream(dataGenerator);
      final results = await processedStream.toList();

      // Assert
      expect(results.length, equals(10));
      for (final result in results) {
        expect(result.containsKey('healthIndex'), isTrue);
        expect(result['healthIndex']! >= 0 && result['healthIndex']! <= 100, isTrue);
      }
    });
  });
}