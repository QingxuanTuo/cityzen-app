import 'package:flutter/material.dart';
import 'package:cityzen/models/user_health_profile.dart';

class HealthScoreService {
  static HealthScoreService? _instance;
  static HealthScoreService get instance => _instance ??= HealthScoreService._();
  
  HealthScoreService._();

  // 计算环境健康评分 (0-100)
  int calculateHealthScore({
    required double? pm25,
    required double? pm10,
    required double? temperature,
    required double? humidity,
    required double? windSpeed,
    required int? weatherCode,
    UserHealthProfile? userProfile,
  }) {
    double score = 100.0;

    // PM2.5 影响 (基于WHO标准)
    if (pm25 != null) {
      score -= _calculatePM25Impact(pm25);
    }

    // PM10 影响
    if (pm10 != null) {
      score -= _calculatePM10Impact(pm10);
    }

    // 温度影响
    if (temperature != null) {
      score -= _calculateTemperatureImpact(temperature);
    }

    // 湿度影响
    if (humidity != null) {
      score -= _calculateHumidityImpact(humidity);
    }

    // 风速影响
    if (windSpeed != null) {
      score -= _calculateWindSpeedImpact(windSpeed);
    }

    // 天气状况影响
    if (weatherCode != null) {
      score -= _calculateWeatherCodeImpact(weatherCode);
    }

    // 用户健康状况调整
    if (userProfile != null) {
      score *= userProfile.getSensitivityMultiplier();
    }

    return score.clamp(0, 100).round();
  }

  // PM2.5 影响计算
  double _calculatePM25Impact(double pm25) {
    // WHO标准: 0-15 良好, 15-25 中等, 25-50 不健康, >50 非常不健康
    if (pm25 <= 15) return 0;
    if (pm25 <= 25) return (pm25 - 15) * 1.0; // 轻微影响
    if (pm25 <= 50) return 10 + (pm25 - 25) * 1.5; // 中等影响
    return 47.5 + (pm25 - 50) * 2.0; // 严重影响
  }

  // PM10 影响计算
  double _calculatePM10Impact(double pm10) {
    // WHO标准: 0-45 良好, 45-75 中等, >75 不健康
    if (pm10 <= 45) return 0;
    if (pm10 <= 75) return (pm10 - 45) * 0.5;
    return 15 + (pm10 - 75) * 1.0;
  }

  // 温度影响计算
  double _calculateTemperatureImpact(double temperature) {
    // 舒适温度范围: 18-26°C
    if (temperature >= 18 && temperature <= 26) return 0;
    
    if (temperature < 18) {
      // 低温影响
      if (temperature >= 10) return (18 - temperature) * 0.5;
      if (temperature >= 0) return 4 + (10 - temperature) * 1.0;
      return 14 + (0 - temperature) * 1.5; // 极低温
    } else {
      // 高温影响
      if (temperature <= 32) return (temperature - 26) * 1.0;
      if (temperature <= 38) return 6 + (temperature - 32) * 1.5;
      return 15 + (temperature - 38) * 2.0; // 极高温
    }
  }

  // 湿度影响计算
  double _calculateHumidityImpact(double humidity) {
    // 舒适湿度范围: 40-60%
    if (humidity >= 40 && humidity <= 60) return 0;
    
    if (humidity < 40) {
      return (40 - humidity) * 0.2; // 干燥影响较小
    } else {
      return (humidity - 60) * 0.3; // 潮湿影响稍大
    }
  }

  // 风速影响计算
  double _calculateWindSpeedImpact(double windSpeed) {
    // 适宜风速: 0-15 km/h
    if (windSpeed <= 15) return 0;
    if (windSpeed <= 25) return (windSpeed - 15) * 0.5; // 轻微影响
    if (windSpeed <= 40) return 5 + (windSpeed - 25) * 1.0; // 中等影响
    return 20 + (windSpeed - 40) * 1.5; // 强风影响
  }

  // 天气状况影响计算 (基于Open-Meteo weather codes)
  double _calculateWeatherCodeImpact(int weatherCode) {
    if (weatherCode == 0) return 0; // 晴朗
    if (weatherCode <= 2) return 2; // 部分多云
    if (weatherCode == 3) return 5; // 阴天
    if (weatherCode == 45 || weatherCode == 48) return 8; // 雾
    if (weatherCode >= 51 && weatherCode <= 67) return 10; // 雨
    if (weatherCode >= 71 && weatherCode <= 77) return 12; // 雪
    if (weatherCode >= 95 && weatherCode <= 99) return 15; // 雷暴
    return 5; // 其他天气
  }

  // 获取评分等级
  HealthScoreLevel getScoreLevel(int score) {
    if (score >= 80) return HealthScoreLevel.excellent;
    if (score >= 60) return HealthScoreLevel.good;
    if (score >= 40) return HealthScoreLevel.moderate;
    if (score >= 20) return HealthScoreLevel.poor;
    return HealthScoreLevel.veryPoor;
  }

  // 获取评分颜色
  Color getScoreColor(int score) {
    final level = getScoreLevel(score);
    switch (level) {
      case HealthScoreLevel.excellent:
        return Colors.green;
      case HealthScoreLevel.good:
        return Colors.lightGreen;
      case HealthScoreLevel.moderate:
        return Colors.amber;
      case HealthScoreLevel.poor:
        return Colors.orange;
      case HealthScoreLevel.veryPoor:
        return Colors.red;
    }
  }

  // 获取评分描述
  String getScoreDescription(int score) {
    final level = getScoreLevel(score);
    switch (level) {
      case HealthScoreLevel.excellent:
        return '优秀';
      case HealthScoreLevel.good:
        return '良好';
      case HealthScoreLevel.moderate:
        return '一般';
      case HealthScoreLevel.poor:
        return '较差';
      case HealthScoreLevel.veryPoor:
        return '很差';
    }
  }

  // 获取活动建议
  String getActivityAdvice(int score, UserHealthProfile? userProfile) {
    final level = getScoreLevel(score);
    
    if (userProfile != null) {
      return userProfile.getPersonalizedAdvice(score);
    }

    // 通用建议
    switch (level) {
      case HealthScoreLevel.excellent:
        return '环境条件优秀，适合各种户外活动和运动。';
      case HealthScoreLevel.good:
        return '环境条件良好，可以进行户外活动，建议选择空气流通好的区域。';
      case HealthScoreLevel.moderate:
        return '环境条件一般，建议适度户外活动，避开污染严重的区域。';
      case HealthScoreLevel.poor:
        return '环境条件较差，建议减少户外活动，选择室内运动。';
      case HealthScoreLevel.veryPoor:
        return '环境条件很差，建议待在室内，如需外出请做好防护。';
    }
  }

  // 获取详细的环境分析
  Map<String, dynamic> getDetailedAnalysis({
    required double? pm25,
    required double? pm10,
    required double? temperature,
    required double? humidity,
    required double? windSpeed,
    required int? weatherCode,
    UserHealthProfile? userProfile,
  }) {
    final score = calculateHealthScore(
      pm25: pm25,
      pm10: pm10,
      temperature: temperature,
      humidity: humidity,
      windSpeed: windSpeed,
      weatherCode: weatherCode,
      userProfile: userProfile,
    );

    return {
      'score': score,
      'level': getScoreLevel(score),
      'color': getScoreColor(score),
      'description': getScoreDescription(score),
      'advice': getActivityAdvice(score, userProfile),
      'factors': {
        'pm25': _analyzePM25(pm25),
        'pm10': _analyzePM10(pm10),
        'temperature': _analyzeTemperature(temperature),
        'humidity': _analyzeHumidity(humidity),
        'windSpeed': _analyzeWindSpeed(windSpeed),
        'weather': _analyzeWeather(weatherCode),
      },
    };
  }

  // 分析各个因子
  Map<String, dynamic> _analyzePM25(double? pm25) {
    if (pm25 == null) return {'status': 'unknown', 'message': '数据不可用'};
    
    if (pm25 <= 15) {
      return {'status': 'good', 'message': 'PM2.5浓度良好'};
    } else if (pm25 <= 25) {
      return {'status': 'moderate', 'message': 'PM2.5浓度中等'};
    } else if (pm25 <= 50) {
      return {'status': 'poor', 'message': 'PM2.5浓度较高，敏感人群需注意'};
    } else {
      return {'status': 'very_poor', 'message': 'PM2.5浓度很高，建议减少户外活动'};
    }
  }

  Map<String, dynamic> _analyzePM10(double? pm10) {
    if (pm10 == null) return {'status': 'unknown', 'message': '数据不可用'};
    
    if (pm10 <= 45) {
      return {'status': 'good', 'message': 'PM10浓度良好'};
    } else if (pm10 <= 75) {
      return {'status': 'moderate', 'message': 'PM10浓度中等'};
    } else {
      return {'status': 'poor', 'message': 'PM10浓度较高'};
    }
  }

  Map<String, dynamic> _analyzeTemperature(double? temperature) {
    if (temperature == null) return {'status': 'unknown', 'message': '数据不可用'};
    
    if (temperature >= 18 && temperature <= 26) {
      return {'status': 'good', 'message': '温度适宜'};
    } else if (temperature < 18) {
      return {'status': 'cold', 'message': '温度较低，注意保暖'};
    } else {
      return {'status': 'hot', 'message': '温度较高，注意防暑'};
    }
  }

  Map<String, dynamic> _analyzeHumidity(double? humidity) {
    if (humidity == null) return {'status': 'unknown', 'message': '数据不可用'};
    
    if (humidity >= 40 && humidity <= 60) {
      return {'status': 'good', 'message': '湿度适宜'};
    } else if (humidity < 40) {
      return {'status': 'dry', 'message': '空气干燥'};
    } else {
      return {'status': 'humid', 'message': '空气潮湿'};
    }
  }

  Map<String, dynamic> _analyzeWindSpeed(double? windSpeed) {
    if (windSpeed == null) return {'status': 'unknown', 'message': '数据不可用'};
    
    if (windSpeed <= 15) {
      return {'status': 'good', 'message': '风速适宜'};
    } else if (windSpeed <= 25) {
      return {'status': 'moderate', 'message': '风速较大'};
    } else {
      return {'status': 'strong', 'message': '风速很大，注意安全'};
    }
  }

  Map<String, dynamic> _analyzeWeather(int? weatherCode) {
    if (weatherCode == null) return {'status': 'unknown', 'message': '数据不可用'};
    
    if (weatherCode == 0) {
      return {'status': 'excellent', 'message': '天气晴朗'};
    } else if (weatherCode <= 3) {
      return {'status': 'good', 'message': '天气良好'};
    } else if (weatherCode >= 51 && weatherCode <= 67) {
      return {'status': 'rainy', 'message': '有降雨，注意出行安全'};
    } else if (weatherCode >= 71 && weatherCode <= 77) {
      return {'status': 'snowy', 'message': '有降雪，注意保暖和出行安全'};
    } else {
      return {'status': 'moderate', 'message': '天气一般'};
    }
  }
}

// 健康评分等级枚举
enum HealthScoreLevel {
  excellent, // 80-100
  good,      // 60-79
  moderate,  // 40-59
  poor,      // 20-39
  veryPoor,  // 0-19
}