import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// AI服务提供商枚举
enum AIProvider {
  gemini('Google Gemini', 'models/gemini-3-flash-preview'),
  openai('OpenAI GPT', 'gpt-4o-mini'),
  claude('Anthropic Claude', 'claude-3-haiku-20240307'),
  ollama('Ollama (Local)', 'llama3.2');

  const AIProvider(this.displayName, this.defaultModel);
  final String displayName;
  final String defaultModel;
}

// AI配置管理器
class AIConfigManager extends ChangeNotifier {
  static final AIConfigManager _instance = AIConfigManager._internal();
  factory AIConfigManager() => _instance;
  AIConfigManager._internal();

  AIProvider _currentProvider = AIProvider.gemini;
  String _apiKey = '';
  String _customModel = '';
  String _baseUrl = '';
  bool _isConfigured = false;

  // Getters
  AIProvider get currentProvider => _currentProvider;
  String get apiKey => _apiKey;
  String get model => _customModel.isEmpty ? _currentProvider.defaultModel : _customModel;
  String get baseUrl => _baseUrl;
  bool get isConfigured => _isConfigured && _apiKey.isNotEmpty;

  // 加载配置
  Future<void> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    
    final providerIndex = prefs.getInt('ai_provider') ?? 0;
    _currentProvider = AIProvider.values[providerIndex];
    _apiKey = prefs.getString('ai_api_key') ?? '';
    _customModel = prefs.getString('ai_custom_model') ?? '';
    _baseUrl = prefs.getString('ai_base_url') ?? '';
    _isConfigured = prefs.getBool('ai_configured') ?? false;
    
    notifyListeners();
  }

  // 保存配置
  Future<void> saveConfig({
    AIProvider? provider,
    String? apiKey,
    String? customModel,
    String? baseUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (provider != null) {
      _currentProvider = provider;
      await prefs.setInt('ai_provider', provider.index);
    }
    
    if (apiKey != null) {
      _apiKey = apiKey;
      await prefs.setString('ai_api_key', apiKey);
    }
    
    if (customModel != null) {
      _customModel = customModel;
      await prefs.setString('ai_custom_model', customModel);
    }
    
    if (baseUrl != null) {
      _baseUrl = baseUrl;
      await prefs.setString('ai_base_url', baseUrl);
    }
    
    _isConfigured = _apiKey.isNotEmpty;
    await prefs.setBool('ai_configured', _isConfigured);
    
    notifyListeners();
  }

  // 清除配置
  Future<void> clearConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('ai_provider');
    await prefs.remove('ai_api_key');
    await prefs.remove('ai_custom_model');
    await prefs.remove('ai_base_url');
    await prefs.remove('ai_configured');
    
    _currentProvider = AIProvider.gemini;
    _apiKey = '';
    _customModel = '';
    _baseUrl = '';
    _isConfigured = false;
    
    notifyListeners();
  }

  // 获取API端点URL
  String getApiEndpoint() {
    if (_baseUrl.isNotEmpty) return _baseUrl;
    
    switch (_currentProvider) {
      case AIProvider.gemini:
        return 'https://generativelanguage.googleapis.com/v1beta/models';
      case AIProvider.openai:
        return 'https://api.openai.com/v1/chat/completions';
      case AIProvider.claude:
        return 'https://api.anthropic.com/v1/messages';
      case AIProvider.ollama:
        return 'http://localhost:11434/api/generate';
    }
  }

  // 验证API Key格式
  bool validateApiKey(String key, AIProvider provider) {
    if (key.isEmpty) return false;
    
    switch (provider) {
      case AIProvider.gemini:
        return key.startsWith('AIza') && key.length > 20;
      case AIProvider.openai:
        return key.startsWith('sk-') && key.length > 20;
      case AIProvider.claude:
        return key.startsWith('sk-ant-') && key.length > 20;
      case AIProvider.ollama:
        return true; // Ollama通常不需要API Key
    }
  }

  // 获取配置提示信息
  String getConfigHint(AIProvider provider) {
    switch (provider) {
      case AIProvider.gemini:
        return 'Get your API key from Google AI Studio (aistudio.google.com)';
      case AIProvider.openai:
        return 'Get your API key from OpenAI Platform (platform.openai.com)';
      case AIProvider.claude:
        return 'Get your API key from Anthropic Console (console.anthropic.com)';
      case AIProvider.ollama:
        return 'Make sure Ollama is running locally on port 11434';
    }
  }
}