// import 'package:amazon_cognito_identity_dart_2/cognito.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// // ─── Persistent Storage ───────────────────────────────────────────────────────
// class _CognitoStorage extends CognitoStorage {
//   final SharedPreferences _prefs;
//   _CognitoStorage(this._prefs);

//   @override
//   Future<String?> getItem(String key) async => _prefs.getString(key);

//   @override
//   Future<void> setItem(String key, dynamic value) async =>
//       await _prefs.setString(key, value.toString());

//   @override
//   Future<void> removeItem(String key) async => await _prefs.remove(key);

//   @override
//   Future<void> clear() async => await _prefs.clear();
// }

// // ─── AuthService ──────────────────────────────────────────────────────────────
// class AuthService {
//   static const String _userPoolId = 'ap-south-1_TJZfocZgL';     // ← Replace
//   static const String _clientId   = '2ts5mv8rhapub6lhqnsns0eue5'; // ← Replace

//   static CognitoUserPool? _userPool;
//   static CognitoUser? _currentCognitoUser;

//   // ── Init ──────────────────────────────────────────────────────────────────
//   static Future<void> init() async {
//     final prefs = await SharedPreferences.getInstance();
//     _userPool = CognitoUserPool(_userPoolId, _clientId, storage: _CognitoStorage(prefs));
//   }

//   static CognitoUserPool get _pool {
//     if (_userPool == null) throw Exception('Call AuthService.init() in main().');
//     return _userPool!;
//   }

//   // ── SIGN UP ───────────────────────────────────────────────────────────────
//   // Returns: { 'success': bool, 'message': String }
//   static Future<Map<String, dynamic>> signup({
//     required String fullName,
//     required String email,
//     required String password,
//     String? phone,
//   }) async {
//     try {
//       final userAttributes = [
//         AttributeArg(name: 'name', value: fullName),
//         if (phone != null && phone.isNotEmpty)
//           AttributeArg(name: 'phone_number', value: _formatPhone(phone)),
//       ];

//       // Email is used directly as username (works after pool recreated with email-only sign-in)
//       await _pool.signUp(email, password, userAttributes: userAttributes);

//       return {'success': true, 'message': 'Account created successfully!'};
//     } on CognitoClientException catch (e) {
//       return {'success': false, 'message': _cognitoErrorMessage(e)};
//     } catch (e) {
//       return {'success': false, 'message': e.toString()};
//     }
//   }

//   // ── LOGIN ─────────────────────────────────────────────────────────────────
//   // Returns: { 'success': bool, 'message': String, 'user': Map? }
//   static Future<Map<String, dynamic>> login({
//     required String email,
//     required String password,
//   }) async {
//     try {
//       _currentCognitoUser = CognitoUser(email, _pool);
//       final session = await _currentCognitoUser!.authenticateUser(
//         AuthenticationDetails(username: email, password: password),
//       );

//       if (session == null || !session.isValid()) {
//         return {'success': false, 'message': 'Login failed. Please try again.'};
//       }

//       final attributes = await _currentCognitoUser!.getUserAttributes();

//       final isVerified = attributes
//               ?.firstWhere(
//                 (a) => a.name == 'email_verified',
//                 orElse: () => CognitoUserAttribute(name: 'email_verified', value: 'false'),
//               )
//               .value == 'true';

//       final name = attributes
//               ?.firstWhere(
//                 (a) => a.name == 'name',
//                 orElse: () => CognitoUserAttribute(name: 'name', value: ''),
//               )
//               .value ?? '';

//       // Get sub (Cognito's unique user ID) to use as user_id
//       final sub = attributes
//               ?.firstWhere(
//                 (a) => a.name == 'sub',
//                 orElse: () => CognitoUserAttribute(name: 'sub', value: '0'),
//               )
//               .value ?? '0';

//       final phone = attributes
//               ?.firstWhere(
//                 (a) => a.name == 'phone_number',
//                 orElse: () => CognitoUserAttribute(name: 'phone_number', value: ''),
//               )
//               .value;

//       return {
//         'success': true,
//         'message': 'Login successful!',
//         'user': {
//           // Mapped to match your User model fields exactly
//           'user_id':    sub.hashCode.abs(),
//           'email':      email,
//           'full_name':  name,
//           'phone':      (phone == null || phone.isEmpty) ? null : phone,
//           'is_verified': isVerified,
//           'created_at': DateTime.now().toIso8601String(),
//           'last_login': DateTime.now().toIso8601String(),
//           // Also keep 'name' for login_screen is_verified check
//           'name':       name,
//         },
//       };
//     } on CognitoClientException catch (e) {
//       return {'success': false, 'message': _cognitoErrorMessage(e)};
//     } catch (e) {
//       return {'success': false, 'message': e.toString()};
//     }
//   }

//   // ── SEND OTP ──────────────────────────────────────────────────────────────
//   static Future<Map<String, dynamic>> sendOtp(String email) async {
//     try {
//       await CognitoUser(email, _pool).resendConfirmationCode();
//       return {'success': true, 'message': 'OTP sent to $email'};
//     } on CognitoClientException catch (e) {
//       return {'success': false, 'message': _cognitoErrorMessage(e)};
//     } catch (e) {
//       return {'success': false, 'message': e.toString()};
//     }
//   }

//   // ── VERIFY OTP ────────────────────────────────────────────────────────────
//   static Future<Map<String, dynamic>> verifyOtp({
//     required String email,
//     required String otp,
//   }) async {
//     try {
//       final confirmed = await CognitoUser(email, _pool).confirmRegistration(otp);
//       return confirmed
//           ? {'success': true,  'message': 'Email verified successfully!'}
//           : {'success': false, 'message': 'Verification failed. Please try again.'};
//     } on CognitoClientException catch (e) {
//       return {'success': false, 'message': _cognitoErrorMessage(e)};
//     } catch (e) {
//       return {'success': false, 'message': e.toString()};
//     }
//   }

//   // ── RESEND VERIFICATION ───────────────────────────────────────────────────
//   static Future<Map<String, dynamic>> resendVerification(String email) async =>
//       sendOtp(email);

//   // ── FORGOT PASSWORD ───────────────────────────────────────────────────────
//   static Future<Map<String, dynamic>> forgotPassword(String email) async {
//     try {
//       _currentCognitoUser = CognitoUser(email, _pool);
//       await _currentCognitoUser!.forgotPassword();
//       return {'success': true, 'message': 'Reset code sent to $email'};
//     } on CognitoClientException catch (e) {
//       return {'success': false, 'message': _cognitoErrorMessage(e)};
//     } catch (e) {
//       return {'success': false, 'message': e.toString()};
//     }
//   }

//   // ── RESET PASSWORD ────────────────────────────────────────────────────────
//   static Future<Map<String, dynamic>> resetPassword({
//     required String token,
//     required String newPassword,
//   }) async {
//     try {
//       if (_currentCognitoUser == null) {
//         return {'success': false, 'message': 'Session expired. Please restart.'};
//       }
//       final confirmed = await _currentCognitoUser!.confirmPassword(token, newPassword);
//       return confirmed
//           ? {'success': true,  'message': 'Password reset successful!'}
//           : {'success': false, 'message': 'Reset failed. Please try again.'};
//     } on CognitoClientException catch (e) {
//       return {'success': false, 'message': _cognitoErrorMessage(e)};
//     } catch (e) {
//       return {'success': false, 'message': e.toString()};
//     }
//   }

//   // ── LOGOUT ────────────────────────────────────────────────────────────────
//   static Future<void> logout() async {
//     await _currentCognitoUser?.signOut();
//     _currentCognitoUser = null;
//   }

//   // ── IS LOGGED IN ──────────────────────────────────────────────────────────
//   static Future<bool> isLoggedIn() async {
//     try {
//       final user = await _pool.getCurrentUser();
//       if (user == null) return false;
//       final session = await user.getSession();
//       return session?.isValid() ?? false;
//     } catch (_) {
//       return false;
//     }
//   }

//   // ── GET ACCESS TOKEN ──────────────────────────────────────────────────────
//   static Future<String?> getAccessToken() async {
//     try {
//       final user = await _pool.getCurrentUser();
//       final session = await user?.getSession();
//       return session?.accessToken.jwtToken;
//     } catch (_) {
//       return null;
//     }
//   }

//   // ── FORMAT PHONE (E.164) ──────────────────────────────────────────────────
//   static String _formatPhone(String phone) {
//     final digits = phone.replaceAll(RegExp(r'\D'), '');
//     if (digits.length == 12 && digits.startsWith('91')) return '+$digits';
//     if (digits.length == 10) return '+91$digits';
//     if (phone.startsWith('+')) return '+$digits';
//     return '+91$digits';
//   }

//   // ── ERROR MESSAGES ────────────────────────────────────────────────────────
//   static String _cognitoErrorMessage(CognitoClientException e) {
//     switch (e.code) {
//       case 'UsernameExistsException':    return 'An account with this email already exists.';
//       case 'UserNotFoundException':      return 'No account found with this email.';
//       case 'NotAuthorizedException':     return 'Incorrect email or password.';
//       case 'CodeMismatchException':      return 'Invalid verification code. Please try again.';
//       case 'ExpiredCodeException':       return 'Code has expired. Please request a new one.';
//       case 'InvalidPasswordException':   return 'Password must be at least 8 characters with uppercase, lowercase, and numbers.';
//       case 'TooManyRequestsException':   return 'Too many attempts. Please wait and try again.';
//       case 'LimitExceededException':     return 'Attempt limit exceeded. Please try again later.';
//       case 'UserNotConfirmedException':  return 'Email not verified. Please verify your email first.';
//       case 'InvalidParameterException':  return 'Invalid input. Please check your details.';
//       default: return e.message ?? 'An error occurred. Please try again.';
//     }
//   }
// }

import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Persistent Storage ───────────────────────────────────────────────────────
class _CognitoStorage extends CognitoStorage {
  final SharedPreferences _prefs;
  _CognitoStorage(this._prefs);

  @override
  Future<String?> getItem(String key) async => _prefs.getString(key);

  @override
  Future<void> setItem(String key, dynamic value) async =>
      await _prefs.setString(key, value.toString());

  @override
  Future<void> removeItem(String key) async => await _prefs.remove(key);

  @override
  Future<void> clear() async => await _prefs.clear();
}

// ─── AuthService ──────────────────────────────────────────────────────────────
class AuthService {
    static const String _userPoolId = 'ap-south-1_TJZfocZgL';     // ← Replace
  static const String _clientId   = '2ts5mv8rhapub6lhqnsns0eue5'; // ← Replace

  static CognitoUserPool? _userPool;
  static CognitoUser? _currentCognitoUser;

  // ── Init ──────────────────────────────────────────────────────────────────
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _userPool = CognitoUserPool(_userPoolId, _clientId, storage: _CognitoStorage(prefs));
  }

  static CognitoUserPool get _pool {
    if (_userPool == null) throw Exception('Call AuthService.init() in main().');
    return _userPool!;
  }

  // ── SIGN UP ───────────────────────────────────────────────────────────────
  // Returns: { 'success': bool, 'message': String }
  static Future<Map<String, dynamic>> signup({
    required String fullName,
    required String email,
    required String password,
    String? phone,
  }) async {
    try {
      final userAttributes = [
        AttributeArg(name: 'name', value: fullName),
        if (phone != null && phone.isNotEmpty)
          AttributeArg(name: 'phone_number', value: _formatPhone(phone)),
      ];

      // Email is used directly as username (works after pool recreated with email-only sign-in)
      await _pool.signUp(email, password, userAttributes: userAttributes);

      return {'success': true, 'message': 'Account created successfully!'};
    } on CognitoClientException catch (e) {
      return {'success': false, 'message': _cognitoErrorMessage(e)};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ── LOGIN ─────────────────────────────────────────────────────────────────
  // Returns: { 'success': bool, 'message': String, 'user': Map? }
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      _currentCognitoUser = CognitoUser(email, _pool);

      CognitoUserSession? session;
      try {
        session = await _currentCognitoUser!.authenticateUser(
          AuthenticationDetails(username: email, password: password),
        );
      } on CognitoClientException catch (e) {
        debugPrint('=== Cognito Login Error ===');
        debugPrint('Code: \${e.code}');
        debugPrint('Name: \${e.name}');
        debugPrint('Message: \${e.message}');
        debugPrint('StatusCode: \${e.statusCode}');
        rethrow;
      } catch (e, stack) {
        debugPrint('=== Unknown Login Error ===');
        debugPrint('Type: \${e.runtimeType}');
        debugPrint('Error: \$e');
        debugPrint('Stack: \$stack');
        rethrow;
      }

      if (session == null || !session.isValid()) {
        return {'success': false, 'message': 'Login failed. Please try again.'};
      }

      final attributes = await _currentCognitoUser!.getUserAttributes();

      final isVerified = attributes
              ?.firstWhere(
                (a) => a.name == 'email_verified',
                orElse: () => CognitoUserAttribute(name: 'email_verified', value: 'false'),
              )
              .value == 'true';

      final name = attributes
              ?.firstWhere(
                (a) => a.name == 'name',
                orElse: () => CognitoUserAttribute(name: 'name', value: ''),
              )
              .value ?? '';

      // Get sub (Cognito's unique user ID) to use as user_id
      final sub = attributes
              ?.firstWhere(
                (a) => a.name == 'sub',
                orElse: () => CognitoUserAttribute(name: 'sub', value: '0'),
              )
              .value ?? '0';

      final phone = attributes
              ?.firstWhere(
                (a) => a.name == 'phone_number',
                orElse: () => CognitoUserAttribute(name: 'phone_number', value: ''),
              )
              .value;

      return {
        'success': true,
        'message': 'Login successful!',
        'user': {
          // Mapped to match your User model fields exactly
          'user_id':    sub.hashCode.abs(),
          'email':      email,
          'full_name':  name,
          'phone':      (phone == null || phone.isEmpty) ? null : phone,
          'is_verified': isVerified,
          'created_at': DateTime.now().toIso8601String(),
          'last_login': DateTime.now().toIso8601String(),
          // Also keep 'name' for login_screen is_verified check
          'name':       name,
        },
      };
    } on CognitoClientException catch (e) {
      return {'success': false, 'message': _cognitoErrorMessage(e)};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ── SEND OTP ──────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> sendOtp(String email) async {
    try {
      await CognitoUser(email, _pool).resendConfirmationCode();
      return {'success': true, 'message': 'OTP sent to $email'};
    } on CognitoClientException catch (e) {
      return {'success': false, 'message': _cognitoErrorMessage(e)};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ── VERIFY OTP ────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> verifyOtp({
    required String email,
    required String otp,
  }) async {
    try {
      final confirmed = await CognitoUser(email, _pool).confirmRegistration(otp);
      return confirmed
          ? {'success': true,  'message': 'Email verified successfully!'}
          : {'success': false, 'message': 'Verification failed. Please try again.'};
    } on CognitoClientException catch (e) {
      return {'success': false, 'message': _cognitoErrorMessage(e)};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ── RESEND VERIFICATION ───────────────────────────────────────────────────
  static Future<Map<String, dynamic>> resendVerification(String email) async =>
      sendOtp(email);

  // ── FORGOT PASSWORD ───────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      _currentCognitoUser = CognitoUser(email, _pool);
      await _currentCognitoUser!.forgotPassword();
      return {'success': true, 'message': 'Reset code sent to $email'};
    } on CognitoClientException catch (e) {
      return {'success': false, 'message': _cognitoErrorMessage(e)};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ── RESET PASSWORD ────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      if (_currentCognitoUser == null) {
        return {'success': false, 'message': 'Session expired. Please restart.'};
      }
      final confirmed = await _currentCognitoUser!.confirmPassword(token, newPassword);
      return confirmed
          ? {'success': true,  'message': 'Password reset successful!'}
          : {'success': false, 'message': 'Reset failed. Please try again.'};
    } on CognitoClientException catch (e) {
      return {'success': false, 'message': _cognitoErrorMessage(e)};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ── LOGOUT ────────────────────────────────────────────────────────────────
  static Future<void> logout() async {
    await _currentCognitoUser?.signOut();
    _currentCognitoUser = null;
  }

  // ── IS LOGGED IN ──────────────────────────────────────────────────────────
  static Future<bool> isLoggedIn() async {
    try {
      final user = await _pool.getCurrentUser();
      if (user == null) return false;
      final session = await user.getSession();
      return session?.isValid() ?? false;
    } catch (_) {
      return false;
    }
  }

  // ── GET ACCESS TOKEN ──────────────────────────────────────────────────────
  static Future<String?> getAccessToken() async {
    try {
      final user = await _pool.getCurrentUser();
      final session = await user?.getSession();
      return session?.accessToken.jwtToken;
    } catch (_) {
      return null;
    }
  }

  // ── FORMAT PHONE (E.164) ──────────────────────────────────────────────────
  static String _formatPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('91')) return '+$digits';
    if (digits.length == 10) return '+91$digits';
    if (phone.startsWith('+')) return '+$digits';
    return '+91$digits';
  }

  // ── ERROR MESSAGES ────────────────────────────────────────────────────────
  static String _cognitoErrorMessage(CognitoClientException e) {
    switch (e.code) {
      case 'UsernameExistsException':    return 'An account with this email already exists.';
      case 'UserNotFoundException':      return 'No account found with this email.';
      case 'NotAuthorizedException':     return 'Incorrect email or password.';
      case 'CodeMismatchException':      return 'Invalid verification code. Please try again.';
      case 'ExpiredCodeException':       return 'Code has expired. Please request a new one.';
      case 'InvalidPasswordException':   return 'Password must be at least 8 characters with uppercase, lowercase, and numbers.';
      case 'TooManyRequestsException':   return 'Too many attempts. Please wait and try again.';
      case 'LimitExceededException':     return 'Attempt limit exceeded. Please try again later.';
      case 'UserNotConfirmedException':  return 'Email not verified. Please verify your email first.';
      case 'InvalidParameterException':  return 'Invalid input. Please check your details.';
      default: return e.message ?? 'An error occurred. Please try again.';
    }
  }
}