import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import 'api.dart';
import 'notifications_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _loading = true;

  User? get user => _user;
  bool get loading => _loading;
  bool get isLoggedIn => _user != null;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userData = prefs.getString('user');
    if (token != null && userData != null) {
      try {
        _user = User.fromJson(jsonDecode(userData));
      } catch (_) {}
    }
    // Server signals "session ended elsewhere" via 401 on any authed call;
    // ApiService fires the listener and we wipe local state here so the
    // app falls back to the login screen on the next frame.
    ApiService.onUnauthorized(_handleSessionEnded);
    _loading = false;
    notifyListeners();
  }

  void _handleSessionEnded() {
    if (_user == null) return;
    _user = null;
    ApiService.clearToken();
    SharedPreferences.getInstance().then((p) => _wipeUserScopedKeys(p));
    NotificationsService.instance.unregister();
    notifyListeners();
  }

  /// Single source of truth for which prefs entries are tied to a signed-
  /// in user. Anything user-specific the customer app caches between
  /// launches goes through here so logout (and the silent 401 path) wipes
  /// it. Kept additive: when a new prefs key is introduced, append it
  /// here instead of duplicating the cleanup at every call site.
  Future<void> _wipeUserScopedKeys(SharedPreferences prefs) async {
    await prefs.remove('user');
    // Cart contents persist across launches; without this the next user
    // who logs in inherits the previous user's basket on first paint.
    await prefs.remove('cart_items_v1');
  }

  Future<void> login(String email, String password) async {
    final data = await ApiService.login(email, password);
    await _saveSession(data);
  }

  Future<void> signup(String email, String password) async {
    final data = await ApiService.signup(email, password);
    await _saveSession(data);
  }

  Future<void> loginWithOtp({
    required String phone,
    required String otp,
    required String requestId,
  }) async {
    final data = await ApiService.verifyOtp(
      phone: phone,
      otp: otp,
      requestId: requestId,
    );
    await _saveSession(data);
  }

  Future<void> _saveSession(Map<String, dynamic> data) async {
    _user = User.fromJson(data['user']);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', jsonEncode(data['user']));
    notifyListeners();
    NotificationsService.instance.registerForUser();
  }

  Future<void> logout() async {
    await NotificationsService.instance.unregister();
    _user = null;
    await ApiService.clearToken();
    final prefs = await SharedPreferences.getInstance();
    await _wipeUserScopedKeys(prefs);
    notifyListeners();
  }

  // Hard delete: removes the user server-side (cascades addresses, devices,
  // coupon redemptions; anonymises orders) and wipes all locally-stored
  // session data. Caller should handle errors thrown by the API.
  Future<void> deleteAccount() async {
    await ApiService.deleteAccount();
    _user = null;
    await ApiService.clearToken();
    final prefs = await SharedPreferences.getInstance();
    await _wipeUserScopedKeys(prefs);
    notifyListeners();
  }
}
