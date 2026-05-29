import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Branded gradient app bar used across FundMate screens.
class FundMateAppBar extends StatelessWidget implements PreferredSizeWidget {
  const FundMateAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leadingIcon,
    this.actions,
    this.showBackButton = false,
    this.bottom,
  });

  final String title;
  final String? subtitle;
  final IconData? leadingIcon;
  final List<Widget>? actions;
  final bool showBackButton;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize {
    final bottomHeight = bottom?.preferredSize.height ?? 0;
    return Size.fromHeight(kToolbarHeight + bottomHeight + 14);
  }

  @override
  Widget build(BuildContext context) {
    final fm = context.fundMate;

    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      automaticallyImplyLeading: showBackButton,
      iconTheme: const IconThemeData(color: Colors.white),
      leading: showBackButton
          ? null
          : (leadingIcon != null
              ? Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Center(
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Icon(leadingIcon, color: Colors.white, size: 22),
                    ),
                  ),
                )
              : null),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.4,
              height: 1.2,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.88),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (actions != null) ...actions!,
        const SizedBox(width: 10),
      ],
      bottom: bottom,
      flexibleSpace: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [fm.gradientStart, fm.gradientEnd],
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                right: -36,
                top: -28,
                child: _DecorCircle(size: 130, opacity: 0.1),
              ),
              Positioned(
                left: -24,
                bottom: -48,
                child: _DecorCircle(size: 100, opacity: 0.08),
              ),
              Positioned(
                right: 80,
                bottom: 8,
                child: _DecorCircle(size: 36, opacity: 0.12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Frosted action button for app bar icons.
  static Widget actionButton({
    required IconData icon,
    required VoidCallback? onPressed,
    String? tooltip,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Material(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

class _DecorCircle extends StatelessWidget {
  const _DecorCircle({
    required this.size,
    required this.opacity,
  });

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
