import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cityzen/ai_config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiAIService {
  final AIConfigManager _configManager = AIConfigManager();
  GenerativeModel? _geminiModel;
  
  GeminiAIService() {
    _initializeService();
  }

  Future<void> _initializeService() async {
    await _configManager.loadConfig();
    _setupGeminiModel();
  }

  void _setupGeminiModel() {
    if (_configManager.currentProvider == AIProvider.gemini && 
        _configManager.apiKey.isNotEmpty) {
      _geminiModel = GenerativeModel(
        model: _configManager.model,
        apiKey: _configManager.apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.8,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 2048,
        ),
      );
    }
  }

  // 刷新配置
  Future<void> refreshConfig() async {
    await _configManager.loadConfig();
    _setupGeminiModel();
  }

  Future<String> getWorkoutAdvice({
    required String userMessage,
    required double? pm25,
    required double? pm10,
    required double? windSpeed,
    required double? temperature,
    required int? weatherCode,
    required String city,
  }) async {
    // 检查AI配置
    if (!_configManager.isConfigured) {
      return "AI service not configured. Please set up your AI provider and API key in Settings.";
    }

    try {
      switch (_configManager.currentProvider) {
        case AIProvider.gemini:
          return await _callGeminiAPI(userMessage, pm25, pm10, windSpeed, temperature, weatherCode, city);
        case AIProvider.openai:
          return await _callOpenAIAPI(userMessage, pm25, pm10, windSpeed, temperature, weatherCode, city);
        case AIProvider.claude:
          return await _callClaudeAPI(userMessage, pm25, pm10, windSpeed, temperature, weatherCode, city);
        case AIProvider.ollama:
          return await _callOllamaAPI(userMessage, pm25, pm10, windSpeed, temperature, weatherCode, city);
      }
    } catch (e) {
      debugPrint('AI Service Error: $e');
      return _getSmartFallbackResponse(userMessage, pm25, windSpeed, temperature);
    }
  }

  Future<String> _callGeminiAPI(String userMessage, double? pm25, double? pm10, 
      double? windSpeed, double? temperature, int? weatherCode, String city) async {
    if (_geminiModel == null) {
      throw Exception('Gemini model not initialized');
    }

    final systemPrompt = _buildSystemPrompt(userMessage, pm25, pm10, windSpeed, temperature, weatherCode, city);
    final content = [Content.text(systemPrompt)];
    final response = await _geminiModel!.generateContent(content);
    
    return _formatAIResponse(response.text ?? 'Sorry, I couldn\'t generate a response right now. Please try again.');
  }

  Future<String> _callOpenAIAPI(String userMessage, double? pm25, double? pm10, 
      double? windSpeed, double? temperature, int? weatherCode, String city) async {
    
    final systemPrompt = _buildSystemPrompt(userMessage, pm25, pm10, windSpeed, temperature, weatherCode, city);
    
    final response = await http.post(
      Uri.parse(_configManager.getApiEndpoint()),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${_configManager.apiKey}',
      },
      body: jsonEncode({
        'model': _configManager.model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userMessage}
        ],
        'max_tokens': 500,
        'temperature': 0.8,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'];
      return _formatAIResponse(content);
    } else {
      throw Exception('OpenAI API Error: ${response.statusCode}');
    }
  }

  Future<String> _callClaudeAPI(String userMessage, double? pm25, double? pm10, 
      double? windSpeed, double? temperature, int? weatherCode, String city) async {
    
    final systemPrompt = _buildSystemPrompt(userMessage, pm25, pm10, windSpeed, temperature, weatherCode, city);
    
    final response = await http.post(
      Uri.parse(_configManager.getApiEndpoint()),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': _configManager.apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': _configManager.model,
        'max_tokens': 500,
        'system': systemPrompt,
        'messages': [
          {'role': 'user', 'content': userMessage}
        ],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['content'][0]['text'];
      return _formatAIResponse(content);
    } else {
      throw Exception('Claude API Error: ${response.statusCode}');
    }
  }

  Future<String> _callOllamaAPI(String userMessage, double? pm25, double? pm10, 
      double? windSpeed, double? temperature, int? weatherCode, String city) async {
    
    final systemPrompt = _buildSystemPrompt(userMessage, pm25, pm10, windSpeed, temperature, weatherCode, city);
    
    final response = await http.post(
      Uri.parse(_configManager.getApiEndpoint()),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'model': _configManager.model,
        'prompt': '$systemPrompt\n\nUser: $userMessage\nAssistant:',
        'stream': false,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return _formatAIResponse(data['response']);
    } else {
      throw Exception('Ollama API Error: ${response.statusCode}');
    }
  }

  String _buildSystemPrompt(String userMessage, double? pm25, double? pm10, 
      double? windSpeed, double? temperature, int? weatherCode, String city) {
    
    // 检测用户输入的语言和意图
    String detectedLanguage = _detectLanguage(userMessage);
    String languageInstruction = _getLanguageInstruction(detectedLanguage);
    String userIntent = _analyzeUserIntent(userMessage, detectedLanguage);
    
    return '''
You are CityZen's AI fitness coach. You are friendly, helpful, and adapt to the user's communication style and needs.

CURRENT CONDITIONS IN $city:
• PM2.5: ${pm25?.toStringAsFixed(1) ?? 'N/A'} µg/m³
• Temperature: ${temperature?.toStringAsFixed(1) ?? 'N/A'}°C
• Wind Speed: ${windSpeed?.toStringAsFixed(1) ?? 'N/A'} km/h

LANGUAGE REQUIREMENT:
$languageInstruction

USER INTENT ANALYSIS:
$userIntent

RESPONSE GUIDELINES:
1. MATCH THE USER'S COMMUNICATION STYLE - if they greet, greet back; if they ask casually, respond casually
2. Use simple paragraphs, no markdown formatting
3. Use bullet points with • symbol only when listing information
4. Keep sentences natural and conversational
5. Maximum 200 words total
6. Use emojis appropriately (1-3 per response)
7. No headers, no bold text, no special formatting

HEALTH GUIDELINES:
• PM2.5: Good <25, Moderate 25-50, Poor >50 µg/m³
• Always prioritize safety over performance

IMPORTANT: Respond naturally to the user's actual intent. If they greet you, greet them back. If they ask about weather, focus on weather. If they want exercise advice, give exercise advice. Be conversational and helpful.

USER MESSAGE: "$userMessage"

Respond appropriately in the same language and style as the user:''';
  }

  // 检测用户输入的语言
  String _detectLanguage(String text) {
    // 检测中文字符
    if (RegExp(r'[\u4e00-\u9fff]').hasMatch(text)) {
      return 'chinese';
    }
    // 检测日文字符
    else if (RegExp(r'[\u3040-\u309f\u30a0-\u30ff]').hasMatch(text)) {
      return 'japanese';
    }
    // 检测韩文字符
    else if (RegExp(r'[\uac00-\ud7af]').hasMatch(text)) {
      return 'korean';
    }
    // 检测西班牙语特征词汇
    else if (RegExp(r'(hola|gracias|buenos)', caseSensitive: false).hasMatch(text)) {
      return 'spanish';
    }
    // 检测法语特征词汇
    else if (RegExp(r'(bonjour|merci|bonsoir)', caseSensitive: false).hasMatch(text)) {
      return 'french';
    }
    // 检测德语特征词汇
    else if (RegExp(r'(hallo|danke|guten)', caseSensitive: false).hasMatch(text)) {
      return 'german';
    }
    // 检测意大利语特征词汇
    else if (RegExp(r'(ciao|grazie|buongiorno)', caseSensitive: false).hasMatch(text)) {
      return 'italian';
    }
    // 默认为英语
    else {
      return 'english';
    }
  }

  // 分析用户意图
  String _analyzeUserIntent(String userMessage, String language) {
    final message = userMessage.toLowerCase();
    
    // 问候语检测
    if (_isGreeting(message, language)) {
      return "USER INTENT: Greeting - The user is saying hello or greeting you. Respond with a friendly greeting back and briefly introduce yourself as their AI fitness coach.";
    }
    
    // 运动相关询问
    if (_isExerciseQuery(message, language)) {
      return "USER INTENT: Exercise Inquiry - The user is asking about specific exercises or workout recommendations. Provide detailed exercise advice based on current conditions.";
    }
    
    // 天气/环境询问
    if (_isWeatherQuery(message, language)) {
      return "USER INTENT: Weather/Environment Inquiry - The user wants to know about current weather or air quality conditions. Focus on environmental data and its impact on activities.";
    }
    
    // 时间相关询问
    if (_isTimeQuery(message, language)) {
      return "USER INTENT: Timing Question - The user is asking about when to exercise or best times for activities. Provide time-specific recommendations.";
    }
    
    // 健康/安全询问
    if (_isHealthQuery(message, language)) {
      return "USER INTENT: Health/Safety Concern - The user is asking about health impacts or safety considerations. Focus on health advice and safety precautions.";
    }
    
    // 闲聊/一般对话
    if (_isCasualChat(message, language)) {
      return "USER INTENT: Casual Conversation - The user is making casual conversation. Respond naturally and try to steer toward helpful fitness/health topics if appropriate.";
    }
    
    // 默认：健身建议请求
    return "USER INTENT: General Fitness Advice - The user seems to be looking for general fitness or activity recommendations. Provide comprehensive advice based on current conditions.";
  }

  // 检测问候语
  bool _isGreeting(String message, String language) {
    switch (language) {
      case 'chinese':
        return RegExp(r'(你好|您好|hi|hello|嗨|早上好|下午好|晚上好|哈喽)').hasMatch(message);
      case 'japanese':
        return RegExp(r'(こんにちは|おはよう|こんばんは|はじめまして|hello|hi)').hasMatch(message);
      case 'korean':
        return RegExp(r'(안녕|안녕하세요|hello|hi)').hasMatch(message);
      case 'spanish':
        return RegExp(r'(hola|buenos días|buenas tardes|buenas noches|hello|hi)').hasMatch(message);
      case 'french':
        return RegExp(r'(bonjour|bonsoir|salut|hello|hi)').hasMatch(message);
      case 'german':
        return RegExp(r'(hallo|guten tag|guten morgen|guten abend|hello|hi)').hasMatch(message);
      case 'italian':
        return RegExp(r'(ciao|buongiorno|buonasera|hello|hi)').hasMatch(message);
      default:
        return RegExp(r'(hello|hi|hey|good morning|good afternoon|good evening|greetings)').hasMatch(message);
    }
  }

  // 检测运动询问
  bool _isExerciseQuery(String message, String language) {
    switch (language) {
      case 'chinese':
        return RegExp(r'(跑步|运动|锻炼|健身|骑车|瑜伽|游泳|适合|推荐|什么运动)').hasMatch(message);
      case 'japanese':
        return RegExp(r'(運動|ランニング|サイクリング|ヨガ|フィットネス|おすすめ)').hasMatch(message);
      case 'korean':
        return RegExp(r'(운동|달리기|사이클링|요가|피트니스|추천)').hasMatch(message);
      case 'spanish':
        return RegExp(r'(ejercicio|correr|ciclismo|yoga|fitness|recomend)').hasMatch(message);
      case 'french':
        return RegExp(r'(exercice|course|cyclisme|yoga|fitness|recommand)').hasMatch(message);
      case 'german':
        return RegExp(r'(übung|laufen|radfahren|yoga|fitness|empfehl)').hasMatch(message);
      case 'italian':
        return RegExp(r'(esercizio|correre|ciclismo|yoga|fitness|raccomand)').hasMatch(message);
      default:
        return RegExp(r'(exercise|workout|running|cycling|yoga|fitness|recommend|activity|sport)').hasMatch(message);
    }
  }

  // 检测天气询问
  bool _isWeatherQuery(String message, String language) {
    switch (language) {
      case 'chinese':
        return RegExp(r'(天气|空气|质量|温度|风速|pm2\.5|环境|污染)').hasMatch(message);
      case 'japanese':
        return RegExp(r'(天気|空気|品質|温度|風速|環境|汚染)').hasMatch(message);
      case 'korean':
        return RegExp(r'(날씨|공기|품질|온도|풍속|환경|오염)').hasMatch(message);
      case 'spanish':
        return RegExp(r'(tiempo|aire|calidad|temperatura|viento|ambiente|contaminación)').hasMatch(message);
      case 'french':
        return RegExp(r'(temps|air|qualité|température|vent|environnement|pollution)').hasMatch(message);
      case 'german':
        return RegExp(r'(wetter|luft|qualität|temperatur|wind|umwelt|verschmutzung)').hasMatch(message);
      case 'italian':
        return RegExp(r'(tempo|aria|qualità|temperatura|vento|ambiente|inquinamento)').hasMatch(message);
      default:
        return RegExp(r'(weather|air quality|temperature|wind|environment|pollution|pm2\.5)').hasMatch(message);
    }
  }

  // 检测时间询问
  bool _isTimeQuery(String message, String language) {
    switch (language) {
      case 'chinese':
        return RegExp(r'(什么时候|时间|几点|早上|下午|晚上|现在|最佳时间)').hasMatch(message);
      case 'japanese':
        return RegExp(r'(いつ|時間|何時|朝|午後|夜|今|最適)').hasMatch(message);
      case 'korean':
        return RegExp(r'(언제|시간|몇시|아침|오후|저녁|지금|최적)').hasMatch(message);
      case 'spanish':
        return RegExp(r'(cuándo|tiempo|hora|mañana|tarde|noche|ahora|mejor momento)').hasMatch(message);
      case 'french':
        return RegExp(r'(quand|temps|heure|matin|après-midi|soir|maintenant|meilleur moment)').hasMatch(message);
      case 'german':
        return RegExp(r'(wann|zeit|stunde|morgen|nachmittag|abend|jetzt|beste zeit)').hasMatch(message);
      case 'italian':
        return RegExp(r'(quando|tempo|ora|mattina|pomeriggio|sera|ora|momento migliore)').hasMatch(message);
      default:
        return RegExp(r'(when|time|hour|morning|afternoon|evening|now|best time)').hasMatch(message);
    }
  }

  // 检测健康询问
  bool _isHealthQuery(String message, String language) {
    switch (language) {
      case 'chinese':
        return RegExp(r'(健康|安全|危险|影响|身体|呼吸|过敏|注意)').hasMatch(message);
      case 'japanese':
        return RegExp(r'(健康|安全|危険|影響|体|呼吸|アレルギー|注意)').hasMatch(message);
      case 'korean':
        return RegExp(r'(건강|안전|위험|영향|몸|호흡|알레르기|주의)').hasMatch(message);
      case 'spanish':
        return RegExp(r'(salud|seguridad|peligro|impacto|cuerpo|respiración|alergia|cuidado)').hasMatch(message);
      case 'french':
        return RegExp(r'(santé|sécurité|danger|impact|corps|respiration|allergie|attention)').hasMatch(message);
      case 'german':
        return RegExp(r'(gesundheit|sicherheit|gefahr|auswirkung|körper|atmung|allergie|achtung)').hasMatch(message);
      case 'italian':
        return RegExp(r'(salute|sicurezza|pericolo|impatto|corpo|respirazione|allergia|attenzione)').hasMatch(message);
      default:
        return RegExp(r'(health|safety|danger|impact|body|breathing|allergy|caution)').hasMatch(message);
    }
  }

  // 检测闲聊
  bool _isCasualChat(String message, String language) {
    switch (language) {
      case 'chinese':
        return RegExp(r'(怎么样|如何|谢谢|不错|好的|明白|知道了|哈哈)').hasMatch(message);
      case 'japanese':
        return RegExp(r'(どう|ありがとう|いいね|わかった|そうですね)').hasMatch(message);
      case 'korean':
        return RegExp(r'(어떻게|고마워|좋아|알겠어|그렇네)').hasMatch(message);
      case 'spanish':
        return RegExp(r'(cómo|gracias|bien|entiendo|vale)').hasMatch(message);
      case 'french':
        return RegExp(r'(comment|merci|bien|compris|accord)').hasMatch(message);
      case 'german':
        return RegExp(r'(wie|danke|gut|verstehe|okay)').hasMatch(message);
      case 'italian':
        return RegExp(r'(come|grazie|bene|capisco|va bene)').hasMatch(message);
      default:
        return RegExp(r'(how|thanks|good|understand|okay|nice|cool)').hasMatch(message);
    }
  }

  // 获取语言指令
  String _getLanguageInstruction(String language) {
    switch (language) {
      case 'chinese':
        return 'RESPOND IN CHINESE (中文). The user asked in Chinese, so reply in Chinese. Use simplified Chinese characters.';
      case 'japanese':
        return 'RESPOND IN JAPANESE (日本語). The user asked in Japanese, so reply in Japanese.';
      case 'korean':
        return 'RESPOND IN KOREAN (한국어). The user asked in Korean, so reply in Korean.';
      case 'spanish':
        return 'RESPOND IN SPANISH (Español). The user asked in Spanish, so reply in Spanish.';
      case 'french':
        return 'RESPOND IN FRENCH (Français). The user asked in French, so reply in French.';
      case 'german':
        return 'RESPOND IN GERMAN (Deutsch). The user asked in German, so reply in German.';
      case 'italian':
        return 'RESPOND IN ITALIAN (Italiano). The user asked in Italian, so reply in Italian.';
      default:
        return 'RESPOND IN ENGLISH. The user asked in English, so reply in English.';
    }
  }

  // 格式化AI响应，确保移动端友好
  String _formatAIResponse(String rawResponse) {
    // 移除markdown格式
    String formatted = rawResponse
        .replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'\1') // 移除粗体
        .replaceAll(RegExp(r'\*([^*]+)\*'), r'\1')     // 移除斜体
        .replaceAll(RegExp(r'#{1,6}\s*'), '')          // 移除标题
        .replaceAll(RegExp(r'```[^`]*```'), '')        // 移除代码块
        .replaceAll(RegExp(r'`([^`]+)`'), r'\1')       // 移除行内代码
        .replaceAll(RegExp(r'\n\s*\n\s*\n'), '\n\n')  // 规范化换行
        .trim();

    // 确保不超过字数限制，但不要截断句子
    if (formatted.length > 800) {
      // 找到最后一个完整句子的位置
      int lastSentence = formatted.lastIndexOf('.', 800);
      if (lastSentence > 400) {
        formatted = formatted.substring(0, lastSentence + 1);
      } else {
        formatted = formatted.substring(0, 800) + '...';
      }
    }

    return formatted;
  }

  String _getSmartFallbackResponse(String userMessage, double? pm25, double? windSpeed, double? temperature) {
    final language = _detectLanguage(userMessage);
    
    // 分析用户意图
    if (_isGreeting(userMessage.toLowerCase(), language)) {
      return _formatGreetingResponse(language);
    }
    
    // 环境评估
    String airStatus = _getAirQualityStatus(pm25);
    String tempStatus = _getTemperatureStatus(temperature);
    String windStatus = _getWindStatus(windSpeed);
    
    // 根据用户意图和语言生成回复
    if (_isExerciseQuery(userMessage.toLowerCase(), language)) {
      return _formatExerciseAdvice(pm25, temperature, windSpeed, airStatus, tempStatus, windStatus, language);
    } else if (_isWeatherQuery(userMessage.toLowerCase(), language)) {
      return _formatWeatherAdvice(pm25, temperature, windSpeed, airStatus, tempStatus, windStatus, language);
    } else if (_isTimeQuery(userMessage.toLowerCase(), language)) {
      return _formatTimeAdvice(airStatus, tempStatus, language);
    } else if (_isHealthQuery(userMessage.toLowerCase(), language)) {
      return _formatHealthAdvice(pm25, temperature, airStatus, tempStatus, language);
    } else if (_isCasualChat(userMessage.toLowerCase(), language)) {
      return _formatCasualResponse(language);
    } else {
      return _formatGeneralAdvice(pm25, temperature, airStatus, tempStatus, language);
    }
  }

  // 问候回应
  String _formatGreetingResponse(String language) {
    switch (language) {
      case 'chinese':
        return "你好！👋 我是你的AI健身教练，很高兴认识你！\n\n"
               "我可以根据实时的环境数据为你提供个性化的运动建议。\n\n"
               "你可以问我关于:\n"
               "• 今天适合什么运动\n"
               "• 空气质量和天气情况\n"
               "• 最佳运动时间\n"
               "• 健康和安全建议\n\n"
               "有什么想了解的吗？";
      case 'spanish':
        return "¡Hola! 👋 Soy tu entrenador de fitness con IA, ¡encantado de conocerte!\n\n"
               "Puedo darte consejos personalizados de ejercicio basados en datos ambientales en tiempo real.\n\n"
               "Puedes preguntarme sobre ejercicios, calidad del aire, o el mejor momento para entrenar.";
      case 'french':
        return "Bonjour ! 👋 Je suis votre coach fitness IA, ravi de vous rencontrer !\n\n"
               "Je peux vous donner des conseils d'exercice personnalisés basés sur les données environnementales en temps réel.\n\n"
               "Vous pouvez me demander des exercices, la qualité de l'air, ou le meilleur moment pour s'entraîner.";
      default:
        return "Hello! 👋 I'm your AI fitness coach, nice to meet you!\n\n"
               "I can provide personalized workout advice based on real-time environmental data.\n\n"
               "You can ask me about:\n"
               "• What exercises are good today\n"
               "• Air quality and weather conditions\n"
               "• Best times to exercise\n"
               "• Health and safety advice\n\n"
               "What would you like to know?";
    }
  }

  // 运动建议回应
  String _formatExerciseAdvice(double? pm25, double? temp, double? wind, String airStatus, String tempStatus, String windStatus, String language) {
    if (language == 'chinese') {
      String advice = "🏃‍♂️ 运动建议\n\n";
      
      if (pm25 != null) {
        advice += "空气质量: ${pm25.toStringAsFixed(1)} µg/m³ (${_translateStatus(airStatus, language)})\n";
      }
      if (temp != null) {
        advice += "温度: ${temp.toStringAsFixed(1)}°C (${_translateStatus(tempStatus, language)})\n\n";
      }
      
      if (airStatus == "poor" || (pm25 != null && pm25 > 35)) {
        advice += "建议: 室内运动更安全\n\n";
        advice += "• 瑜伽、普拉提或室内健身\n";
        advice += "• 如需户外: 最多15-20分钟\n";
        advice += "• 避开交通繁忙区域";
      } else {
        advice += "建议: 适合户外运动\n\n";
        advice += "• 跑步、骑行或户外健身都不错\n";
        advice += "• 最佳时间: 早上6-8点或晚上6-8点\n";
        if (tempStatus == "cold") {
          advice += "• 注意保暖，充分热身";
        } else if (tempStatus == "warm") {
          advice += "• 注意补水，避开正午时段";
        } else {
          advice += "• 运动条件很好！";
        }
      }
      return advice;
    } else {
      // 英文版本
      String advice = "🏃‍♂️ EXERCISE RECOMMENDATIONS\n\n";
      
      if (pm25 != null) {
        advice += "Air Quality: ${pm25.toStringAsFixed(1)} µg/m³ ($airStatus)\n";
      }
      if (temp != null) {
        advice += "Temperature: ${temp.toStringAsFixed(1)}°C ($tempStatus)\n\n";
      }
      
      if (airStatus == "poor" || (pm25 != null && pm25 > 35)) {
        advice += "RECOMMENDATION: Indoor activities preferred\n\n";
        advice += "• Yoga, pilates, or indoor gym workouts\n";
        advice += "• If outdoors: 15-20 min max\n";
        advice += "• Avoid busy traffic areas";
      } else {
        advice += "RECOMMENDATION: Great for outdoor activities\n\n";
        advice += "• Running, cycling, or outdoor fitness all good\n";
        advice += "• Best times: 6-8 AM or 6-8 PM\n";
        if (tempStatus == "cold") {
          advice += "• Dress warmly, warm up thoroughly";
        } else if (tempStatus == "warm") {
          advice += "• Stay hydrated, avoid midday heat";
        } else {
          advice += "• Perfect conditions for exercise!";
        }
      }
      return advice;
    }
  }

  // 健康建议回应
  String _formatHealthAdvice(double? pm25, double? temp, String airStatus, String tempStatus, String language) {
    if (language == 'chinese') {
      String advice = "🏥 健康建议\n\n";
      
      if (pm25 != null) {
        if (pm25 > 50) {
          advice += "空气质量较差 (PM2.5: ${pm25.toStringAsFixed(1)})\n\n";
          advice += "健康提醒:\n";
          advice += "• 减少户外活动时间\n";
          advice += "• 外出时佩戴N95口罩\n";
          advice += "• 多喝水，注意休息\n";
          advice += "• 有呼吸道疾病者尤其注意";
        } else if (pm25 > 25) {
          advice += "空气质量中等 (PM2.5: ${pm25.toStringAsFixed(1)})\n\n";
          advice += "健康提醒:\n";
          advice += "• 适度户外活动\n";
          advice += "• 敏感人群注意防护\n";
          advice += "• 避开交通高峰期";
        } else {
          advice += "空气质量良好 (PM2.5: ${pm25.toStringAsFixed(1)})\n\n";
          advice += "健康状况:\n";
          advice += "• 适合各种户外活动\n";
          advice += "• 深呼吸，享受新鲜空气\n";
          advice += "• 是运动的好时机";
        }
      }
      
      return advice;
    } else {
      String advice = "🏥 HEALTH ADVICE\n\n";
      
      if (pm25 != null) {
        if (pm25 > 50) {
          advice += "Poor air quality (PM2.5: ${pm25.toStringAsFixed(1)})\n\n";
          advice += "Health reminders:\n";
          advice += "• Limit outdoor activities\n";
          advice += "• Wear N95 mask when outside\n";
          advice += "• Stay hydrated and rest\n";
          advice += "• Extra caution for respiratory conditions";
        } else if (pm25 > 25) {
          advice += "Moderate air quality (PM2.5: ${pm25.toStringAsFixed(1)})\n\n";
          advice += "Health reminders:\n";
          advice += "• Moderate outdoor activities okay\n";
          advice += "• Sensitive individuals take precautions\n";
          advice += "• Avoid rush hour traffic";
        } else {
          advice += "Good air quality (PM2.5: ${pm25.toStringAsFixed(1)})\n\n";
          advice += "Health status:\n";
          advice += "• Great for all outdoor activities\n";
          advice += "• Take deep breaths, enjoy fresh air\n";
          advice += "• Perfect time for exercise";
        }
      }
      
      return advice;
    }
  }

  // 闲聊回应
  String _formatCasualResponse(String language) {
    switch (language) {
      case 'chinese':
        return "😊 很高兴和你聊天！\n\n"
               "我是专门帮助你做运动决策的AI教练。基于当前的环境数据，我可以给你最合适的建议。\n\n"
               "比如你可以问我:\n"
               "• \"今天适合跑步吗？\"\n"
               "• \"空气质量怎么样？\"\n"
               "• \"什么时候运动最好？\"\n\n"
               "有什么想了解的吗？";
      case 'spanish':
        return "😊 ¡Me alegra charlar contigo!\n\n"
               "Soy un entrenador de IA especializado en ayudarte a tomar decisiones de ejercicio basadas en datos ambientales actuales.\n\n"
               "¿Hay algo específico sobre fitness o condiciones ambientales que te gustaría saber?";
      case 'french':
        return "😊 Ravi de discuter avec vous !\n\n"
               "Je suis un coach IA spécialisé pour vous aider à prendre des décisions d'exercice basées sur les données environnementales actuelles.\n\n"
               "Y a-t-il quelque chose de spécifique sur le fitness ou les conditions environnementales que vous aimeriez savoir ?";
      default:
        return "😊 Nice chatting with you!\n\n"
               "I'm an AI coach specialized in helping you make exercise decisions based on current environmental data.\n\n"
               "You could ask me things like:\n"
               "• \"Is it good for running today?\"\n"
               "• \"How's the air quality?\"\n"
               "• \"When's the best time to exercise?\"\n\n"
               "Is there anything specific you'd like to know?";
    }
  }

  String _getAirQualityStatus(double? pm25) {
    if (pm25 == null) return "unknown";
    if (pm25 < 10) return "excellent";
    if (pm25 < 25) return "good";
    if (pm25 < 50) return "moderate";
    return "poor";
  }

  String _getTemperatureStatus(double? temp) {
    if (temp == null) return "unknown";
    if (temp < 5) return "cold";
    if (temp < 15) return "cool";
    if (temp < 25) return "comfortable";
    return "warm";
  }

  String _getWindStatus(double? wind) {
    if (wind == null) return "unknown";
    if (wind < 10) return "calm";
    if (wind < 20) return "moderate";
    return "strong";
  }

  String _formatRunningAdvice(double? pm25, double? temp, double? wind, String airStatus, String tempStatus, String language) {
    if (language == 'chinese') {
      String advice = "🏃‍♂️ 跑步评估\n\n";
      
      if (pm25 != null) {
        advice += "空气质量: ${pm25.toStringAsFixed(1)} µg/m³ (${_translateStatus(airStatus, language)})\n";
      }
      if (temp != null) {
        advice += "温度: ${temp.toStringAsFixed(1)}°C (${_translateStatus(tempStatus, language)})\n\n";
      }
      
      if (airStatus == "poor" || (pm25 != null && pm25 > 35)) {
        advice += "建议: 室内跑步更安全\n\n";
        advice += "• 尝试跑步机或爬楼梯\n";
        advice += "• 如需户外: 最多15-20分钟，选择清晨\n";
        advice += "• 避开繁忙道路和交通区域";
      } else {
        advice += "建议: 适合户外跑步\n\n";
        advice += "• 最佳时间: 早上6-8点或晚上6-8点\n";
        advice += "• 选择公园或绿树成荫的路线\n";
        if (tempStatus == "cold") {
          advice += "• 充分热身，分层穿衣";
        } else if (tempStatus == "warm") {
          advice += "• 保持水分，避开阳光强烈时段";
        } else {
          advice += "• 跑步条件很好";
        }
      }
      return advice;
    } else {
      // 英文版本保持原样
      String advice = "🏃‍♂️ RUNNING ASSESSMENT\n\n";
      
      if (pm25 != null) {
        advice += "Air Quality: ${pm25.toStringAsFixed(1)} µg/m³ ($airStatus)\n";
      }
      if (temp != null) {
        advice += "Temperature: ${temp.toStringAsFixed(1)}°C ($tempStatus)\n\n";
      }
      
      if (airStatus == "poor" || (pm25 != null && pm25 > 35)) {
        advice += "RECOMMENDATION: Indoor running recommended\n\n";
        advice += "• Try treadmill or stair climbing\n";
        advice += "• If outdoors: 15-20 min max, early morning\n";
        advice += "• Avoid busy roads and traffic areas";
      } else {
        advice += "RECOMMENDATION: Outdoor running is suitable\n\n";
        advice += "• Best times: 6-8 AM or 6-8 PM\n";
        advice += "• Choose parks or tree-lined routes\n";
        if (tempStatus == "cold") {
          advice += "• Warm up thoroughly, dress in layers";
        } else if (tempStatus == "warm") {
          advice += "• Stay hydrated, avoid peak sun hours";
        } else {
          advice += "• Perfect conditions for your run";
        }
      }
      return advice;
    }
  }

  String _formatCyclingAdvice(double? pm25, double? temp, double? wind, String airStatus, String tempStatus, String windStatus, String language) {
    if (language == 'chinese') {
      String advice = "🚴‍♂️ 骑行评估\n\n";
      
      if (pm25 != null) {
        advice += "空气质量: ${pm25.toStringAsFixed(1)} µg/m³ (${_translateStatus(airStatus, language)})\n";
      }
      if (temp != null) {
        advice += "温度: ${temp.toStringAsFixed(1)}°C (${_translateStatus(tempStatus, language)})\n";
      }
      if (wind != null) {
        advice += "风速: ${wind.toStringAsFixed(1)} km/h (${_translateStatus(windStatus, language)})\n\n";
      }
      
      advice += "建议: ";
      if (airStatus == "poor") {
        advice += "室内骑行更好\n\n";
        advice += "• 使用动感单车或训练台\n";
        advice += "• 如需户外: 仅短距离骑行";
      } else {
        advice += "适合户外骑行\n\n";
        advice += "• 选择自行车道和公园\n";
        advice += "• 避开交通繁忙区域\n";
        if (windStatus == "strong") {
          advice += "• 考虑风向规划路线";
        } else {
          advice += "• 适合长距离骑行";
        }
      }
      return advice;
    } else {
      // 英文版本
      String advice = "🚴‍♂️ CYCLING ASSESSMENT\n\n";
      
      if (pm25 != null) {
        advice += "Air Quality: ${pm25.toStringAsFixed(1)} µg/m³ ($airStatus)\n";
      }
      if (temp != null) {
        advice += "Temperature: ${temp.toStringAsFixed(1)}°C ($tempStatus)\n";
      }
      if (wind != null) {
        advice += "Wind: ${wind.toStringAsFixed(1)} km/h ($windStatus)\n\n";
      }
      
      advice += "RECOMMENDATION: ";
      if (airStatus == "poor") {
        advice += "Indoor cycling preferred\n\n";
        advice += "• Use stationary bike or trainer\n";
        advice += "• If outdoors: short rides only";
      } else {
        advice += "Outdoor cycling suitable\n\n";
        advice += "• Stick to bike paths and parks\n";
        advice += "• Avoid heavy traffic areas\n";
        if (windStatus == "strong") {
          advice += "• Plan route considering wind direction";
        } else {
          advice += "• Good conditions for longer rides";
        }
      }
      return advice;
    }
  }

  String _formatYogaAdvice(String airStatus, String tempStatus, String language) {
    if (language == 'chinese') {
      return "🧘‍♀️ 瑜伽评估\n\n"
             "建议: 今天的完美选择\n\n"
             "• 室内瑜伽总是理想的\n"
             "• 专注于呼吸练习\n"
             "• 有助于灵活性和正念\n"
             "• 不受天气影响";
    } else {
      return "🧘‍♀️ YOGA ASSESSMENT\n\n"
             "RECOMMENDATION: Perfect choice for today\n\n"
             "• Indoor yoga is always ideal\n"
             "• Focus on breathing exercises\n"
             "• Great for flexibility and mindfulness\n"
             "• No weather dependency needed";
    }
  }

  String _formatWeatherAdvice(double? pm25, double? temp, double? wind, String airStatus, String tempStatus, String windStatus, String language) {
    if (language == 'chinese') {
      String advice = "🌤️ 当前环境状况\n\n";
      
      if (pm25 != null) {
        advice += "空气质量: ${pm25.toStringAsFixed(1)} µg/m³ (${_translateStatus(airStatus, language)})\n";
      }
      if (temp != null) {
        advice += "温度: ${temp.toStringAsFixed(1)}°C (${_translateStatus(tempStatus, language)})\n";
      }
      if (wind != null) {
        advice += "风速: ${wind.toStringAsFixed(1)} km/h (${_translateStatus(windStatus, language)})\n\n";
      }
      
      advice += "总体评估:\n";
      if (airStatus == "excellent" || airStatus == "good") {
        advice += "• 户外活动条件很好\n";
      } else if (airStatus == "moderate") {
        advice += "• 户外活动可以，建议缩短时间\n";
      } else {
        advice += "• 建议室内活动\n";
      }
      
      advice += "• 全天监测环境变化";
      return advice;
    } else {
      String advice = "🌤️ CURRENT CONDITIONS\n\n";
      
      if (pm25 != null) {
        advice += "Air Quality: ${pm25.toStringAsFixed(1)} µg/m³ ($airStatus)\n";
      }
      if (temp != null) {
        advice += "Temperature: ${temp.toStringAsFixed(1)}°C ($tempStatus)\n";
      }
      if (wind != null) {
        advice += "Wind Speed: ${wind.toStringAsFixed(1)} km/h ($windStatus)\n\n";
      }
      
      advice += "OVERALL ASSESSMENT:\n";
      if (airStatus == "excellent" || airStatus == "good") {
        advice += "• Great conditions for outdoor activities\n";
      } else if (airStatus == "moderate") {
        advice += "• Outdoor activities okay, shorter sessions\n";
      } else {
        advice += "• Indoor activities recommended\n";
      }
      
      advice += "• Monitor conditions throughout the day";
      return advice;
    }
  }

  String _formatTimeAdvice(String airStatus, String tempStatus, String language) {
    if (language == 'chinese') {
      return "⏰ 最佳运动时间\n\n"
             "推荐时段:\n"
             "• 清晨: 6-8点 (空气最清洁)\n"
             "• 傍晚: 6-8点 (温度较凉爽)\n\n"
             "避免时段:\n"
             "• 中午: 11点-下午3点 (污染高峰)\n"
             "• 高峰期: 早7-9点，晚5-7点 (交通繁忙)";
    } else {
      return "⏰ OPTIMAL EXERCISE TIMES\n\n"
             "BEST WINDOWS:\n"
             "• Early morning: 6-8 AM (cleanest air)\n"
             "• Evening: 6-8 PM (cooler temperatures)\n\n"
             "AVOID:\n"
             "• Midday: 11 AM-3 PM (peak pollution)\n"
             "• Rush hours: 7-9 AM, 5-7 PM traffic";
    }
  }

  String _formatGeneralAdvice(double? pm25, double? temp, String airStatus, String tempStatus, String language) {
    if (language == 'chinese') {
      String advice = "💪 健身教练就绪\n\n";
      
      if (pm25 != null) {
        advice += "当前空气质量: ${pm25.toStringAsFixed(1)} µg/m³ (${_translateStatus(airStatus, language)})\n";
      }
      if (temp != null) {
        advice += "温度: ${temp.toStringAsFixed(1)}°C (${_translateStatus(tempStatus, language)})\n\n";
      }
      
      advice += "询问我关于:\n";
      advice += "• 跑步条件和路线\n";
      advice += "• 骑行安全和时间\n";
      advice += "• 室内运动替代方案\n";
      advice += "• 今日最佳运动时间";
      
      return advice;
    } else {
      String advice = "💪 FITNESS COACH READY\n\n";
      
      if (pm25 != null) {
        advice += "Current air quality: ${pm25.toStringAsFixed(1)} µg/m³ ($airStatus)\n";
      }
      if (temp != null) {
        advice += "Temperature: ${temp.toStringAsFixed(1)}°C ($tempStatus)\n\n";
      }
      
      advice += "ASK ME ABOUT:\n";
      advice += "• Running conditions and routes\n";
      advice += "• Cycling safety and timing\n";
      advice += "• Indoor workout alternatives\n";
      advice += "• Best exercise times today";
      
      return advice;
    }
  }

  // 翻译状态词
  String _translateStatus(String status, String language) {
    if (language == 'chinese') {
      switch (status) {
        case 'excellent': return '优秀';
        case 'good': return '良好';
        case 'moderate': return '中等';
        case 'poor': return '差';
        case 'cold': return '寒冷';
        case 'cool': return '凉爽';
        case 'comfortable': return '舒适';
        case 'warm': return '温暖';
        case 'calm': return '微风';
        case 'strong': return '强风';
        default: return status;
      }
    }
    return status;
  }
}