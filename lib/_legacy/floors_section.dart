import 'package:flutter/material.dart';

/// Simple, explicit contract so the page can pass everything it needs.
class FloorsSection extends StatelessWidget {
  const FloorsSection({
    super.key,
    required this.areaLabel,
    required this.heightLabel,
    required this.floorAreasCtrls,
    required this.floorHeightsCtrls,
    required this.onAddFloor,
    required this.onRemoveFloor,
  });

  final String areaLabel;
  final String heightLabel;
  final List<TextEditingController> floorAreasCtrls;
  final List<TextEditingController> floorHeightsCtrls;
  final VoidCallback onAddFloor;
  final void Function(int index) onRemoveFloor;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Floors', style: t.titleMedium),
        const SizedBox(height: 8),
        ...List.generate(floorAreasCtrls.length, (i) {
          return Padding(
            padding: EdgeInsets.only(
                bottom: i == floorAreasCtrls.length - 1 ? 0 : 12),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: floorAreasCtrls[i],
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: areaLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: floorHeightsCtrls[i],
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: heightLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Remove floor',
                  onPressed: () => onRemoveFloor(i),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onAddFloor,
          icon: const Icon(Icons.add),
          label: const Text('Add floor'),
        ),
      ],
    );
  }
}
