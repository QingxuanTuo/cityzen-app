import 'package:flutter/material.dart';

class UserHealthProfile {
  final String? userId;
  final int? age;
  final bool hasRespiratoryConditions;
  final bool hasCardiovascularConditions;
  final String activityLevel; // 'low', 'moderate', 'high'
  final List<String> allergies;
  final double pm25Threshold;
  final double temperatureThreshold;
  final String sensitivityLevel; // 'low', 'normal', 'high'
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserHealthProfile({
    this.userId,
    this.age,
    this.hasRespiratoryConditions = false,
    this.hasCardiovascularConditions = false,
    this.activityLevel = 'moderate',
    this.allergies = const [],
    this.pm25Threshold = 25.0,
    this.temperatureThreshold = 30.0,
    this.sensitivityLevel = 'normal',
    this.createdAt,
    this.updatedAt,
  });

  // 针对不同人群的个性化建议
  String getPersonalizedAdvice(int healthScore) {
    if (age != null && age! > 65) {
      return _getElderlyAdvice(healthScore);
    } else if (hasRespiratoryConditions) {
      return _getRespiratoryAdvice(healthScore);
    } else if (hasCardiovascularConditions) {
      return _getCardiovascularAdvice(healthScore);
    } else {
      return _getGeneralAdvice(healthScore);
    }
  }

  String _getElderlyAdvice(int score) {
    if (score >= 80) {
      return '环境条件良好，适合散步和轻度户外活动。建议选择公园等绿化较好的区域。';
    } else if (score >= 60) {
      return '环境条件一般，建议短时间户外活动，避开交通繁忙时段。';
    } else if (score >= 40) {
      return '环境质量较差，建议室内活动。如需外出，请佩戴口罩并缩短户外时间。';
    } else {
      return '环境质量很差，强烈建议待在室内，关闭门窗，使用空气净化器。';
    }
  }

  String _getRespiratoryAdvice(int score) {
    if (score >= 80) {
      return '空气质量良好，可以进行正常的户外活动。建议选择空气流通好的区域。';
    } else if (score >= 60) {
      return '空气质量一般，可适度户外活动，但请随身携带急救药物。';
    } else if (score >= 40) {
      return '空气质量较差，建议减少户外活动。如需外出，请佩戴N95口罩。';
    } else {
      return '空气质量很差，请避免户外活动，待在室内并使用空气净化器。';
    }
  }

  String _getCardiovascularAdvice(int score) {
    if (score >= 80) {
      return '环境条件适宜，可进行轻到中度的户外运动，注意监测心率。';
    } else if (score >= 60) {
      return '环境条件一般，建议轻度活动，避免剧烈运动，注意休息。';
    } else if (score >= 40) {
      return '环境条件较差，建议室内活动，避免户外运动以减少心脏负担。';
    } else {
      return '环境条件很差，请待在室内休息，避免任何剧烈活动。';
    }
  }

  String _getGeneralAdvice(int score) {
    if (score >= 80) {
      return '环境条件优良，适合各种户外活动和运动。';
    } else if (score >= 60) {
      return '环境条件良好，可以进行户外活动，建议避开交通高峰期。';
    } else if (score >= 40) {
      return '环境条件一般，建议减少户外活动时间，选择室内运动。';
    } else {
      return '环境条件较差，建议待在室内，如需外出请做好防护。';
    }
  }

  // 获取敏感度调整系数
  double getSensitivityMultiplier() {
    double multiplier = 1.0;
    
    // 年龄调整
    if (age != null) {
      if (age! > 65) multiplier *= 0.8;
      if (age! < 18) multiplier *= 0.9;
    }
    
    // 健康状况调整
    if (hasRespiratoryConditions) multiplier *= 0.7;
    if (hasCardiovascularConditions) multiplier *= 0.8;
    
    // 敏感度等级调整
    switch (sensitivityLevel) {
      case 'high':
        multiplier *= 0.8;
        break;
      case 'low':
        multiplier *= 1.2;
        break;
      default:
        break;
    }
    
    return multiplier;
  }

  // 转换为Map用于Firestore存储
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'age': age,
      'hasRespiratoryConditions': hasRespiratoryConditions,
      'hasCardiovascularConditions': hasCardiovascularConditions,
      'activityLevel': activityLevel,
      'allergies': allergies,
      'pm25Threshold': pm25Threshold,
      'temperatureThreshold': temperatureThreshold,
      'sensitivityLevel': sensitivityLevel,
      'createdAt': createdAt?.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }

  // 从Map创建实例
  factory UserHealthProfile.fromMap(Map<String, dynamic> map) {
    return UserHealthProfile(
      userId: map['userId'],
      age: map['age'],
      hasRespiratoryConditions: map['hasRespiratoryConditions'] ?? false,
      hasCardiovascularConditions: map['hasCardiovascularConditions'] ?? false,
      activityLevel: map['activityLevel'] ?? 'moderate',
      allergies: List<String>.from(map['allergies'] ?? []),
      pm25Threshold: map['pm25Threshold']?.toDouble() ?? 25.0,
      temperatureThreshold: map['temperatureThreshold']?.toDouble() ?? 30.0,
      sensitivityLevel: map['sensitivityLevel'] ?? 'normal',
      createdAt: map['createdAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'])
          : null,
    );
  }

  // 复制并更新
  UserHealthProfile copyWith({
    String? userId,
    int? age,
    bool? hasRespiratoryConditions,
    bool? hasCardiovascularConditions,
    String? activityLevel,
    List<String>? allergies,
    double? pm25Threshold,
    double? temperatureThreshold,
    String? sensitivityLevel,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserHealthProfile(
      userId: userId ?? this.userId,
      age: age ?? this.age,
      hasRespiratoryConditions: hasRespiratoryConditions ?? this.hasRespiratoryConditions,
      hasCardiovascularConditions: hasCardiovascularConditions ?? this.hasCardiovascularConditions,
      activityLevel: activityLevel ?? this.activityLevel,
      allergies: allergies ?? this.allergies,
      pm25Threshold: pm25Threshold ?? this.pm25Threshold,
      temperatureThreshold: temperatureThreshold ?? this.temperatureThreshold,
      sensitivityLevel: sensitivityLevel ?? this.sensitivityLevel,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}