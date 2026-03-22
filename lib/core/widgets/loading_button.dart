// lib/core/widgets/loading_button.dart
//
// Filled button that automatically shows a spinner while an async callback
// is running and disables itself during that time.
//
// Usage:
//   LoadingButton(
//     label: 'Save',
//     icon: Icons.save_outlined,
//     onPressed: () async { await doWork(); },
//   )

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LoadingButton extends StatefulWidget {
  const LoadingButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.tonal = false,
    this.haptic = true,
    this.width = double.infinity,
  });

  final String label;
  final Future<void> Function() onPressed;
  final IconData? icon;

  /// If true renders as [FilledButton.tonal]; otherwise [FilledButton].
  final bool tonal;

  /// Trigger [HapticFeedback.mediumImpact] when tapped.
  final bool haptic;

  final double width;

  @override
  State<LoadingButton> createState() => _LoadingButtonState();
}

class _LoadingButtonState extends State<LoadingButton> {
  bool _loading = false;

  Future<void> _handleTap() async {
    if (_loading) return;
    if (widget.haptic) HapticFeedback.mediumImpact();
    setState(() => _loading = true);
    try {
      await widget.onPressed();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final spinner = SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: widget.tonal
            ? Theme.of(context).colorScheme.onSecondaryContainer
            : Colors.white,
      ),
    );

    final labelWidget = Text(_loading ? 'Please wait…' : widget.label);
    final iconWidget = _loading
        ? spinner
        : (widget.icon != null ? Icon(widget.icon) : null);

    return Semantics(
      label: _loading ? 'Loading, please wait' : null,
      child: SizedBox(
        width: widget.width,
        child: widget.tonal
          ? (iconWidget != null
              ? FilledButton.tonalIcon(
                  onPressed: _loading ? null : _handleTap,
                  icon: iconWidget,
                  label: labelWidget,
                )
              : FilledButton.tonal(
                  onPressed: _loading ? null : _handleTap,
                  child: labelWidget,
                ))
          : (iconWidget != null
              ? FilledButton.icon(
                  onPressed: _loading ? null : _handleTap,
                  icon: iconWidget,
                  label: labelWidget,
                )
              : FilledButton(
                  onPressed: _loading ? null : _handleTap,
                  child: labelWidget,
                )),
      ),
    );
  }
}
