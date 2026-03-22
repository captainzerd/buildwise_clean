// lib/core/widgets/app_page_route.dart
//
// Consistent right-to-left slide transition used across the app.
// Replaces MaterialPageRoute's platform-dependent defaults so every
// push feels the same on iOS and Android.

import 'package:flutter/material.dart';

/// Drop-in replacement for [MaterialPageRoute] with a slide-from-right
/// transition that works identically on all platforms.
class AppPageRoute<T> extends PageRouteBuilder<T> {
  AppPageRoute({required WidgetBuilder builder, super.settings})
      : super(
          pageBuilder: (ctx, _, __) => builder(ctx),
          transitionDuration: const Duration(milliseconds: 280),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          transitionsBuilder: (_, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            final tween = Tween(begin: begin, end: end).chain(
              CurveTween(curve: Curves.easeInOutCubic),
            );
            final fadeTween = Tween<double>(begin: 0.0, end: 1.0).chain(
              CurveTween(curve: const Interval(0.0, 0.5)),
            );
            return SlideTransition(
              position: animation.drive(tween),
              child: FadeTransition(
                opacity: animation.drive(fadeTween),
                child: child,
              ),
            );
          },
        );
}
