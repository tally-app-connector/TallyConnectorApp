import 'dart:io';
import 'package:flutter/material.dart';

/// Wraps content with desktop-appropriate constraints.
/// On desktop (width > 900), centers content with maxWidth constraint.
/// On mobile, passes through unchanged.
class DesktopResponsiveWrapper extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsets? desktopPadding;

  const DesktopResponsiveWrapper({
    super.key,
    required this.child,
    this.maxWidth = 900,
    this.desktopPadding,
  });

  static bool get isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  @override
  Widget build(BuildContext context) {
    if (!isDesktop) return child;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: desktopPadding != null
            ? Padding(padding: desktopPadding!, child: child)
            : child,
      ),
    );
  }
}
