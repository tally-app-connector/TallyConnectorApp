import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class CompanyLogoService {
  static Future<Uint8List?> loadLogo(String companyGuid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final base64 = prefs.getString('company_logo_$companyGuid');
      if (base64 == null || base64.isEmpty) return null;
      return base64Decode(base64);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveLogo(String companyGuid, Uint8List bytes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('company_logo_$companyGuid', base64Encode(bytes));
  }

  static Future<void> deleteLogo(String companyGuid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('company_logo_$companyGuid');
  }
}
