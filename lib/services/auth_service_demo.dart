import 'package:flutter/material.dart';
import 'package:cityzen/services/user_data_service.dart';

// 演示模式用户类
class DemoUser {
  final String uid;
  final String? email;
  final String? displayName;
  final bool isAnonymous;

  DemoUser({
    required this.uid,
    this.email,
    this.displayName,
    this.isAnonymous = false,
  });
}

class AuthServiceDemo extends ChangeNotifier {
  static AuthServiceDemo? _instance;
  static AuthServiceDemo get instance => _instance ??= AuthServiceDemo._();
  
  AuthServiceDemo._();

  DemoUser? _demoUser;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  DemoUser? get currentUser => _demoUser;
  bool get isAuthenticated => _demoUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAnonymous => _demoUser?.isAnonymous ?? false;

  // 初始化认证服务
  Future<void> initialize() async {
    try {
      // 演示模式，直接初始化成功
      await Future.delayed(const Duration(milliseconds: 100));
      notifyListeners();
      debugPrint('Demo Auth service initialized');
    } catch (e) {
      debugPrint('Demo Auth service initialization error: $e');
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // 邮箱密码注册（演示模式）
  Future<bool> registerWithEmailPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      // 模拟注册延迟
      await Future.delayed(const Duration(milliseconds: 800));
      
      final user = DemoUser(
        uid: 'demo_${DateTime.now().millisecondsSinceEpoch}',
        email: email,
        displayName: displayName,
        isAnonymous: false,
      );

      _demoUser = user;
      notifyListeners();

      // 创建用户数据
      await UserDataService.instance.createUserProfile(
        userId: user.uid,
        email: email,
        displayName: displayName,
      );

      debugPrint('Demo user registered successfully: ${user.uid}');
      return true;
    } catch (e) {
      _errorMessage = 'Registration failed: $e';
      debugPrint('Registration error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // 邮箱密码登录（演示模式）
  Future<bool> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      // 模拟登录延迟
      await Future.delayed(const Duration(milliseconds: 600));
      
      final user = DemoUser(
        uid: 'demo_${email.hashCode.abs()}',
        email: email,
        displayName: email.split('@')[0],
        isAnonymous: false,
      );

      _demoUser = user;
      notifyListeners();

      debugPrint('Demo user signed in successfully: ${user.uid}');
      return true;
    } catch (e) {
      _errorMessage = 'Login failed: $e';
      debugPrint('Sign in error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // 匿名登录（演示模式）
  Future<bool> signInAnonymously() async {
    try {
      _setLoading(true);
      _clearError();

      // 模拟匿名登录延迟
      await Future.delayed(const Duration(milliseconds: 400));
      
      final user = DemoUser(
        uid: 'demo_anon_${DateTime.now().millisecondsSinceEpoch}',
        displayName: 'Guest User',
        isAnonymous: true,
      );

      _demoUser = user;
      notifyListeners();
      
      // 创建用户数据
      await UserDataService.instance.createUserProfile(
        userId: user.uid,
        email: null,
        displayName: 'Guest User',
        isAnonymous: true,
      );

      debugPrint('Demo anonymous sign in successful: ${user.uid}');
      return true;
    } catch (e) {
      _errorMessage = 'Anonymous login failed: $e';
      debugPrint('Anonymous sign in error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // 发送密码重置邮件（演示模式）
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      _setLoading(true);
      _clearError();

      // 模拟发送邮件延迟
      await Future.delayed(const Duration(milliseconds: 500));
      debugPrint('Demo password reset email sent to: $email');
      return true;
    } catch (e) {
      _errorMessage = 'Failed to send reset email: $e';
      debugPrint('Password reset error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // 更新用户资料（演示模式）
  Future<bool> updateProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      final user = currentUser;
      if (user == null) {
        _errorMessage = 'User not logged in';
        return false;
      }

      // 模拟更新延迟
      await Future.delayed(const Duration(milliseconds: 300));
      
      _demoUser = DemoUser(
        uid: user.uid,
        email: user.email,
        displayName: displayName ?? user.displayName,
        isAnonymous: user.isAnonymous,
      );
      
      notifyListeners();

      debugPrint('Demo profile updated successfully');
      return true;
    } catch (e) {
      _errorMessage = 'Profile update failed: $e';
      debugPrint('Profile update error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // 登出
  Future<void> signOut() async {
    try {
      _setLoading(true);
      await Future.delayed(const Duration(milliseconds: 200));
      _demoUser = null;
      notifyListeners();
      debugPrint('Demo user signed out successfully');
    } catch (e) {
      _errorMessage = 'Sign out failed: $e';
      debugPrint('Sign out error: $e');
    } finally {
      _setLoading(false);
    }
  }

  // 删除账户（演示模式）
  Future<bool> deleteAccount() async {
    try {
      _setLoading(true);
      _clearError();

      final user = currentUser;
      if (user == null) {
        _errorMessage = 'User not logged in';
        return false;
      }

      // 删除用户数据
      await UserDataService.instance.deleteUserData(user.uid);
      
      // 模拟删除延迟
      await Future.delayed(const Duration(milliseconds: 500));
      _demoUser = null;
      notifyListeners();

      debugPrint('Demo account deleted successfully');
      return true;
    } catch (e) {
      _errorMessage = 'Account deletion failed: $e';
      debugPrint('Account deletion error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
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