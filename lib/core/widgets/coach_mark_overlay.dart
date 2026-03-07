import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 4-step coach mark tour shown once after first sign-in.
/// Gate on SharedPreferences key 'coach_done'.
class CoachMarkOverlay extends StatefulWidget {
  const CoachMarkOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<CoachMarkOverlay> createState() => _CoachMarkOverlayState();
}

class _CoachMarkOverlayState extends State<CoachMarkOverlay> {
  int _step = 0;
  bool _visible = false;

  static const _labels = [
    ('Estimate', 'Get instant construction cost estimates for your project.'),
    ('Projects', 'Track your projects, phases, costs and documents.'),
    ('People', 'Find builders, PMs and vendors on the marketplace.'),
    ('Account', 'Manage your profile, subscription and identity.'),
  ];

  // Approximate bottom-nav tab positions for a 5-tab nav bar.
  // Tabs highlighted: Estimate (0), Projects (1), People (3), Account (4).
  // alignment.x maps [-1, 1] across the screen width.
  // With 5 equally-spaced tabs, centres are at roughly ±0.8 and ±0.4.
  static const _alignments = [
    Alignment(-0.80, 1.0), // Estimate  (tab 0 of 5)
    Alignment(-0.40, 1.0), // Projects  (tab 1 of 5)
    Alignment(0.40, 1.0),  // People    (tab 3 of 5)
    Alignment(0.80, 1.0),  // Account   (tab 4 of 5)
  ];

  @override
  void initState() {
    super.initState();
    _checkIfNeeded();
  }

  Future<void> _checkIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool('coach_done') ?? false;
    if (!done && mounted) {
      // Small delay so the shell has fully rendered its nav bar.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (mounted) setState(() => _visible = true);
    }
  }

  Future<void> _next() async {
    if (_step < _labels.length - 1) {
      setState(() => _step++);
    } else {
      setState(() => _visible = false);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('coach_done', true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return widget.child;
    final (title, body) = _labels[_step];
    final alignment = _alignments[_step];

    return Stack(
      children: [
        widget.child,
        // Semi-transparent scrim with a cutout over the active nav tab.
        Positioned.fill(
          child: GestureDetector(
            onTap: _next,
            child: CustomPaint(
              painter: _ScrimPainter(alignment: alignment),
            ),
          ),
        ),
        // Tooltip label positioned above the highlighted tab.
        Positioned.fill(
          child: Align(
            alignment: Alignment(alignment.x, 0.6),
            child: GestureDetector(
              onTap: _next,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(40),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      body,
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int i = 0; i < _labels.length; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: i == _step ? 20 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: i == _step
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context)
                                      .colorScheme
                                      .outlineVariant,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _next,
                      child: Text(
                        _step < _labels.length - 1 ? 'Next' : 'Got it',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScrimPainter extends CustomPainter {
  const _ScrimPainter({required this.alignment});

  final Alignment alignment;

  @override
  void paint(Canvas canvas, Size size) {
    // Bottom nav bar is approximately 80 dp tall.
    const navBarHeight = 80.0;
    const tabWidth = 72.0;
    final cx = (alignment.x + 1) / 2 * size.width;
    final cy = size.height - navBarHeight / 2;
    final cutoutRect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: tabWidth,
      height: navBarHeight - 8,
    );

    // evenOdd fill rule punches a transparent hole where the cutout RRect is,
    // so no BlendMode.clear / saveLayer is required.
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(
        RRect.fromRectAndRadius(cutoutRect, const Radius.circular(12)),
      );

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black54
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_ScrimPainter old) => old.alignment != alignment;
}
