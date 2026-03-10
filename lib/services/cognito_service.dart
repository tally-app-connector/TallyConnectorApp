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
//   static const String _userPoolId = 'ap-south-1_DerdR5W8N';     // ← Replace
//   static const String _clientId   = '7ptt7a50h0pktrvmjhhall05m7'; // ← Replace

//   static CognitoUserPool? _userPool;
//   static CognitoUser? _currentCognitoUser;

//   // ── Init pool (call once in main) ─────────────────────────────────────────
//   static Future<void> init() async {
//     final prefs = await SharedPreferences.getInstance();
//     final storage = _CognitoStorage(prefs);
//     _userPool = CognitoUserPool(_userPoolId, _clientId, storage: storage);
//   }

//   static CognitoUserPool get _pool {
//     if (_userPool == null) throw Exception('AuthService not initialized. Call AuthService.init() in main().');
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
//         AttributeArg(name: 'email', value: email),
//         AttributeArg(name: 'name',  value: fullName),
//         if (phone != null && phone.isNotEmpty)
//           AttributeArg(name: 'phone_number', value: phone),
//       ];

//       await _pool.signUp(email, password, userAttributes: userAttributes);

//       return {
//         'success': true,
//         'message': 'Account created successfully!',
//       };
//     } on CognitoClientException catch (e) {
//       return {
//         'success': false,
//         'message': _cognitoErrorMessage(e),
//       };
//     } catch (e) {
//       return {
//         'success': false,
//         'message': e.toString(),
//       };
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
//       final authDetails = AuthenticationDetails(
//         username: email,
//         password: password,
//       );

//       final session = await _currentCognitoUser!.authenticateUser(authDetails);

//       if (session == null || !session.isValid()) {
//         return {'success': false, 'message': 'Login failed. Please try again.'};
//       }

//       // Get user attributes to check verification status
//       final attributes = await _currentCognitoUser!.getUserAttributes();
//       final emailVerified = attributes
//           ?.firstWhere(
//             (a) => a.name == 'email_verified',
//             orElse: () => CognitoUserAttribute(name: 'email_verified', value: 'false'),
//           )
//           .value == 'true';

//       final nameAttr = attributes
//           ?.firstWhere(
//             (a) => a.name == 'name',
//             orElse: () => CognitoUserAttribute(name: 'name', value: ''),
//           )
//           .value ?? '';

//       return {
//         'success': true,
//         'message': 'Login successful!',
//         'user': {
//           'email': email,
//           'name': nameAttr,
//           'is_verified': emailVerified,
//         },
//       };
//     } on CognitoClientException catch (e) {
//       return {
//         'success': false,
//         'message': _cognitoErrorMessage(e),
//       };
//     } catch (e) {
//       return {
//         'success': false,
//         'message': e.toString(),
//       };
//     }
//   }

//   // ── SEND OTP (confirm signup code) ────────────────────────────────────────
//   // Returns: { 'success': bool, 'message': String }
//   static Future<Map<String, dynamic>> sendOtp(String email) async {
//     try {
//       final user = CognitoUser(email, _pool);
//       await user.resendConfirmationCode();
//       return {
//         'success': true,
//         'message': 'OTP sent to $email',
//       };
//     } on CognitoClientException catch (e) {
//       return {
//         'success': false,
//         'message': _cognitoErrorMessage(e),
//       };
//     } catch (e) {
//       return {
//         'success': false,
//         'message': e.toString(),
//       };
//     }
//   }

//   // ── VERIFY OTP ────────────────────────────────────────────────────────────
//   // Returns: { 'success': bool, 'message': String }
//   static Future<Map<String, dynamic>> verifyOtp({
//     required String email,
//     required String otp,
//   }) async {
//     try {
//       final user = CognitoUser(email, _pool);
//       final confirmed = await user.confirmRegistration(otp);
//       if (confirmed) {
//         return {
//           'success': true,
//           'message': 'Email verified successfully!',
//         };
//       }
//       return {
//         'success': false,
//         'message': 'Verification failed. Please try again.',
//       };
//     } on CognitoClientException catch (e) {
//       return {
//         'success': false,
//         'message': _cognitoErrorMessage(e),
//       };
//     } catch (e) {
//       return {
//         'success': false,
//         'message': e.toString(),
//       };
//     }
//   }

//   // ── RESEND VERIFICATION EMAIL (link) ──────────────────────────────────────
//   // Cognito sends OTP code via email — same as sendOtp
//   // Returns: { 'success': bool, 'message': String }
//   static Future<Map<String, dynamic>> resendVerification(String email) async {
//     return sendOtp(email);
//   }

//   // ── FORGOT PASSWORD ───────────────────────────────────────────────────────
//   // Sends reset code to email
//   // Returns: { 'success': bool, 'message': String }
//   static Future<Map<String, dynamic>> forgotPassword(String email) async {
//     try {
//       _currentCognitoUser = CognitoUser(email, _pool);
//       await _currentCognitoUser!.forgotPassword();
//       return {
//         'success': true,
//         'message': 'Reset code sent to $email',
//       };
//     } on CognitoClientException catch (e) {
//       return {
//         'success': false,
//         'message': _cognitoErrorMessage(e),
//       };
//     } catch (e) {
//       return {
//         'success': false,
//         'message': e.toString(),
//       };
//     }
//   }

//   // ── RESET PASSWORD ────────────────────────────────────────────────────────
//   // token = the code received in email
//   // Returns: { 'success': bool, 'message': String }
//   static Future<Map<String, dynamic>> resetPassword({
//     required String token,
//     required String newPassword,
//   }) async {
//     try {
//       if (_currentCognitoUser == null) {
//         return {
//           'success': false,
//           'message': 'Session expired. Please restart forgot password flow.',
//         };
//       }
//       final confirmed = await _currentCognitoUser!.confirmPassword(token, newPassword);
//       if (confirmed) {
//         return {
//           'success': true,
//           'message': 'Password reset successful!',
//         };
//       }
//       return {
//         'success': false,
//         'message': 'Reset failed. Please try again.',
//       };
//     } on CognitoClientException catch (e) {
//       return {
//         'success': false,
//         'message': _cognitoErrorMessage(e),
//       };
//     } catch (e) {
//       return {
//         'success': false,
//         'message': e.toString(),
//       };
//     }
//   }

//   // ── LOGOUT ────────────────────────────────────────────────────────────────
//   static Future<void> logout() async {
//     await _currentCognitoUser?.signOut();
//     _currentCognitoUser = null;
//   }

//   // ── CHECK IF LOGGED IN ────────────────────────────────────────────────────
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

//   // ── FRIENDLY ERROR MESSAGES ───────────────────────────────────────────────
//   static String _cognitoErrorMessage(CognitoClientException e) {
//     switch (e.code) {
//       case 'UsernameExistsException':
//         return 'An account with this email already exists.';
//       case 'UserNotFoundException':
//         return 'No account found with this email.';
//       case 'NotAuthorizedException':
//         return 'Incorrect email or password.';
//       case 'CodeMismatchException':
//         return 'Invalid verification code. Please try again.';
//       case 'ExpiredCodeException':
//         return 'Verification code has expired. Please request a new one.';
//       case 'InvalidPasswordException':
//         return 'Password must be at least 8 characters with uppercase, lowercase, and numbers.';
//       case 'TooManyRequestsException':
//         return 'Too many attempts. Please wait a moment and try again.';
//       case 'LimitExceededException':
//         return 'Attempt limit exceeded. Please try again later.';
//       case 'UserNotConfirmedException':
//         return 'Email not verified. Please verify your email first.';
//       case 'InvalidParameterException':
//         return 'Invalid input. Please check your details.';
//       default:
//         return e.message ?? 'An error occurred. Please try again.';
//     }
//   }
// }