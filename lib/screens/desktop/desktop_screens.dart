library desktop_screens;

/// Barrel file for all desktop-only screens.
/// Import this single file when adding desktop screens to AppShell.
///
/// IMPORTANT: Do NOT import mobile screens here.
/// Do NOT use mobile widgets (lib/screens/mobile/) in desktop screens.
/// Shared logic goes in lib/services/, lib/models/, lib/utils/.

export 'setting_screen.dart';
export 'database_viewer_screen.dart';
