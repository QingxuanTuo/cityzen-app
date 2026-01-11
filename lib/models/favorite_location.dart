import 'package:flutter/material.dart';

class FavoriteLocation {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String type; // 'home', 'work', 'hospital', 'park', 'gym', 'other'
  final IconData icon;
  final String? address;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const FavoriteLocation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.type,
    required this.icon,
    this.address,
    required this.createdAt,
    this.updatedAt,
  });

  // 根据类型获取默认图标
  static IconData getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'home':
        return Icons.home;
      case 'work':
        return Icons.work;
      case 'hospital':
        return Icons.local_hospital;
      case 'park':
        return Icons.park;
      case 'gym':
        return Icons.fitness_center;
      case 'school':
        return Icons.school;
      case 'shopping':
        return Icons.shopping_cart;
      default:
        return Icons.place;
    }
  }

  // 根据类型获取颜色
  static Color getColorForType(String type) {
    switch (type.toLowerCase()) {
      case 'home':
        return Colors.blue;
      case 'work':
        return Colors.orange;
      case 'hospital':
        return Colors.red;
      case 'park':
        return Colors.green;
      case 'gym':
        return Colors.purple;
      case 'school':
        return Colors.indigo;
      case 'shopping':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }

  // 获取类型的显示名称
  static String getTypeDisplayName(String type) {
    switch (type.toLowerCase()) {
      case 'home':
        return '家';
      case 'work':
        return '工作';
      case 'hospital':
        return '医院';
      case 'park':
        return '公园';
      case 'gym':
        return '健身房';
      case 'school':
        return '学校';
      case 'shopping':
        return '购物';
      default:
        return '其他';
    }
  }

  // 转换为Map用于存储
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'type': type,
      'iconCodePoint': icon.codePoint,
      'address': address,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }

  // 从Map创建实例
  factory FavoriteLocation.fromMap(Map<String, dynamic> map) {
    return FavoriteLocation(
      id: map['id'],
      name: map['name'],
      latitude: map['latitude'].toDouble(),
      longitude: map['longitude'].toDouble(),
      type: map['type'],
      icon: IconData(
        map['iconCodePoint'] ?? Icons.place.codePoint,
        fontFamily: 'MaterialIcons',
      ),
      address: map['address'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      updatedAt: map['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'])
          : null,
    );
  }

  // 复制并更新
  FavoriteLocation copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    String? type,
    IconData? icon,
    String? address,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FavoriteLocation(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FavoriteLocation && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'FavoriteLocation(id: $id, name: $name, type: $type)';
  }
}

// 预定义的位置类型
class LocationTypes {
  static const List<String> all = [
    'home',
    'work', 
    'hospital',
    'park',
    'gym',
    'school',
    'shopping',
    'other',
  ];

  static const Map<String, String> displayNames = {
    'home': '家',
    'work': '工作',
    'hospital': '医院',
    'park': '公园',
    'gym': '健身房',
    'school': '学校',
    'shopping': '购物',
    'other': '其他',
  };
}