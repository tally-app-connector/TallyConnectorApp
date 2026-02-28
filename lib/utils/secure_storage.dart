import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage();
  
  // Keys
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  // Selected Company Methods
  static const String _selectedCompanyGuid = 'selected_company_guid';
  static Future<String?> getSelectedCompanyGuid() async {
    return await _storage.read(key: _selectedCompanyGuid);
  }
  static Future<void> saveCompanyGuid(String guid) async {
    await _storage.write(key: _selectedCompanyGuid, value: guid);
  }
  // Save token
  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }
  
  // Get token
  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }
  
  // Save user
  static Future<void> saveUser(String userData) async {
    await _storage.write(key: _userKey, value: userData);
  }
  
  // Get user
  static Future<String?> getUser() async {
    return await _storage.read(key: _userKey);
  }

  static Future<String?> getUserEmail() async {
  final userData = await _storage.read(key: _userKey);

  if (userData == null || userData.isEmpty) return null;

  try {
    final Map<String, dynamic> userMap = jsonDecode(userData);
    return userMap['email'] as String?;
  } catch (e) {
    return null;
  }
}

  
  // Clear all
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
  
  // Check if logged in
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}