import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Standard elevated card used across dashboards and lists.
class FundMateSurfaceCard extends StatelessWidget {
  const FundMateSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.highlighted = false,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fm = context.fundMate;
    final scheme = Theme.of(context).colorScheme;

    final decoration = BoxDecoration(
      color: highlighted ? fm.unreadTint : fm.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: highlighted
            ? AppColors.accent.withValues(alpha: 0.45)
            : fm.cardBorder,
      ),
      boxShadow: [
        BoxShadow(
          color: fm.shadow,
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    );

    final content = Padding(padding: padding, child: child);

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: decoration,
            child: DefaultTextStyle(
              style: TextStyle(color: scheme.onSurface),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
