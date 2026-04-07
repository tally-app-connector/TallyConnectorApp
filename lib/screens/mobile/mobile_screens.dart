library mobile_screens;

/// Barrel file for all mobile-only screens.
/// Import this single file when adding mobile screens to AppShell.
///
/// IMPORTANT: Do NOT import desktop screens here.
/// Do NOT use desktop widgets (lib/screens/desktop/) in mobile screens.
/// Shared logic goes in lib/services/, lib/models/, lib/utils/.

export 'dashboard_screen.dart';
export 'reports_overview_screen.dart';
export 'reports_screen.dart';
export 'mobile_profile_tab.dart';
export 'database_overview_screen.dart';
export 'metric_detail_screen.dart';
export 'outstanding_detail_screen.dart';
export 'Recevaible_screen.dart';
export 'excel_export_screen.dart';
export 'pdf_export_screen.dart';
export 'kpi_manager_screen.dart';
export 'net_sales_detail_screen.dart';
export 'group_outstanding_detail_screen.dart';
