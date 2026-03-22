// lib/core/widgets/theme_mode_action.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/theme_mode_controller.dart';

class ThemeModeAction extends StatelessWidget {
  const ThemeModeAction({super.key});

  @override
  Widget build(BuildContext context) {
    final themeCtrl = context.read<ThemeModeController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IconButton(
      tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
      icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
      onPressed: themeCtrl.toggle,
    );
  }
}
