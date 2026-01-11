import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cityzen/models/user_health_profile.dart';
import 'package:cityzen/models/favorite_location.dart';
import 'package:cityzen/services/firebase_service.dart';

class UserDataService extends ChangeNotifier {
  static UserDataService? _instance;
  static UserDataService get instance => _instance ??= UserDataService._();
  
  UserDataService._();

  UserHealthProfile? _healthProfile;
  List<FavoriteLocation> _currentFavoriteLocations = [];
  Map<String, dynamic>? _currentUserSettings;
  bool _isLoading = false;

  // Getters
  UserHealthProfile? get healthProfile => _healthProfile;
  List<FavoriteLocation> get favoriteLocations => _currentFavoriteLocations;
  Map<String, dynamic>? get userSettings => _currentUserSettings;
  bool get isLoading => _isLoading;

  // 创建用户档案
  Future<bool> createUserProfile({
    required String userId,
    String? email,
    required String displayName,
    bool isAnonymous = false,
  }) async {
    try {
      _setLoading(true);

      // 检查是否是演示模式
      if (userId.startsWith('demo_user_')) {
        debugPrint('Creating demo user profile locally: $userId');
        await createDefaultHealthProfile(userId);
        await createDefaultSettings(userId);
        return true;
      }

      final userData = {
        'uid': userId,
        'email': email,
        'displayName': displayName,
        'isAnonymous': isAnonymous,
        'role': FirebaseConfig.defaultRole,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // 创建用户主文档
      await FirebaseService.instance.createUserDocument(userId, userData);

      // 创建默认健康档案
      await createDefaultHealthProfile(userId);

      // 创建默认设置
      await createDefaultSettings(userId);

      debugPrint('User profile created successfully: $userId');
      return true;
    } catch (e) {
      debugPrint('Create user profile error: $e');
      // 如果Firebase失败，尝试本地创建
      if (!userId.startsWith('demo_user_')) {
        debugPrint('Firebase failed, creating local demo profile');
        await createDefaultHealthProfile(userId);
        await createDefaultSettings(userId);
        return true;
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // 更新用户档案
  Future<bool> updateUserProfile({
    required String userId,
    String? email,
    String? displayName,
    bool? isAnonymous,
  }) async {
    try {
      _setLoading(true);

      final updates = <String, dynamic>{};
      if (email != null) updates['email'] = email;
      if (displayName != null) updates['displayName'] = displayName;
      if (isAnonymous != null) updates['isAnonymous'] = isAnonymous;

      if (updates.isNotEmpty) {
        await FirebaseService.instance.updateUserDocument(userId, updates);
      }

      debugPrint('User profile updated successfully: $userId');
      return true;
    } catch (e) {
      debugPrint('Update user profile error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // 创建默认健康档案
  Future<bool> createDefaultHealthProfile(String userId) async {
    try {
      final defaultProfile = UserHealthProfile(
        userId: userId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await FirebaseService.instance.firestore
          .collection(FirebaseConfig.healthProfilesCollection)
          .doc(userId)
          .set(defaultProfile.toMap());

      _healthProfile = defaultProfile;
      notifyListeners();

      debugPrint('Default health profile created: $userId');
      return true;
    } catch (e) {
      debugPrint('Create default health profile error: $e');
      return false;
    }
  }

  // 获取健康档案
  Future<UserHealthProfile?> getHealthProfile(String userId) async {
    try {
      _setLoading(true);

      final doc = await FirebaseService.instance.firestore
          .collection(FirebaseConfig.healthProfilesCollection)
          .doc(userId)
          .get();

      if (doc.exists && doc.data() != null) {
        _healthProfile = UserHealthProfile.fromMap(doc.data()!);
      } else {
        // Create default if not exists
        await createDefaultHealthProfile(userId);
      }
      
      notifyListeners();
      return _healthProfile;
    } catch (e) {
      debugPrint('Get health profile error: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // 更新健康档案
  Future<bool> updateHealthProfile({
    required String userId,
    int? age,
    bool? hasRespiratoryConditions,
    bool? hasCardiovascularConditions,
    String? activityLevel,
    List<String>? allergies,
    double? pm25Threshold,
    double? temperatureThreshold,
    String? sensitivityLevel,
  }) async {
    try {
      _setLoading(true);

      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (age != null) updates['age'] = age;
      if (hasRespiratoryConditions != null) updates['hasRespiratoryConditions'] = hasRespiratoryConditions;
      if (hasCardiovascularConditions != null) updates['hasCardiovascularConditions'] = hasCardiovascularConditions;
      if (activityLevel != null) updates['activityLevel'] = activityLevel;
      if (allergies != null) updates['allergies'] = allergies;
      if (pm25Threshold != null) updates['pm25Threshold'] = pm25Threshold;
      if (temperatureThreshold != null) updates['temperatureThreshold'] = temperatureThreshold;
      if (sensitivityLevel != null) updates['sensitivityLevel'] = sensitivityLevel;

      await FirebaseService.instance.firestore
          .collection(FirebaseConfig.healthProfilesCollection)
          .doc(userId)
          .update(updates);

      // 更新本地缓存
      if (_healthProfile != null) {
        _healthProfile = _healthProfile!.copyWith(
          age: age,
          hasRespiratoryConditions: hasRespiratoryConditions,
          hasCardiovascularConditions: hasCardiovascularConditions,
          activityLevel: activityLevel,
          allergies: allergies,
          pm25Threshold: pm25Threshold,
          temperatureThreshold: temperatureThreshold,
          sensitivityLevel: sensitivityLevel,
          updatedAt: DateTime.now(),
        );
        notifyListeners();
      }

      debugPrint('Health profile updated successfully: $userId');
      return true;
    } catch (e) {
      debugPrint('Update health profile error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // 添加收藏位置
  Future<bool> addFavoriteLocation(String userId, FavoriteLocation location) async {
    try {
      _setLoading(true);

      await FirebaseService.instance.firestore
          .collection(FirebaseConfig.favoriteLocationsCollection)
          .doc(location.id)
          .set({
        ...location.toMap(),
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _currentFavoriteLocations.add(location);
      notifyListeners();

      debugPrint('Favorite location added: ${location.name}');
      return true;
    } catch (e) {
      debugPrint('Add favorite location error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // 获取收藏位置列表
  Future<List<FavoriteLocation>> getFavoriteLocations(String userId) async {
    try {
      _setLoading(true);

      final querySnapshot = await FirebaseService.instance.firestore
          .collection(FirebaseConfig.favoriteLocationsCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      _currentFavoriteLocations = querySnapshot.docs
          .map((doc) => FavoriteLocation.fromMap(doc.data()))
          .toList();

      notifyListeners();
      return _currentFavoriteLocations;
    } catch (e) {
      debugPrint('Get favorite locations error: $e');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  // 删除收藏位置
  Future<bool> removeFavoriteLocation(String userId, String locationId) async {
    try {
      _setLoading(true);

      await FirebaseService.instance.firestore
          .collection(FirebaseConfig.favoriteLocationsCollection)
          .doc(locationId)
          .delete();

      _currentFavoriteLocations.removeWhere((location) => location.id == locationId);
      notifyListeners();

      debugPrint('Favorite location removed: $locationId');
      return true;
    } catch (e) {
      debugPrint('Remove favorite location error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // 创建默认设置
  Future<bool> createDefaultSettings(String userId) async {
    try {
      final defaultSettings = {
        'notifications': {
          'pm25Alerts': true,
          'temperatureAlerts': true,
          'dailySummary': true,
          'activityReminders': false,
        },
        'preferences': {
          'temperatureUnit': 'celsius',
          'distanceUnit': 'kilometers',
          'language': 'en',
          'theme': 'light',
        },
        'privacy': {
          'shareLocation': false,
          'shareHealthData': false,
          'analytics': true,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseService.instance.firestore
          .collection(FirebaseConfig.userSettingsCollection)
          .doc(userId)
          .set(defaultSettings);

      _currentUserSettings = defaultSettings;
      notifyListeners();

      debugPrint('Default settings created: $userId');
      return true;
    } catch (e) {
      debugPrint('Create default settings error: $e');
      return false;
    }
  }

  // 获取用户设置
  Future<Map<String, dynamic>?> getUserSettings(String userId) async {
    try {
      _setLoading(true);

      final doc = await FirebaseService.instance.firestore
          .collection(FirebaseConfig.userSettingsCollection)
          .doc(userId)
          .get();

      if (doc.exists && doc.data() != null) {
        _currentUserSettings = doc.data()!;
      } else {
        // Create default if not exists
        await createDefaultSettings(userId);
      }
      
      notifyListeners();
      return _currentUserSettings;
    } catch (e) {
      debugPrint('Get user settings error: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // 更新用户设置
  Future<bool> updateUserSettings(
    String userId,
    Map<String, dynamic> settings,
  ) async {
    try {
      _setLoading(true);

      final updates = {
        ...settings,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseService.instance.firestore
          .collection(FirebaseConfig.userSettingsCollection)
          .doc(userId)
          .update(updates);

      // 更新本地缓存
      if (_currentUserSettings != null) {
        _currentUserSettings!.addAll(settings);
        notifyListeners();
      }

      debugPrint('User settings updated: $userId');
      return true;
    } catch (e) {
      debugPrint('Update user settings error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // 删除用户所有数据
  Future<bool> deleteUserData(String userId) async {
    try {
      _setLoading(true);

      // 使用Firebase服务的删除方法
      await FirebaseService.instance.deleteUserData(userId);

      // 清除本地缓存
      _healthProfile = null;
      _currentFavoriteLocations.clear();
      _currentUserSettings = null;
      notifyListeners();

      debugPrint('User data deleted successfully: $userId');
      return true;
    } catch (e) {
      debugPrint('Delete user data error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // 创建会话记录（新增 - 用于高分展示）
  Future<bool> createSession({
    required String userId,
    required Map<String, dynamic> sessionData,
  }) async {
    try {
      _setLoading(true);

      final sessionDoc = {
        'userId': userId,
        ...sessionData,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseService.instance.firestore
          .collection(FirebaseConfig.sessionsCollection)
          .add(sessionDoc);

      debugPrint('Session created successfully for user: $userId');
      return true;
    } catch (e) {
      debugPrint('Create session error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // 获取用户会话列表（新增 - 用于高分展示）
  Future<List<Map<String, dynamic>>> getUserSessions(String userId) async {
    try {
      _setLoading(true);

      final querySnapshot = await FirebaseService.instance.firestore
          .collection(FirebaseConfig.sessionsCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      final sessions = querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      debugPrint('Retrieved ${sessions.length} sessions for user: $userId');
      return sessions;
    } catch (e) {
      debugPrint('Get user sessions error: $e');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  // 设置加载状态
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // 清除本地数据
  void clearLocalData() {
    _healthProfile = null;
    _currentFavoriteLocations.clear();
    _currentUserSettings = null;
    notifyListeners();
  }
}