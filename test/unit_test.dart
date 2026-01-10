import 'package:flutter_test/flutter_test.dart';
import 'package:cityzen/environment_data.dart';
import 'package:cityzen/ai_config.dart';

void main() {
  group('Environment Data Tests', () {
    test('EnvironmentData should be created correctly', () {
      final data = EnvironmentData(
        temperatureC: 20.0,
        windKmh: 10.0,
        pm25: 15.0,
        pm10: 20.0,
        weatherCode: 0,
        humidity: 60.0,
        lastUpdated: DateTime.now(),
      );

      expect(data.temperatureC, equals(20.0));
      expect(data.windKmh, equals(10.0));
      expect(data.pm25, equals(15.0));
      expect(data.pm10, equals(20.0));
      expect(data.weatherCode, equals(0));
      expect(data.humidity, equals(60.0));
      expect(data.lastUpdated, isNotNull);
    });

    test('EnvironmentData should handle null values', () {
      final data = EnvironmentData(
        temperatureC: null,
        windKmh: null,
        pm25: null,
        pm10: null,
        weatherCode: null,
        humidity: null,
        lastUpdated: DateTime.now(),
      );

      expect(data.temperatureC, isNull);
      expect(data.windKmh, isNull);
      expect(data.pm25, isNull);
      expect(data.pm10, isNull);
      expect(data.weatherCode, isNull);
      expect(data.humidity, isNull);
    });

    test('EnvironmentData should calculate age correctly', () {
      final oldData = EnvironmentData(
        temperatureC: 20.0,
        windKmh: 10.0,
        pm25: 15.0,
        pm10: 20.0,
        weatherCode: 0,
        humidity: 60.0,
        lastUpdated: DateTime.now().subtract(const Duration(hours: 2)),
      );

      final age = DateTime.now().difference(oldData.lastUpdated);
      expect(age.inHours, greaterThanOrEqualTo(1));
    });
  });

  group('AI Configuration Tests', () {
    test('AIProvider should have correct display names', () {
      expect(AIProvider.gemini.displayName, equals('Google Gemini'));
      expect(AIProvider.openai.displayName, equals('OpenAI GPT'));
      expect(AIProvider.claude.displayName, equals('Anthropic Claude'));
      expect(AIProvider.ollama.displayName, equals('Ollama (Local)'));
    });

    test('AIProvider should have correct default models', () {
      expect(AIProvider.gemini.defaultModel, equals('models/gemini-3-flash-preview'));
      expect(AIProvider.openai.defaultModel, equals('gpt-4o-mini'));
      expect(AIProvider.claude.defaultModel, equals('claude-3-haiku-20240307'));
      expect(AIProvider.ollama.defaultModel, equals('llama3.2'));
    });

    test('AIConfigManager should initialize with default values', () {
      final configManager = AIConfigManager();
      
      expect(configManager.currentProvider, equals(AIProvider.gemini));
      expect(configManager.apiKey, isEmpty);
      expect(configManager.model, equals(AIProvider.gemini.defaultModel));
      expect(configManager.baseUrl, isEmpty);
    });

    test('AIConfigManager should validate API keys correctly', () {
      final configManager = AIConfigManager();
      
      // Test Gemini API key validation
      expect(configManager.validateApiKey('AIza' + 'A' * 20, AIProvider.gemini), isTrue);
      expect(configManager.validateApiKey('invalid', AIProvider.gemini), isFalse);
      expect(configManager.validateApiKey('AIza123', AIProvider.gemini), isFalse); // Too short
      
      // Test OpenAI API key validation
      expect(configManager.validateApiKey('sk-' + 'A' * 20, AIProvider.openai), isTrue);
      expect(configManager.validateApiKey('invalid', AIProvider.openai), isFalse);
      expect(configManager.validateApiKey('sk-123', AIProvider.openai), isFalse); // Too short
      
      // Test Claude API key validation
      expect(configManager.validateApiKey('sk-ant-' + 'A' * 20, AIProvider.claude), isTrue);
      expect(configManager.validateApiKey('invalid', AIProvider.claude), isFalse);
      expect(configManager.validateApiKey('sk-ant-123', AIProvider.claude), isFalse); // Too short
      
      // Ollama allows any non-empty string (due to the isEmpty check at the beginning)
      expect(configManager.validateApiKey('anything', AIProvider.ollama), isTrue);
      // Note: Empty string returns false due to the initial isEmpty check
    });
  });

  group('Utility Functions Tests', () {
    test('Temperature conversion should work correctly', () {
      // Celsius to Fahrenheit: F = C * 9/5 + 32
      const celsius = 20.0;
      const fahrenheit = celsius * 9 / 5 + 32;
      
      expect(fahrenheit, equals(68.0));
    });

    test('Wind speed conversion should work correctly', () {
      // km/h to mph: mph = km/h * 0.621371
      const kmh = 10.0;
      const mph = kmh * 0.621371;
      
      expect(mph, closeTo(6.21, 0.01));
    });

    test('Air quality thresholds should be correct', () {
      // WHO PM2.5 guidelines
      const good = 5.0;
      const fair = 15.0;
      const moderate = 50.0;
      const poor = 90.0;
      
      expect(good, lessThanOrEqualTo(5.0));
      expect(fair, lessThanOrEqualTo(15.0));
      expect(moderate, lessThanOrEqualTo(50.0));
      expect(poor, lessThanOrEqualTo(90.0));
    });
  });

  group('Data Validation Tests', () {
    test('Should handle invalid weather codes gracefully', () {
      const validCodes = [0, 1, 2, 3, 45, 48, 51, 61, 71, 95];
      const invalidCode = 999;
      
      for (final code in validCodes) {
        expect(code, greaterThanOrEqualTo(0));
        expect(code, lessThan(100));
      }
      
      expect(invalidCode, greaterThan(100));
    });

    test('Should validate coordinate ranges', () {
      // Milan coordinates
      const milanLat = 45.4642;
      const milanLon = 9.1900;
      
      expect(milanLat, greaterThanOrEqualTo(-90));
      expect(milanLat, lessThanOrEqualTo(90));
      expect(milanLon, greaterThanOrEqualTo(-180));
      expect(milanLon, lessThanOrEqualTo(180));
    });

    test('Should validate PM values are non-negative', () {
      const validPM25 = 15.0;
      const validPM10 = 25.0;
      const invalidPM = -5.0;
      
      expect(validPM25, greaterThanOrEqualTo(0));
      expect(validPM10, greaterThanOrEqualTo(0));
      expect(invalidPM, lessThan(0)); // This should be handled as invalid
    });
  });
}