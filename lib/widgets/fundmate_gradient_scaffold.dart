import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Full-screen branded gradient used on auth and onboarding flows.
class FundMateGradientScaffold extends StatelessWidget {
  const FundMateGradientScaffold({
    super.key,
    required this.child,
    this.appBar,
  });

  final Widget child;
  final PreferredSizeWidget? appBar;

  @override
  Widget build(BuildContext context) {
    final fm = context.fundMate;

    return Scaffold(
      extendBodyBehindAppBar: appBar != null,
      appBar: appBar,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [fm.gradientStart, fm.gradientEnd],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -60,
              top: -40,
              child: _Orb(size: 200, opacity: 0.07),
            ),
            Positioned(
              left: -40,
              bottom: 80,
              child: _Orb(size: 140, opacity: 0.05),
            ),
            SafeArea(child: child),
          ],
        ),
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}

/// Frosted card for login / signup forms — adapts to light and dark mode.
class FundMateAuthCard extends StatelessWidget {
  const FundMateAuthCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final fm = context.fundMate;
    final isDark = context.isDarkMode;

    return Container(
      decoration: BoxDecoration(
        color: fm.authCard,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark
              ? fm.cardBorder.withValues(alpha: 0.8)
              : Colors.white.withValues(alpha: 0.9),
        ),
        boxShadow: [
          BoxShadow(
            color: fm.shadow,
            blurRadius: isDark ? 24 : 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: child,
      ),
    );
  }
}

/// Themed text field shell for auth pages.
class FundMateAuthField extends StatelessWidget {
  const FundMateAuthField({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final fm = context.fundMate;
    return Container(
      decoration: BoxDecoration(
        color: fm.authFieldFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: fm.cardBorder.withValues(alpha: 0.6)),
      ),
      child: child,
    );
  }
}
