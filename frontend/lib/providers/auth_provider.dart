import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';

class AuthProvider extends ChangeNotifier {
  String? _token;
  String? _role;
  String? _username;
  bool _isLoading = false;

  String? get token => _token;
  String? get role => _role;
  String? get username => _username;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null;
  bool get isAdmin => _role == 'admin';

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _token = data['access_token'];
        _role = data['role'];
        _username = data['username'];
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint("Login error: $e");
    }
    _isLoading = false;
    notifyListeners();
    return false;
  }

  void logout() {
    _token = null;
    _role = null;
    _username = null;
    notifyListeners();
  }
}
