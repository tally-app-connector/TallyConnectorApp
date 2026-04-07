import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/theme/app_theme.dart';
import '../services/tally_interaction_bot.dart';
import '../services/tally_step_monitor.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Onboarding Setup Guide — shown once on first launch after login
// ─────────────────────────────────────────────────────────────────────────────

Future<void> showOnboardingGuide(BuildContext context) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    builder: (_) => const _OnboardingGuideDialog(),
  );
}

// ── Step data model ──────────────────────────────────────────────────────────

class _OnboardingStep {
  final IconData icon;
  final Color iconColor;
  final Color Function() iconBgColor;
  final String title;
  final String description;
  final bool hasCustomContent;

  const _OnboardingStep({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.description,
    this.hasCustomContent = false,
  });
}

// ── Steps ────────────────────────────────────────────────────────────────────

final List<_OnboardingStep> _steps = [
  _OnboardingStep(
    icon: Icons.person_add_rounded,
    iconColor: AppColors.blue,
    iconBgColor: () => AppColors.iconBgBlue,
    title: 'Create Your Account',
    description:
        'Sign up with your email and verify it to get started. '
        'Your data stays secure with encrypted cloud sync.',
  ),
  _OnboardingStep(
    icon: Icons.desktop_windows_rounded,
    iconColor: AppColors.green,
    iconBgColor: () => AppColors.iconBgGreen,
    title: 'Open Tally ERP',
    description:
        'Launch Tally ERP/Prime on your computer and open the '
        'company you want to analyze. Tally must be running during sync.',
  ),
  _OnboardingStep(
    icon: Icons.settings_ethernet_rounded,
    iconColor: AppColors.amber,
    iconBgColor: () => AppColors.iconBgAmber,
    title: 'Enable Tally API Port',
    description: '',
    hasCustomContent: true,
  ),
  _OnboardingStep(
    icon: Icons.cloud_download_rounded,
    iconColor: AppColors.purple,
    iconBgColor: () => AppColors.iconBgPurple,
    title: 'Fetch Companies',
    description:
        'Go to the Settings tab in this app and tap "Fetch Companies" '
        'to discover all companies from your running Tally instance.',
  ),
  _OnboardingStep(
    icon: Icons.check_circle_rounded,
    iconColor: AppColors.amber,
    iconBgColor: () => AppColors.iconBgAmber,
    title: 'Select a Company',
    description:
        'Choose the company you want to analyze from the fetched '
        'list in Settings.',
  ),
  _OnboardingStep(
    icon: Icons.sync_rounded,
    iconColor: AppColors.blue,
    iconBgColor: () => AppColors.iconBgBlue,
    title: 'Sync Your Data',
    description:
        'Go to Home tab and click "Full Sync". Wait until the '
        'sync-complete popup appears confirming all data has been synced.',
  ),
  _OnboardingStep(
    icon: Icons.analytics_rounded,
    iconColor: AppColors.green,
    iconBgColor: () => AppColors.iconBgGreen,
    title: 'Start Analyzing!',
    description:
        'Your data is ready. Explore the Dashboard for KPIs, '
        'Reports for detailed analysis, and Analytics for visual insights.',
  ),
];

// ── Dialog widget ────────────────────────────────────────────────────────────

class _OnboardingGuideDialog extends StatefulWidget {
  const _OnboardingGuideDialog();

  @override
  State<_OnboardingGuideDialog> createState() =>
      _OnboardingGuideDialogState();
}

class _OnboardingGuideDialogState extends State<_OnboardingGuideDialog> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // ── Bot & Monitor state ────────────────────────────────────────────────
  final TallyStepMonitor _monitor = TallyStepMonitor();
  StreamSubscription<TallySetupStatus>? _monitorSub;
  TallySetupStatus _tallyStatus = const TallySetupStatus();

  bool _isBotRunning = false;
  final List<TallyBotEvent> _botEvents = [];
  String? _latestScreenshot;

  @override
  void initState() {
    super.initState();
    // Start monitoring Tally status on desktop
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      _monitor.start();
      _monitorSub = _monitor.statusStream.listen((status) {
        if (mounted) setState(() => _tallyStatus = status);
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _monitorSub?.cancel();
    _monitor.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    if (mounted) Navigator.of(context).pop();
  }

  void _nextPage() {
    if (_currentPage < _steps.length - 1) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.animateToPage(
        _currentPage - 1,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  String? _warningMessage;

  /// Check if Tally is open, show warning inside dialog if not, then run bot.
  Future<void> _runBotWithCheck() async {
    final running = await TallyInteractionBot.isTallyProcessRunning();
    if (!running && mounted) {
      setState(() {
        _warningMessage =
            'Tally Prime is not open! Please open Tally first, then try again.';
      });
      // Auto-dismiss after 4 seconds
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) setState(() => _warningMessage = null);
      });
      return;
    }
    setState(() => _warningMessage = null);
    _runBot();
  }

  /// Run the full automation bot.
  Future<void> _runBot() async {
    setState(() {
      _isBotRunning = true;
      _botEvents.clear();
      _latestScreenshot = null;
    });

    final bot = TallyInteractionBot(
      onEvent: (event) {
        if (mounted) {
          setState(() {
            _botEvents.add(event);
            if (event.screenshotPath != null) {
              _latestScreenshot = event.screenshotPath;
            }
          });
        }
      },
    );

    await bot.runFullSetup();

    if (mounted) {
      setState(() => _isBotRunning = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    syncBrightness(context);
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 800;
    final dialogWidth = isWide ? 580.0 : size.width * 0.92;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: dialogWidth,
          constraints: BoxConstraints(maxHeight: isWide ? 600 : 540),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
            border: AppShadows.cardBorder,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _steps.length,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemBuilder: (_, i) {
                    final step = _steps[i];
                    if (step.hasCustomContent && i == 2) {
                      return _buildTallyConfigStep(step, i);
                    }
                    return _buildStepPage(step, i);
                  },
                ),
              ),
              _buildDots(),
              // Auto Configure button — fixed above nav, only on step 3
              if (_currentPage == 2 &&
                  (Platform.isWindows ||
                      Platform.isMacOS ||
                      Platform.isLinux)) ...[
                const SizedBox(height: 10),
                // Warning message
                if (_warningMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(
                        left: 24, right: 24, bottom: 8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_rounded,
                              size: 18, color: Colors.red.shade600),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _warningMessage!,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.red.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isBotRunning ? null : _runBotWithCheck,
                      icon: _isBotRunning
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.smart_toy_rounded, size: 16),
                      label: Text(
                        _isBotRunning ? 'Running...' : 'Auto Configure',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.amber,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              _buildNavButtons(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A6FD8), Color(0xFF00C9A7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.rocket_launch_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Setup Guide', style: AppTypography.pageTitle),
                const SizedBox(height: 2),
                Text('Follow these steps to get started',
                    style: AppTypography.itemSubtitle),
              ],
            ),
          ),
          TextButton(
            onPressed: _completeOnboarding,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: const Text('Skip',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  // ── Standard step page ─────────────────────────────────────────────────

  Widget _buildStepPage(_OnboardingStep step, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildStepBadge(step, index),
          const SizedBox(height: 20),
          _buildIconCircle(step, index),
          const SizedBox(height: 24),
          Text(
            step.title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            step.description,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Step 3: Tally Config — live checklist + bot + screenshot
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTallyConfigStep(_OnboardingStep step, int index) {
    // Full page scrollable
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          _buildStepBadge(step, index),
          const SizedBox(height: 8),
          Text(
            step.title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),

          // ── Live checklist ─────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.pillBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.monitor_heart_rounded,
                        size: 14, color: AppColors.blue),
                    const SizedBox(width: 6),
                    Text(
                      'Live Status',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.blue,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _tallyStatus.apiResponding
                            ? AppColors.green
                            : AppColors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _checkRow('Tally is running', _tallyStatus.tallyRunning,
                    Icons.desktop_windows_rounded),
                _checkRow('Company open', _tallyStatus.companyOpen,
                    Icons.business_rounded),
                _checkRow('Port 9000 open', _tallyStatus.portOpen,
                    Icons.settings_ethernet_rounded),
                _checkRow('API responding', _tallyStatus.apiResponding,
                    Icons.check_circle_outline_rounded),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ── Manual steps ───────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.pillBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manual Steps in Tally Prime:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 6),
                _tallyStep('1', 'Press F1 (Help)', Icons.keyboard_rounded),
                _tallyStep('2', 'Click Settings', Icons.settings_rounded),
                _tallyStep('3', 'Go to Connectivity', Icons.wifi_rounded),
                _tallyStep('4', 'Client/Server \u2192 Both', Icons.dns_rounded),
                _tallyStep('5', 'Set Port: 9000', Icons.numbers_rounded),
                _tallyStep('6', 'Ctrl+A to save', Icons.save_rounded),
                _tallyStep('7', 'Click Yes to restart Tally', Icons.restart_alt_rounded),
              ],
            ),
          ),

          // ── Bot log ────────────────────────────────────────────────────
          if (_botEvents.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.pillBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bot Log',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ..._botEvents
                      .where((e) => e.status != StepStatus.screenshot)
                      .map((e) => _botLogRow(e)),
                ],
              ),
            ),
          ],

          // ── Screenshot preview ─────────────────────────────────────────
          if (_latestScreenshot != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.divider),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Image.file(
                  File(_latestScreenshot!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Center(
                    child: Text(
                      'Could not load screenshot',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  /// Live status check row with animated tick/cross.
  Widget _checkRow(String label, bool checked, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: checked
                ? Icon(Icons.check_circle_rounded,
                    key: const ValueKey('check'),
                    color: AppColors.green,
                    size: 20)
                : Icon(Icons.radio_button_unchecked_rounded,
                    key: const ValueKey('uncheck'),
                    color: AppColors.textSecondary,
                    size: 20),
          ),
          const SizedBox(width: 10),
          Icon(icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: checked ? FontWeight.w600 : FontWeight.w400,
                color: checked ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ),
          if (checked)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Done',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.green,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Bot event log row.
  Widget _botLogRow(TallyBotEvent event) {
    final Color statusColor;
    final IconData statusIcon;
    switch (event.status) {
      case StepStatus.done:
        statusColor = AppColors.green;
        statusIcon = Icons.check_circle_rounded;
        break;
      case StepStatus.failed:
        statusColor = AppColors.red;
        statusIcon = Icons.error_rounded;
        break;
      case StepStatus.running:
        statusColor = AppColors.amber;
        statusIcon = Icons.hourglass_top_rounded;
        break;
      default:
        statusColor = AppColors.textSecondary;
        statusIcon = Icons.circle_outlined;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(statusIcon, size: 14, color: statusColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              event.message,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textPrimary,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Single Tally manual instruction row.
  Widget _tallyStep(String number, String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: AppColors.amber.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.amber,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                height: 1.3,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared helpers ───────────────────────────────────────────────────────

  Widget _buildStepBadge(_OnboardingStep step, int index) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: step.iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Step ${index + 1} of ${_steps.length}',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: step.iconColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildIconCircle(_OnboardingStep step, int index) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(index),
      tween: Tween(begin: 0.7, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      builder: (_, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: step.iconBgColor(),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: step.iconColor.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(step.icon, color: step.iconColor, size: 36),
      ),
    );
  }

  // ── Dot indicators ───────────────────────────────────────────────────────

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_steps.length, (i) {
        final isActive = i == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? AppColors.blue : AppColors.divider,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  // ── Navigation buttons ───────────────────────────────────────────────────

  Widget _buildNavButtons() {
    final isFirst = _currentPage == 0;
    final isLast = _currentPage == _steps.length - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          if (!isFirst)
            Expanded(
              child: OutlinedButton(
                onPressed: _prevPage,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: BorderSide(color: AppColors.divider),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Back',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          if (!isFirst) const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: isLast ? _completeOnboarding : _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: isLast ? AppColors.green : AppColors.blue,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                isLast ? 'Get Started' : 'Next',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
