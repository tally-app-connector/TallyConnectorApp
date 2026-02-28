class ApiConfig {
  // 🌍 PRODUCTION - Your Live API
  static const String baseUrl = 'https://tally-connector-backend.onrender.com/api';
  
  // 💻 LOCAL DEVELOPMENT - Uncomment when testing locally
  // static const String baseUrl = 'http://localhost:8000/api';
  
  static const String signup = '$baseUrl/auth/signup';
  static const String login = '$baseUrl/auth/login';
  static const String forgotPassword = '$baseUrl/auth/forgot-password';
  static const String resetPassword = '$baseUrl/auth/reset-password';
  static const String getCurrentUser = '$baseUrl/auth/me';
  static const String logout = '$baseUrl/auth/logout';
  static const String verifyEmail = '$baseUrl/auth/verify-email';
  static const String resendVerification = '$baseUrl/auth/resend-verification';
  static const String sendOtp = '$baseUrl/auth/send-otp';
  static const String verifyOtp = '$baseUrl/auth/verify-otp';
  
  static const Duration timeout = Duration(seconds: 60);
}

class NeonConfig {
  // Neon Database Configuration
  static const String host = 'ep-green-breeze-a12cch4d-pooler.ap-southeast-1.aws.neon.tech';
  static const String database = 'neondb';
  static const String username = 'neondb_owner';
  static const String password = 'npg_uKXI6pTWZNh3';
  
  // Connection settings
  static const int connectTimeout = 60; // seconds
  static const int queryTimeout = 60; // seconds
}

// config/api_config.dart
// Add this class to your existing api_config.dart file

class AwsAuroraConfig {
  // ===========================================
  // AWS Aurora Serverless v2 Configuration
  // ===========================================

  // Your Aurora Writer Endpoint
  static const String host =
      'tally-cloud-sync-db-instance-1.cp8em48qwti1.ap-south-1.rds.amazonaws.com';

  // Default database (change if you created a custom one)
  static const String database = 'postgres';

  // Your master username
  static const String username = 'tally_admin';

  // Your password from AWS Secrets Manager
  // TODO: Replace with your actual password or load from secure storage => rHa_m6uUnA)$3c)b:?M6Y7]sLLH$
  static const String password = 'rHa_m6uUnA)\$3c)b:?M6Y7]sLLH\$';

  // Port (default PostgreSQL)
  static const int port = 5432;

  // Connection timeouts (slightly higher for Aurora cold starts)
  static const int connectTimeout = 30; // seconds
  static const int queryTimeout = 60; // seconds
}