import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFFF7F8FA);
  static const surface = Colors.white;
  static const textPrimary = Color(0xFF1A1A2E);
  static const textSecondary = Color(0xFF9CA3AF);
  static const divider = Color(0xFFE5E7EB);
  static const blue = Color(0xFF2D8BE0);
  static const green = Color(0xFF16A34A);
  static const red = Color(0xFFEF4444);
  static const amber = Color(0xFFF59E0B);
  static const purple = Color(0xFF8B5CF6);
  static const iconBgBlue = Color(0xFFEBF5FF);
  static const iconBgGreen = Color(0xFFECFDF5);
  static const iconBgAmber = Color(0xFFFFFBEB);
  static const iconBgPurple = Color(0xFFF5F3FF);
  static const iconBgRed = Color(0xFFFEF2F2);
  static const pillBg = Color(0xFFF3F4F6);
}

class AppTypography {
  static const String fontBody = 'Inter';
  static const String fontSerif = 'Inter';

  static const dashboardLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.5,
    color: AppColors.textSecondary,
  );

  static const companyName = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle cardLabel = const TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    color: AppColors.textSecondary,
  );

  static const cardValue = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  static const cardUnit = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static TextStyle pageTitle = const TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static TextStyle itemTitle = const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle itemSubtitle = const TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
  );

  static TextStyle chartAxisLabel = const TextStyle(
    fontSize: 11,
    color: AppColors.textSecondary,
  );

  static TextStyle badge = const TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
  );

  static TextStyle pillActive = const TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static TextStyle pillInactive = const TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );
}

class AppSpacing {
  static const double pagePadding = 20.0;
  static const double cardGap = 12.0;
  static const double sectionGap = 20.0;
}

class AppRadius {
  static const double card = 14.0;
  static const double pill = 20.0;
  static const double pillInner = 16.0;
}

class AppShadows {
  static List<BoxShadow> card = [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 12,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> headerIcon = [
    BoxShadow(
      color: Colors.black.withOpacity(0.03),
      blurRadius: 8,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> pillActive = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];
}
