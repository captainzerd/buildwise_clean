import 'package:flutter/material.dart';

/// Drop‑in replacement for the "Units & Currency" row in the estimate form.
/// It adapts gracefully to narrow widths to avoid RenderFlex overflow.
///
/// Inject the two children your form already builds:
///  - [lengthToggle] : your "Meters/Feet" segmented control widget
///  - [currencyField]: your currency dropdown/input widget
class UnitsCurrencySection extends StatelessWidget {
  const UnitsCurrencySection({
    super.key,
    required this.lengthToggle,
    required this.currencyField,
  });

  final Widget lengthToggle;
  final Widget currencyField;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final narrow = c.maxWidth < 380;
        if (narrow) {
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(width: c.maxWidth, child: lengthToggle),
              SizedBox(width: c.maxWidth, child: currencyField),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: lengthToggle),
            const SizedBox(width: 12),
            Expanded(child: currencyField),
          ],
        );
      },
    );
  }
}
