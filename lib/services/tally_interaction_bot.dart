import 'dart:io';
import 'dart:async';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Bot that interacts directly with a running Tally Prime window
/// using Windows UI Automation (PowerShell + SendKeys).
///
/// Also captures screenshots of the Tally window after each action
/// and verifies step completion.
class TallyInteractionBot {
  /// Callback for step progress updates.
  final void Function(TallyBotEvent event)? onEvent;

  TallyInteractionBot({this.onEvent});

  // ── Public API ──────────────────────────────────────────────────────────

  /// Run the full automation sequence to enable Tally's API server.
  /// Returns true if all steps completed successfully.
  Future<bool> runFullSetup() async {
    try {
      // Step 1: Check if Tally is running
      _emit(TallyBotEvent(
        step: TallyBotStep.findTally,
        status: StepStatus.running,
        message: 'Looking for Tally Prime...',
      ));

      final tallyRunning = await isTallyProcessRunning();
      if (!tallyRunning) {
        _emit(TallyBotEvent(
          step: TallyBotStep.findTally,
          status: StepStatus.failed,
          message: 'Tally Prime is not running. Please open Tally first.',
        ));
        return false;
      }

      _emit(TallyBotEvent(
        step: TallyBotStep.findTally,
        status: StepStatus.done,
        message: 'Tally Prime found and running.',
      ));

      // Step 2: Bring Tally window to foreground
      _emit(TallyBotEvent(
        step: TallyBotStep.focusTally,
        status: StepStatus.running,
        message: 'Bringing Tally to foreground...',
      ));

      final focused = await _focusTallyWindow();
      if (!focused) {
        _emit(TallyBotEvent(
          step: TallyBotStep.focusTally,
          status: StepStatus.failed,
          message: 'Could not focus Tally window. Please bring Tally to '
              'front manually and try again.',
        ));
        return false;
      }
      await Future.delayed(const Duration(milliseconds: 800));
      await _captureScreen(TallyBotStep.focusTally);

      _emit(TallyBotEvent(
        step: TallyBotStep.focusTally,
        status: StepStatus.done,
        message: 'Tally window focused.',
      ));

      // Step 3: Open Help menu (F1)
      _emit(TallyBotEvent(
        step: TallyBotStep.openHelp,
        status: StepStatus.running,
        message: 'Opening F1 > Settings > Connectivity...',
      ));

      // Press F1 to open Help menu
      await _sendKeys('{F1}');
      await Future.delayed(const Duration(milliseconds: 1000));

      _emit(TallyBotEvent(
        step: TallyBotStep.openHelp,
        status: StepStatus.done,
        message: 'Help menu opened.',
      ));

      // Step 4: Navigate F1 > Settings > Connectivity
      _emit(TallyBotEvent(
        step: TallyBotStep.openSettings,
        status: StepStatus.running,
        message: 'Navigating to Settings > Connectivity...',
      ));

      // From the F1 Help menu:
      //   "Settings" has a submenu (arrow >) with items:
      //   License, Language, Country, Startup, Display, Connectivity
      //
      // Navigation: arrow down to "Settings", then arrow right to
      // open submenu, then arrow down to "Connectivity", then Enter.

      // Navigate down to "Settings" in the Help menu
      // Help menu order: TallyHelp, What's New, Upgrade, TallyShop,
      //                  Troubleshooting, Settings
      // So 5 arrow-downs to reach Settings
      for (int i = 0; i < 5; i++) {
        await _sendKeys('{DOWN}');
        await Future.delayed(const Duration(milliseconds: 150));
      }
      await Future.delayed(const Duration(milliseconds: 300));

      // Arrow right to open the Settings submenu
      await _sendKeys('{RIGHT}');
      await Future.delayed(const Duration(milliseconds: 500));

      // Navigate down to "Connectivity" in the submenu
      // Submenu order: License, Language, Country, Startup, Display, Connectivity
      // So 5 arrow-downs to reach Connectivity
      for (int i = 0; i < 5; i++) {
        await _sendKeys('{DOWN}');
        await Future.delayed(const Duration(milliseconds: 150));
      }
      await Future.delayed(const Duration(milliseconds: 200));

      // Press Enter to open Connectivity Settings
      await _sendKeys('{ENTER}');
      await Future.delayed(const Duration(milliseconds: 1200));
      await _captureScreen(TallyBotStep.openSettings);

      _emit(TallyBotEvent(
        step: TallyBotStep.openSettings,
        status: StepStatus.done,
        message: 'Connectivity Settings opened.',
      ));

      // Step 5: Open Client/Server config and set values
      _emit(TallyBotEvent(
        step: TallyBotStep.configurePort,
        status: StepStatus.running,
        message: 'Configuring Client/Server...',
      ));

      await _configureClientServer();
      await Future.delayed(const Duration(milliseconds: 500));
      await _captureScreen(TallyBotStep.configurePort);

      _emit(TallyBotEvent(
        step: TallyBotStep.configurePort,
        status: StepStatus.done,
        message: 'Set: Acts as=Both, ODBC=Yes, Port=9000.',
      ));

      // Step 6: Save — Ctrl+A to Accept the Client/Server dialog,
      // then Ctrl+A again to Accept the outer Settings screen.
      _emit(TallyBotEvent(
        step: TallyBotStep.saveSettings,
        status: StepStatus.running,
        message: 'Saving settings...',
      ));

      // Accept Client/Server configuration dialog
      await _sendKeys('^a');
      await Future.delayed(const Duration(milliseconds: 800));

      // Accept outer Connectivity Settings screen
      await _sendKeys('^a');
      await Future.delayed(const Duration(milliseconds: 1500));

      // Tally shows "Restart TallyPrime to apply the changes? Yes or No"
      // Press Y to confirm restart
      await _sendKeys('Y');
      await Future.delayed(const Duration(milliseconds: 3000));
      await _captureScreen(TallyBotStep.saveSettings);

      _emit(TallyBotEvent(
        step: TallyBotStep.saveSettings,
        status: StepStatus.done,
        message: 'Settings saved. Tally is restarting...',
      ));

      // Step 7: Verify port is now accessible
      _emit(TallyBotEvent(
        step: TallyBotStep.verify,
        status: StepStatus.running,
        message: 'Waiting for Tally to restart...',
      ));

      // Wait for Tally to restart and start listening on port 9000.
      // Retry up to 10 times with 2-second intervals (20 seconds total).
      bool portOpen = false;
      for (int i = 0; i < 10; i++) {
        await Future.delayed(const Duration(seconds: 2));
        portOpen = await isTallyPortOpen();
        if (portOpen) break;
        _emit(TallyBotEvent(
          step: TallyBotStep.verify,
          status: StepStatus.running,
          message: 'Waiting for Tally to restart... (${i + 1}/10)',
        ));
      }
      if (portOpen) {
        _emit(TallyBotEvent(
          step: TallyBotStep.verify,
          status: StepStatus.done,
          message: 'Tally API server is running on port 9000!',
        ));
        return true;
      } else {
        _emit(TallyBotEvent(
          step: TallyBotStep.verify,
          status: StepStatus.failed,
          message:
              'Port 9000 is not yet accessible. You may need to restart Tally '
              'or configure manually via F1 > Settings > Connectivity.',
        ));
        return false;
      }
    } catch (e) {
      developer.log('TallyInteractionBot error: $e');
      _emit(TallyBotEvent(
        step: TallyBotStep.verify,
        status: StepStatus.failed,
        message: 'Automation error: $e',
      ));
      return false;
    }
  }

  // ── Verification checks (used by StepMonitor) ──────────────────────────

  /// Check if tally.exe (or TallyPrime.exe) process is running.
  static Future<bool> isTallyProcessRunning() async {
    try {
      final result = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-Command',
          'Get-Process | Where-Object { \$_.ProcessName -eq "tally" -or \$_.MainWindowTitle -match "TallyPrime" } | Select-Object -First 1 | ForEach-Object { \$_.ProcessName }',
        ],
        runInShell: true,
      );
      final output = (result.stdout as String).trim();
      return output.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Check if a Tally window with a company open exists.
  static Future<String?> getTallyWindowTitle() async {
    try {
      final result = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-Command',
          'Get-Process | Where-Object { (\$_.ProcessName -eq "tally" -or \$_.MainWindowTitle -match "TallyPrime") -and \$_.MainWindowTitle -ne "" } | Select-Object -First 1 -ExpandProperty MainWindowTitle',
        ],
        runInShell: true,
      );
      final title = (result.stdout as String).trim();
      return title.isNotEmpty ? title : null;
    } catch (_) {
      return null;
    }
  }

  /// Check if Tally is accepting connections on port 9000.
  static Future<bool> isTallyPortOpen() async {
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

  /// Check if Tally responds to an XML company list request.
  static Future<bool> canFetchCompanies() async {
    try {
      const xml = '''<ENVELOPE>
<HEADER><VERSION>1</VERSION><TALLYREQUEST>Export</TALLYREQUEST><TYPE>Collection</TYPE><ID>CompanyList</ID></HEADER>
<BODY><DESC><STATICVARIABLES><SVEXPORTFORMAT>\$\$SysName:XML</SVEXPORTFORMAT></STATICVARIABLES><TDL><TDLMESSAGE><COLLECTION NAME="CompanyList" ISMODIFY="No"><TYPE>Company</TYPE><FETCH>NAME</FETCH></COLLECTION></TDLMESSAGE></TDL></DESC></BODY>
</ENVELOPE>''';

      final response = await http
          .post(
            Uri.parse('http://localhost:9000'),
            headers: {'Content-Type': 'application/xml'},
            body: xml,
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200 &&
          response.body.contains('ENVELOPE');
    } catch (_) {
      return false;
    }
  }

  /// Capture a screenshot of the entire screen and save to temp dir.
  /// Returns the file path of the screenshot, or null on failure.
  static Future<String?> captureScreenshot({String? label}) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = label != null
          ? 'tally_${label}_$timestamp.png'
          : 'tally_screenshot_$timestamp.png';
      final filePath = '${tempDir.path}\\$fileName';

      final psScript = '''
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

\$screen = [System.Windows.Forms.Screen]::PrimaryScreen
\$bounds = \$screen.Bounds
\$bitmap = New-Object System.Drawing.Bitmap(\$bounds.Width, \$bounds.Height)
\$graphics = [System.Drawing.Graphics]::FromImage(\$bitmap)
\$graphics.CopyFromScreen(\$bounds.Location, [System.Drawing.Point]::Empty, \$bounds.Size)
\$bitmap.Save("$filePath", [System.Drawing.Imaging.ImageFormat]::Png)
\$graphics.Dispose()
\$bitmap.Dispose()
Write-Output "OK"
''';

      final result = await Process.run(
        'powershell',
        ['-NoProfile', '-Command', psScript],
        runInShell: true,
      );

      if ((result.stdout as String).trim().contains('OK') &&
          File(filePath).existsSync()) {
        return filePath;
      }
      return null;
    } catch (e) {
      developer.log('Screenshot failed: $e');
      return null;
    }
  }

  // ── Private automation methods ─────────────────────────────────────────

  void _emit(TallyBotEvent event) {
    onEvent?.call(event);
  }

  /// Bring the Tally window to the foreground.
  Future<bool> _focusTallyWindow() async {
    try {
      // Use AppActivate with window title pattern — works across sessions.
      // Also combine with SendKeys in one PowerShell call to stay in the
      // same COM context.
      final result = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-Command',
          'Add-Type -AssemblyName System.Windows.Forms; '
              '\$w = New-Object -ComObject WScript.Shell; '
              'if (\$w.AppActivate("TallyPrime")) { Write-Output "OK" } '
              'else { Write-Output "FAIL" }',
        ],
        runInShell: true,
      );
      final output = (result.stdout as String).trim();
      if (output.contains('OK')) return true;

      // Fallback: try activating by process name "tally"
      final result2 = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-Command',
          'Add-Type -AssemblyName System.Windows.Forms; '
              '\$w = New-Object -ComObject WScript.Shell; '
              'if (\$w.AppActivate("tally")) { Write-Output "OK" } '
              'else { Write-Output "FAIL" }',
        ],
        runInShell: true,
      );
      return (result2.stdout as String).trim().contains('OK');
    } catch (e) {
      developer.log('Focus Tally failed: $e');
      return false;
    }
  }

  /// Send keystrokes to the Tally window via PowerShell.
  /// Always re-activates the Tally window before sending keys to ensure
  /// the right window receives them.
  Future<void> _sendKeys(String keys) async {
    try {
      await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-Command',
          'Add-Type -AssemblyName System.Windows.Forms; '
              '\$w = New-Object -ComObject WScript.Shell; '
              '\$w.AppActivate("TallyPrime") | Out-Null; '
              'Start-Sleep -Milliseconds 300; '
              '[System.Windows.Forms.SendKeys]::SendWait("$keys")',
        ],
        runInShell: true,
      );
    } catch (e) {
      developer.log('SendKeys failed: $e');
    }
  }

  /// Navigate inside Tally Settings to the Connectivity section
  /// and configure the server.
  ///
  /// Tally Prime Settings UI path (verified from actual screenshot):
  ///   Settings (main) → Connectivity Settings → Client/Server configuration
  ///   Dialog fields:
  ///     1. "TallyPrime acts as" : dropdown → select "Both"
  ///     2. "Enable ODBC"        : Yes/No   → select "Yes"
  ///     3. "Port"               : number   → type 9000
  ///   Then Ctrl+A (Accept) to save.
  Future<void> _configureClientServer() async {
    // We are now on the "Connectivity Settings" page.
    // It shows "List of Configurations" with "Client/Server configuration"
    // already highlighted. The preview below shows current values:
    //   TallyPrime acts as : None
    //   Enable ODBC        : No
    //   Port               : 9000
    //
    // Step 1: Press Enter to open the Client/Server configuration dialog.
    // (The row is already selected/highlighted in the list)

    await _sendKeys('{ENTER}');
    await Future.delayed(const Duration(milliseconds: 1000));

    // ── Now inside the Client/Server configuration dialog ──
    //
    // Field 1: "TallyPrime acts as" — dropdown is open and focused.
    // Dropdown list (top to bottom): Both, Client, None (highlighted), Server
    // "None" is currently selected (highlighted yellow).
    //
    // Use arrow keys to navigate: UP UP from "None" → "Client" → "Both"
    await _sendKeys('{UP}');
    await Future.delayed(const Duration(milliseconds: 200));
    await _sendKeys('{UP}');
    await Future.delayed(const Duration(milliseconds: 200));
    await _sendKeys('{ENTER}');
    await Future.delayed(const Duration(milliseconds: 800));

    // Field 2: "Enable ODBC" — now focused (Yes/No toggle).
    // Currently "No". Type "Y" or use arrow to select "Yes".
    await _sendKeys('Y');
    await Future.delayed(const Duration(milliseconds: 200));
    await _sendKeys('{ENTER}');
    await Future.delayed(const Duration(milliseconds: 800));

    // Field 3: "Port" — now focused, currently shows 9000.
    // Port is already 9000 — just press Enter to confirm and move on.
    await _sendKeys('{ENTER}');
    await Future.delayed(const Duration(milliseconds: 500));
  }

  /// Capture a screenshot and attach it to a step event.
  Future<void> _captureScreen(TallyBotStep step) async {
    final path = await captureScreenshot(label: step.name);
    if (path != null) {
      _emit(TallyBotEvent(
        step: step,
        status: StepStatus.screenshot,
        message: 'Screenshot captured.',
        screenshotPath: path,
      ));
    }
  }
}

// ── Event / Step enums ───────────────────────────────────────────────────────

enum TallyBotStep {
  findTally,
  focusTally,
  openHelp,
  openSettings,
  configurePort,
  saveSettings,
  verify,
}

enum StepStatus {
  pending,
  running,
  done,
  failed,
  screenshot,
}

class TallyBotEvent {
  final TallyBotStep step;
  final StepStatus status;
  final String message;
  final String? screenshotPath;

  const TallyBotEvent({
    required this.step,
    required this.status,
    required this.message,
    this.screenshotPath,
  });
}
