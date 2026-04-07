import 'dart:io';
import 'dart:developer' as developer;

/// Bot that automatically finds Tally Prime installation and enables
/// the XML API server on port 9000 by modifying tally.ini.
class TallySetupBot {
  /// Common Tally installation paths to search.
  static const List<String> _searchPaths = [
    r'C:\TallyPrime',
    r'C:\Tally\TallyPrime',
    r'C:\Program Files\TallyPrime',
    r'C:\Program Files (x86)\TallyPrime',
    r'C:\Tally.ERP9',
    r'C:\Tally\Tally.ERP9',
    r'C:\Program Files\Tally.ERP9',
    r'C:\Program Files (x86)\Tally.ERP9',
    r'D:\TallyPrime',
    r'D:\Tally\TallyPrime',
    r'D:\Tally.ERP9',
    r'E:\TallyPrime',
    r'E:\Tally.ERP9',
  ];

  /// Result of setup bot operation.
  static Future<TallySetupResult> autoConfigureTally() async {
    try {
      // Step 1: Check if Tally is already accessible
      final alreadyRunning = await _isTallyAccessible();
      if (alreadyRunning) {
        return TallySetupResult(
          success: true,
          message: 'Tally is already running and accessible on port 9000.',
          step: TallySetupStep.alreadyConfigured,
        );
      }

      // Step 2: Find Tally installation
      final tallyPath = await _findTallyInstallation();
      if (tallyPath == null) {
        return TallySetupResult(
          success: false,
          message: 'Could not find Tally installation. '
              'Please configure manually:\n\n'
              '1. Open Tally Prime\n'
              '2. Press F1 (Help)\n'
              '3. Click Settings\n'
              '4. Go to Connectivity\n'
              '5. Set Client/Server > Acting as: Both\n'
              '6. Set Port: 9000\n'
              '7. Press Ctrl+A to save',
          step: TallySetupStep.tallyNotFound,
        );
      }

      // Step 3: Find and modify tally.ini
      final iniPath = '$tallyPath\\tally.ini';
      final iniFile = File(iniPath);

      if (!iniFile.existsSync()) {
        // Create tally.ini with server config
        await _createTallyIni(iniFile);
        return TallySetupResult(
          success: true,
          message: 'Created tally.ini with API server enabled on port 9000 '
              'at:\n$iniPath\n\n'
              'Please restart Tally Prime for changes to take effect.',
          step: TallySetupStep.configCreated,
          tallyPath: tallyPath,
        );
      }

      // Step 4: Read and modify existing tally.ini
      final modified = await _modifyTallyIni(iniFile);
      if (!modified) {
        return TallySetupResult(
          success: true,
          message: 'Tally API server is already configured in tally.ini.\n'
              'Make sure Tally Prime is running.\n\n'
              'Path: $iniPath',
          step: TallySetupStep.alreadyInConfig,
          tallyPath: tallyPath,
        );
      }

      return TallySetupResult(
        success: true,
        message: 'Tally API server enabled on port 9000!\n\n'
            'Config updated at:\n$iniPath\n\n'
            'Please restart Tally Prime for changes to take effect.',
        step: TallySetupStep.configUpdated,
        tallyPath: tallyPath,
      );
    } catch (e) {
      developer.log('TallySetupBot error: $e');
      return TallySetupResult(
        success: false,
        message: 'Error configuring Tally: $e\n\n'
            'Please configure manually using F1 > Settings > Connectivity.',
        step: TallySetupStep.error,
      );
    }
  }

  /// Check if Tally is currently accessible on port 9000.
  static Future<bool> _isTallyAccessible() async {
    try {
      final socket = await Socket.connect(
        'localhost',
        9000,
        timeout: const Duration(seconds: 3),
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Public method to check Tally connectivity.
  static Future<bool> isTallyRunning() => _isTallyAccessible();

  /// Find Tally installation directory.
  static Future<String?> _findTallyInstallation() async {
    // Check common paths
    for (final path in _searchPaths) {
      final dir = Directory(path);
      if (dir.existsSync()) {
        // Verify it's actually a Tally installation (has tally.exe)
        final exeVariants = [
          '$path\\tally.exe',
          '$path\\TallyPrime.exe',
          '$path\\Tally.ERP9.exe',
        ];
        for (final exe in exeVariants) {
          if (File(exe).existsSync()) return path;
        }
        // Even without exe, if dir exists with Tally in name, likely valid
        return path;
      }
    }

    // Try to find via Windows registry (where command)
    try {
      final result = await Process.run(
        'where',
        ['tally.exe'],
        runInShell: true,
      );
      if (result.exitCode == 0) {
        final path = (result.stdout as String).trim().split('\n').first.trim();
        return File(path).parent.path;
      }
    } catch (_) {}

    // Try to find via running process
    try {
      final result = await Process.run(
        'wmic',
        ['process', 'where', 'name like "%tally%"', 'get', 'ExecutablePath'],
        runInShell: true,
      );
      if (result.exitCode == 0) {
        final output = (result.stdout as String).trim();
        final lines = output.split('\n').where((l) => l.trim().isNotEmpty && !l.contains('ExecutablePath')).toList();
        if (lines.isNotEmpty) {
          return File(lines.first.trim()).parent.path;
        }
      }
    } catch (_) {}

    return null;
  }

  /// Create a new tally.ini with server configuration.
  static Future<void> _createTallyIni(File iniFile) async {
    const config = '''[Tally]
; Tally Connector - Auto-configured API server
Default Companies = Yes
Load Companies on Startup = Yes

[StartupInfo]
TallyPrime Server Port = 9000
Enable ODBC Server = Yes
ODBC Port = 9000
''';
    await iniFile.writeAsString(config);
  }

  /// Modify existing tally.ini to enable the API server.
  /// Returns true if modifications were made.
  static Future<bool> _modifyTallyIni(File iniFile) async {
    String content = await iniFile.readAsString();
    final originalContent = content;

    // Check if server port is already configured
    final hasPort = RegExp(r'(?:TallyPrime\s+Server\s+Port|ODBC\s+Port)\s*=\s*\d+', caseSensitive: false)
        .hasMatch(content);

    if (hasPort) {
      // Port is already set — check if it's 9000
      final portMatch = RegExp(r'(TallyPrime\s+Server\s+Port\s*=\s*)(\d+)', caseSensitive: false)
          .firstMatch(content);
      if (portMatch != null && portMatch.group(2) == '9000') {
        return false; // Already configured correctly
      }
      // Update port to 9000
      content = content.replaceAllMapped(
        RegExp(r'(TallyPrime\s+Server\s+Port\s*=\s*)\d+', caseSensitive: false),
        (m) => '${m.group(1)}9000',
      );
      content = content.replaceAllMapped(
        RegExp(r'(ODBC\s+Port\s*=\s*)\d+', caseSensitive: false),
        (m) => '${m.group(1)}9000',
      );
    } else {
      // Add server config at the end
      if (!content.endsWith('\n')) content += '\n';
      content += '''
; Tally Connector - Auto-configured API server
[StartupInfo]
TallyPrime Server Port = 9000
Enable ODBC Server = Yes
ODBC Port = 9000
''';
    }

    if (content == originalContent) return false;

    // Backup original file
    final backupPath = '${iniFile.path}.backup';
    if (!File(backupPath).existsSync()) {
      await iniFile.copy(backupPath);
    }

    await iniFile.writeAsString(content);
    return true;
  }

  /// Launch Tally Prime from the found installation path.
  static Future<bool> launchTally(String tallyPath) async {
    final exeVariants = [
      '$tallyPath\\TallyPrime.exe',
      '$tallyPath\\tally.exe',
      '$tallyPath\\Tally.ERP9.exe',
    ];

    for (final exe in exeVariants) {
      if (File(exe).existsSync()) {
        try {
          await Process.start(exe, [], mode: ProcessStartMode.detached);
          return true;
        } catch (e) {
          developer.log('Failed to launch Tally: $e');
        }
      }
    }
    return false;
  }
}

// ── Result classes ───────────────────────────────────────────────────────────

enum TallySetupStep {
  alreadyConfigured,
  tallyNotFound,
  configCreated,
  configUpdated,
  alreadyInConfig,
  error,
}

class TallySetupResult {
  final bool success;
  final String message;
  final TallySetupStep step;
  final String? tallyPath;

  const TallySetupResult({
    required this.success,
    required this.message,
    required this.step,
    this.tallyPath,
  });
}
