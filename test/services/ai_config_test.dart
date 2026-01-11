import 'package:flutter_test/flutter_test.dart';
import 'package:cityzen/ai_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AIConfigManager Tests', () {
    late AIConfigManager configManager;

    setUp(() {
      configManager = AIConfigManager();
      // Initialize SharedPreferences with empty values for testing
      SharedPreferences.setMockInitialValues({});
    });

    test('should initialize with default values', () {
      // Assert
      expect(configManager.currentProvider, equals(AIProvider.gemini));
      expect(configManager.apiKey, isEmpty);
      expect(configManager.model, equals(AIProvider.gemini.defaultModel));
      expect(configManager.baseUrl, isEmpty);
      expect(configManager.isConfigured, isFalse);
    });

    test('should validate Gemini API key format correctly', () {
      // Test valid Gemini API key
      expect(
        configManager.validateApiKey('AIzaSyDummyKeyForTesting123456789', AIProvider.gemini),
        isTrue,
      );

      // Test invalid Gemini API key - wrong prefix
      expect(
        configManager.validateApiKey('sk-invalid-key', AIProvider.gemini),
        isFalse,
      );

      // Test invalid Gemini API key - too short
      expect(
        configManager.validateApiKey('AIza123', AIProvider.gemini),
        isFalse,
      );

      // Test empty key
      expect(
        configManager.validateApiKey('', AIProvider.gemini),
        isFalse,
      );
    });

    test('should validate OpenAI API key format correctly', () {
      // Test valid OpenAI API key
      expect(
        configManager.validateApiKey('sk-1234567890abcdef1234567890abcdef', AIProvider.openai),
        isTrue,
      );

      // Test invalid OpenAI API key - wrong prefix
      expect(
        configManager.validateApiKey('AIza-invalid-key', AIProvider.openai),
        isFalse,
      );

      // Test invalid OpenAI API key - too short
      expect(
        configManager.validateApiKey('sk-123', AIProvider.openai),
        isFalse,
      );
    });

    test('should validate Claude API key format correctly', () {
      // Test valid Claude API key
      expect(
        configManager.validateApiKey('sk-ant-1234567890abcdef1234567890abcdef', AIProvider.claude),
        isTrue,
      );

      // Test invalid Claude API key - wrong prefix
      expect(
        configManager.validateApiKey('sk-invalid-key', AIProvider.claude),
        isFalse,
      );

      // Test invalid Claude API key - too short
      expect(
        configManager.validateApiKey('sk-ant-123', AIProvider.claude),
        isFalse,
      );
    });

    test('should return correct API endpoints for each provider', () async {
      // Create a fresh instance for testing
      final configManager = AIConfigManager();
      
      // Clear any existing configuration
      await configManager.clearConfig();
      
      // Test Gemini endpoint (default)
      expect(
        configManager.getApiEndpoint(),
        equals('https://generativelanguage.googleapis.com/v1beta/models'),
      );

      // Test OpenAI endpoint
      await configManager.saveConfig(provider: AIProvider.openai);
      expect(
        configManager.getApiEndpoint(),
        equals('https://api.openai.com/v1/chat/completions'),
      );

      // Test Claude endpoint
      await configManager.saveConfig(provider: AIProvider.claude);
      expect(
        configManager.getApiEndpoint(),
        equals('https://api.anthropic.com/v1/messages'),
      );
    });

    test('should return custom base URL when provided', () async {
      // Arrange
      final configManager = AIConfigManager();
      await configManager.clearConfig();
      const customUrl = 'https://custom-api.example.com';

      // Act
      await configManager.saveConfig(baseUrl: customUrl);

      // Assert
      expect(configManager.getApiEndpoint(), equals(customUrl));
    });

    test('should return correct configuration hints', () {
      // Test Gemini hint
      expect(
        configManager.getConfigHint(AIProvider.gemini),
        contains('Google AI Studio'),
      );

      // Test OpenAI hint
      expect(
        configManager.getConfigHint(AIProvider.openai),
        contains('OpenAI Platform'),
      );

      // Test Claude hint
      expect(
        configManager.getConfigHint(AIProvider.claude),
        contains('Anthropic Console'),
      );
    });

    test('should use custom model when provided', () async {
      // Arrange
      final configManager = AIConfigManager();
      await configManager.clearConfig();
      const customModel = 'custom-model-v2';

      // Act
      await configManager.saveConfig(customModel: customModel);

      // Assert
      expect(configManager.model, equals(customModel));
    });

    test('should use default model when custom model is empty', () async {
      // Arrange
      final configManager = AIConfigManager();
      await configManager.clearConfig();
      
      // Act
      await configManager.saveConfig(
        provider: AIProvider.openai,
        customModel: '',
      );

      // Assert
      expect(configManager.model, equals(AIProvider.openai.defaultModel));
    });

    test('should mark as configured when API key is provided', () async {
      // Arrange
      const validApiKey = 'AIzaSyDummyKeyForTesting123456789';

      // Act
      await configManager.saveConfig(apiKey: validApiKey);

      // Assert
      expect(configManager.isConfigured, isTrue);
      expect(configManager.apiKey, equals(validApiKey));
    });

    test('should mark as not configured when API key is empty', () async {
      // Act
      await configManager.saveConfig(apiKey: '');

      // Assert
      expect(configManager.isConfigured, isFalse);
    });

    test('should clear all configuration correctly', () async {
      // Arrange - Set some configuration first
      await configManager.saveConfig(
        provider: AIProvider.openai,
        apiKey: 'sk-test-key-123456789012345678901234',
        customModel: 'custom-model',
        baseUrl: 'https://custom.api.com',
      );

      // Act
      await configManager.clearConfig();

      // Assert
      expect(configManager.currentProvider, equals(AIProvider.gemini));
      expect(configManager.apiKey, isEmpty);
      expect(configManager.model, equals(AIProvider.gemini.defaultModel));
      expect(configManager.baseUrl, isEmpty);
      expect(configManager.isConfigured, isFalse);
    });
  });

  group('AIProvider Enum Tests', () {
    test('should have correct display names', () {
      expect(AIProvider.gemini.displayName, equals('Google Gemini'));
      expect(AIProvider.openai.displayName, equals('OpenAI GPT'));
      expect(AIProvider.claude.displayName, equals('Anthropic Claude'));
    });

    test('should have correct default models', () {
      expect(AIProvider.gemini.defaultModel, equals('models/gemini-3-flash-preview'));
      expect(AIProvider.openai.defaultModel, equals('gpt-4o-mini'));
      expect(AIProvider.claude.defaultModel, equals('claude-3-haiku-20240307'));
    });

    test('should have all expected providers', () {
      expect(AIProvider.values.length, equals(3));
      expect(AIProvider.values, contains(AIProvider.gemini));
      expect(AIProvider.values, contains(AIProvider.openai));
      expect(AIProvider.values, contains(AIProvider.claude));
    });
  });
}