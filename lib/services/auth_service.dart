import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cityzen/services/firebase_service.dart';
import 'package:cityzen/services/user_data_service.dart';

class AuthService extends ChangeNotifier {
  static AuthService? _instance;
  static AuthService get instance => _instance ??= AuthService._();
  
  AuthService._();

  User? _user;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  User? get currentUser => _user;
  bool get isAuthenticated => currentUser != null || _isDemo;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAnonymous => currentUser?.isAnonymous ?? _isDemo;

  // 初始化认证服务
  Future<void> initialize() async {
    try {
      await FirebaseService.instance.initialize();
      
      // 监听认证状态变化
      FirebaseService.instance.auth.authStateChanges().listen((User? user) {
        _user = user;
        notifyListeners();
        debugPrint('Auth state changed: ${user?.uid ?? 'No user'}');
      });
      
      // 获取当前用户
      _user = FirebaseService.instance.auth.currentUser;
      
      notifyListeners();
      debugPrint('Auth service initialized: ${_user?.uid ?? 'No user - showing login'}');
    } catch (e) {
      debugPrint('Auth service initialization error: $e');
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // 邮箱密码注册
  Future<UserCredential?> registerWithEmailPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      final credential = await FirebaseService.instance.auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 更新用户显示名称
      await credential.user?.updateDisplayName(displayName);
      await credential.user?.reload();
      _user = FirebaseService.instance.auth.currentUser;

      // 创建用户数据
      if (credential.user != null) {
        await UserDataService.instance.createUserProfile(
          userId: credential.user!.uid,
          email: email,
          displayName: displayName,
        );
      }

      notifyListeners();
      debugPrint('User registered successfully: ${credential.user?.uid}');
      return credential;
    } on FirebaseAuthException catch (e) {
      _handleAuthException(e);
      return null;
    } catch (e) {
      _errorMessage = '注册失败: $e';
      debugPrint('Registration error: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // 邮箱密码登录
  Future<UserCredential?> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      final credential = await FirebaseService.instance.auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      _user = credential.user;
      notifyListeners();

      debugPrint('User signed in successfully: ${credential.user?.uid}');
      return credential;
    } on FirebaseAuthException catch (e) {
      _handleAuthException(e);
      return null;
    } catch (e) {
      _errorMessage = '登录失败: $e';
      debugPrint('Sign in error: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // 匿名登录
  Future<UserCredential?> signInAnonymously() async {
    try {
      _setLoading(true);
      _clearError();

      // 检查Firebase是否正确初始化
      if (!FirebaseService.instance.isInitialized) {
        throw Exception('Firebase未正确初始化');
      }

      final credential = await FirebaseService.instance.auth.signInAnonymously();
      _user = credential.user;
      
      // 创建匿名用户数据
      if (credential.user != null) {
        await UserDataService.instance.createUserProfile(
          userId: credential.user!.uid,
          email: null,
          displayName: '匿名用户',
          isAnonymous: true,
        );
      }

      notifyListeners();
      debugPrint('Anonymous sign in successful: ${credential.user?.uid}');
      return credential;
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth Exception in anonymous login: ${e.code} - ${e.message}');
      
      // 如果匿名登录失败，创建一个临时的本地用户用于演示
      if (e.code == 'auth/operation-not-allowed' || e.code.contains('anonymous')) {
        debugPrint('Anonymous auth not enabled, creating demo user');
        return await _createDemoUser();
      }
      
      _errorMessage = '匿名登录失败，请检查Firebase配置。错误: ${e.code}';
      return null;
    } catch (e) {
      debugPrint('Anonymous sign in error: $e');
      // 如果所有Firebase操作都失败，创建演示用户
      return await _createDemoUser();
    } finally {
      _setLoading(false);
    }
  }

  // 创建演示用户（当Firebase不可用时）
  Future<UserCredential?> _createDemoUser() async {
    try {
      // 创建一个模拟的用户对象用于演示
      final demoUserId = 'demo_user_${DateTime.now().millisecondsSinceEpoch}';
      
      // 模拟Firebase User对象的行为
      _user = null; // 我们将通过其他方式处理
      
      // 创建用户数据（使用本地存储）
      await UserDataService.instance.createUserProfile(
        userId: demoUserId,
        email: null,
        displayName: '演示用户',
        isAnonymous: true,
      );

      // 设置一个标志表示这是演示模式
      _isDemo = true;
      _demoUserId = demoUserId;
      
      notifyListeners();
      debugPrint('Demo user created: $demoUserId');
      
      // 返回null但设置状态为已认证
      return null;
    } catch (e) {
      debugPrint('Demo user creation error: $e');
      _errorMessage = '无法创建演示用户: $e';
      return null;
    }
  }

  // 添加演示模式相关变量
  bool _isDemo = false;
  String? _demoUserId;
  
  bool get isDemo => _isDemo;
  String? get demoUserId => _demoUserId;

  // 发送密码重置邮件
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      _setLoading(true);
      _clearError();

      await FirebaseService.instance.auth.sendPasswordResetEmail(email: email);
      debugPrint('Password reset email sent to: $email');
      return true;
    } on FirebaseAuthException catch (e) {
      _handleAuthException(e);
      return false;
    } catch (e) {
      _errorMessage = '发送重置邮件失败: $e';
      debugPrint('Password reset error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // 更新用户资料
  Future<bool> updateProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      final user = currentUser;
      if (user == null) {
        _errorMessage = '用户未登录';
        return false;
      }

      if (displayName != null) {
        await user.updateDisplayName(displayName);
      }
      
      if (photoURL != null) {
        await user.updatePhotoURL(photoURL);
      }

      await user.reload();
      _user = FirebaseService.instance.auth.currentUser;
      notifyListeners();

      debugPrint('Profile updated successfully');
      return true;
    } on FirebaseAuthException catch (e) {
      _handleAuthException(e);
      return false;
    } catch (e) {
      _errorMessage = '更新资料失败: $e';
      debugPrint('Profile update error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // 将匿名账户转换为正式账户
  Future<UserCredential?> linkAnonymousWithEmailPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      final user = currentUser;
      if (user == null || !user.isAnonymous) {
        _errorMessage = '当前不是匿名用户';
        return null;
      }

      final credential = EmailAuthProvider.credential(email: email, password: password);
      final linkedCredential = await user.linkWithCredential(credential);

      // 更新显示名称
      await linkedCredential.user?.updateDisplayName(displayName);
      await linkedCredential.user?.reload();
      _user = FirebaseService.instance.auth.currentUser;

      // 更新用户数据
      await UserDataService.instance.updateUserProfile(
        userId: user.uid,
        email: email,
        displayName: displayName,
        isAnonymous: false,
      );

      notifyListeners();
      debugPrint('Anonymous account linked successfully');
      return linkedCredential;
    } on FirebaseAuthException catch (e) {
      _handleAuthException(e);
      return null;
    } catch (e) {
      _errorMessage = '账户关联失败: $e';
      debugPrint('Account linking error: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // 登出
  Future<void> signOut() async {
    try {
      _setLoading(true);
      await FirebaseService.instance.auth.signOut();
      _user = null;
      notifyListeners();
      debugPrint('User signed out successfully');
    } catch (e) {
      _errorMessage = '登出失败: $e';
      debugPrint('Sign out error: $e');
    } finally {
      _setLoading(false);
    }
  }

  // 删除账户
  Future<bool> deleteAccount() async {
    try {
      _setLoading(true);
      _clearError();

      final user = currentUser;
      if (user == null) {
        _errorMessage = '用户未登录';
        return false;
      }

      // 删除用户数据
      await UserDataService.instance.deleteUserData(user.uid);
      
      // 删除Firebase Auth账户
      await user.delete();
      _user = null;
      notifyListeners();

      debugPrint('Account deleted successfully');
      return true;
    } on FirebaseAuthException catch (e) {
      _handleAuthException(e);
      return false;
    } catch (e) {
      _errorMessage = '删除账户失败: $e';
      debugPrint('Account deletion error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // 处理Firebase Auth异常
  void _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        _errorMessage = '密码强度不够，请使用至少6位字符';
        break;
      case 'email-already-in-use':
        _errorMessage = '邮箱已被使用，请使用其他邮箱或直接登录';
        break;
      case 'invalid-email':
        _errorMessage = '邮箱格式无效，请检查邮箱地址';
        break;
      case 'user-not-found':
        _errorMessage = '用户不存在，请先注册';
        break;
      case 'wrong-password':
        _errorMessage = '密码错误，请重新输入';
        break;
      case 'user-disabled':
        _errorMessage = '账户已被禁用，请联系管理员';
        break;
      case 'too-many-requests':
        _errorMessage = '请求过于频繁，请稍后再试';
        break;
      case 'network-request-failed':
        _errorMessage = '网络连接失败，请检查网络设置';
        break;
      case 'auth/configuration-not-found':
      case 'auth/project-not-found':
        _errorMessage = 'Firebase Authentication未启用，请在Firebase Console中启用Authentication服务';
        break;
      default:
        _errorMessage = 'Firebase Authentication未正确配置，请检查Firebase Console设置。错误代码: ${e.code}';
    }
    debugPrint('Firebase Auth Exception: ${e.code} - ${e.message}');
  }

  // 设置加载状态
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // 清除错误信息
  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // 清除错误信息（公共方法）
  void clearError() {
    _clearError();
  }
}