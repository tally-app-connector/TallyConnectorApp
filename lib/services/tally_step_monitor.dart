import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'tally_interaction_bot.dart';

/// Continuously monitors whether Tally setup steps are completed.
///
/// Runs periodic checks and emits [TallySetupStatus] updates.
/// The onboarding UI listens to [statusStream] and auto-ticks checkboxes.
class TallyStepMonitor {
  Timer? _timer;
  final _controller = StreamController<TallySetupStatus>.broadcast();

  /// Latest status snapshot.
  TallySetupStatus _last = const TallySetupStatus();

  /// Stream of status updates — UI subscribes to this.
  Stream<TallySetupStatus> get statusStream => _controller.stream;

  /// Current status (sync access).
  TallySetupStatus get current => _last;

  /// Start polling every [interval].
  void start({Duration interval = const Duration(seconds: 3)}) {
    stop();
    // Run immediately, then repeat
    _check();
    _timer = Timer.periodic(interval, (_) => _check());
  }

  /// Stop polling.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Dispose resources.
  void dispose() {
    stop();
    _controller.close();
  }

  /// Take a screenshot and return the file path.
  Future<String?> takeScreenshot() async {
    if (!Platform.isWindows) return null;
    return TallyInteractionBot.captureScreenshot(label: 'manual');
  }

  // ── Internal ───────────────────────────────────────────────────────────

  Future<void> _check() async {
    try {
      // Run checks in parallel
      final results = await Future.wait([
        TallyInteractionBot.isTallyProcessRunning(),  // [0] Tally running?
        TallyInteractionBot.isTallyPortOpen(),         // [1] Port 9000 open?
        TallyInteractionBot.canFetchCompanies(),       // [2] API responding?
        TallyInteractionBot.getTallyWindowTitle(),     // [3] Window title
      ]);

      final tallyRunning = results[0] as bool;
      final portOpen = results[1] as bool;
      final apiResponding = results[2] as bool;
      final windowTitle = results[3] as String?;

      // Determine if a company is loaded from the window title.
      // Tally Prime shows titles like:
      //   "TallyPrime:9000" (server mode, no specific company indicator)
      //   "Tally Prime - CompanyName" (company open)
      //   "Select Company" (no company open)
      // If API is responding, we can also infer a company is accessible.
      final companyOpen = windowTitle != null &&
          !windowTitle.toLowerCase().contains('select company') &&
          (windowTitle.contains('-') || apiResponding);

      final status = TallySetupStatus(
        tallyRunning: tallyRunning,
        companyOpen: companyOpen,
        portOpen: portOpen,
        apiResponding: apiResponding,
        windowTitle: windowTitle,
        lastChecked: DateTime.now(),
      );

      if (status != _last) {
        _last = status;
        _controller.add(status);
      }
    } catch (e) {
      debugPrint('TallyStepMonitor check error: $e');
    }
  }
}

/// Immutable snapshot of Tally setup step completion.
class TallySetupStatus {
  /// Tally process is running on this machine.
  final bool tallyRunning;

  /// A company is open in Tally (detected from window title).
  final bool companyOpen;

  /// Port 9000 is accepting TCP connections.
  final bool portOpen;

  /// Tally responds to XML company-list request on port 9000.
  final bool apiResponding;

  /// Tally window title (e.g., "Tally Prime - My Company").
  final String? windowTitle;

  /// When this status was captured.
  final DateTime? lastChecked;

  const TallySetupStatus({
    this.tallyRunning = false,
    this.companyOpen = false,
    this.portOpen = false,
    this.apiResponding = false,
    this.windowTitle,
    this.lastChecked,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TallySetupStatus &&
          tallyRunning == other.tallyRunning &&
          companyOpen == other.companyOpen &&
          portOpen == other.portOpen &&
          apiResponding == other.apiResponding;

  @override
  int get hashCode => Object.hash(tallyRunning, companyOpen, portOpen, apiResponding);
}
