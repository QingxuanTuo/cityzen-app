import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cityzen/firebase_options.dart';

class FirebaseService {
  static FirebaseService? _instance;
  static FirebaseService get instance => _instance ??= FirebaseService._();
  
  FirebaseService._();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  // Firebase instances
  FirebaseFirestore? _firestore;
  FirebaseAuth? _auth;
  FirebaseStorage? _storage;

  // Getters for Firebase instances
  FirebaseFirestore get firestore {
    if (!_initialized) throw Exception('Firebase not initialized');
    return _firestore ??= FirebaseFirestore.instance;
  }

  FirebaseAuth get auth {
    if (!_initialized) throw Exception('Firebase not initialized');
    return _auth ??= FirebaseAuth.instance;
  }

  FirebaseStorage get storage {
    if (!_initialized) throw Exception('Firebase not initialized');
    return _storage ??= FirebaseStorage.instance;
  }

  // 初始化Firebase
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // 配置Firestore设置
      if (kIsWeb) {
        // Web平台特殊配置
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
      }

      // 启用离线持久化（移动端）
      if (!kIsWeb) {
        await FirebaseFirestore.instance.enablePersistence();
      }

      _initialized = true;
      debugPrint('Firebase initialized successfully');
      
      // 测试连接
      await _testConnection();
    } catch (e) {
      debugPrint('Firebase initialization error: $e');
      rethrow;
    }
  }

  // 测试Firebase连接
  Future<void> _testConnection() async {
    try {
      // 测试Firestore连接
      await firestore.collection('_test').limit(1).get();
      debugPrint('Firestore connection successful');
    } catch (e) {
      debugPrint('Firestore connection test failed: $e');
    }
  }

  // 检查Firebase连接状态
  Future<bool> checkConnection() async {
    try {
      if (!_initialized) {
        await initialize();
      }
      
      // 尝试读取一个测试文档
      await firestore.collection('_health_check').limit(1).get();
      return true;
    } catch (e) {
      debugPrint('Firebase connection check failed: $e');
      return false;
    }
  }

  // 创建用户文档
  Future<void> createUserDocument(String uid, Map<String, dynamic> userData) async {
    try {
      await firestore.collection(FirebaseConfig.usersCollection).doc(uid).set({
        ...userData,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('User document created for uid: $uid');
    } catch (e) {
      debugPrint('Error creating user document: $e');
      rethrow;
    }
  }

  // 更新用户文档
  Future<void> updateUserDocument(String uid, Map<String, dynamic> updates) async {
    try {
      await firestore.collection(FirebaseConfig.usersCollection).doc(uid).update({
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('User document updated for uid: $uid');
    } catch (e) {
      debugPrint('Error updating user document: $e');
      rethrow;
    }
  }

  // 获取用户文档
  Future<DocumentSnapshot> getUserDocument(String uid) async {
    try {
      return await firestore.collection(FirebaseConfig.usersCollection).doc(uid).get();
    } catch (e) {
      debugPrint('Error getting user document: $e');
      rethrow;
    }
  }

  // 删除用户数据
  Future<void> deleteUserData(String uid) async {
    try {
      final batch = firestore.batch();
      
      // 删除用户主文档
      batch.delete(firestore.collection(FirebaseConfig.usersCollection).doc(uid));
      
      // 删除健康档案
      batch.delete(firestore.collection(FirebaseConfig.healthProfilesCollection).doc(uid));
      
      // 删除用户设置
      batch.delete(firestore.collection(FirebaseConfig.userSettingsCollection).doc(uid));
      
      // 删除收藏位置
      final favoriteLocations = await firestore
          .collection(FirebaseConfig.favoriteLocationsCollection)
          .where('userId', isEqualTo: uid)
          .get();
      
      for (var doc in favoriteLocations.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      debugPrint('User data deleted for uid: $uid');
    } catch (e) {
      debugPrint('Error deleting user data: $e');
      rethrow;
    }
  }

  // 上传文件到Storage（可选功能）
  Future<String?> uploadFile(String path, List<int> data, {String? contentType}) async {
    try {
      if (!_initialized) {
        debugPrint('Firebase not initialized, skipping file upload');
        return null;
      }
      
      final ref = storage.ref().child(path);
      final uploadTask = ref.putData(
        Uint8List.fromList(data),
        SettableMetadata(contentType: contentType),
      );
      
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      debugPrint('File uploaded successfully: $path');
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading file (Storage may not be configured): $e');
      return null; // 返回null而不是抛出异常
    }
  }

  // 删除Storage中的文件（可选功能）
  Future<void> deleteFile(String path) async {
    try {
      if (!_initialized) {
        debugPrint('Firebase not initialized, skipping file deletion');
        return;
      }
      
      await storage.ref().child(path).delete();
      debugPrint('File deleted successfully: $path');
    } catch (e) {
      debugPrint('Error deleting file (Storage may not be configured): $e');
      // 不抛出异常，允许应用继续运行
    }
  }
}

// Firebase配置常量
class FirebaseConfig {
  // 集合名称 - 按照高分标准设计
  static const String usersCollection = 'users';
  static const String healthProfilesCollection = 'health_profiles';
  static const String favoriteLocationsCollection = 'favorite_locations';
  static const String environmentDataCollection = 'environment_data';
  static const String userSettingsCollection = 'user_settings';
  static const String sessionsCollection = 'sessions';
  static const String appointmentsCollection = 'appointments';

  // 存储路径
  static const String avatarsPath = 'avatars';
  static const String userDataPath = 'user_data';
  static const String environmentMediaPath = 'environment_media';

  // 安全规则相关
  static const List<String> userRoles = ['user', 'admin', 'therapist'];
  static const String defaultRole = 'user';
}