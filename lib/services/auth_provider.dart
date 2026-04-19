import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import 'api.dart';

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
    _loading = false;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final data = await ApiService.login(email, password);
    await _saveSession(data);
  }

  Future<void> signup(String email, String password) async {
    final data = await ApiService.signup(email, password);
    await _saveSession(data);
  }

  Future<void> _saveSession(Map<String, dynamic> data) async {
    _user = User.fromJson(data['user']);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', jsonEncode(data['user']));
    notifyListeners();
  }

  Future<void> logout() async {
    _user = null;
    await ApiService.clearToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user');
    notifyListeners();
  }
}
