import 'package:flutter/material.dart';

import '../theme/theme_controller.dart';
import 'fundmate_app_bar.dart';

/// One tap switches between light and dark mode.
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key, this.onGradientBackground = false});

  final bool onGradientBackground;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final isDark = ThemeController.instance.isDark;
        final icon =
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded;
        final tooltip = isDark ? 'Switch to light mode' : 'Switch to dark mode';

        if (onGradientBackground) {
          return IconButton(
            tooltip: tooltip,
            onPressed: () => ThemeController.instance.toggle(),
            icon: Icon(icon, color: Colors.white),
          );
        }

        return FundMateAppBar.actionButton(
          icon: icon,
          tooltip: tooltip,
          onPressed: () => ThemeController.instance.toggle(),
        );
      },
    );
  }
}
