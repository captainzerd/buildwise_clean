import 'package:flutter/material.dart';
import '../../../core/models/estimate.dart';

/// Simple, dumb dialog that lists saved estimates and delegates actions
/// back to the caller (controller/page).
class SavedEstimatesDialog extends StatelessWidget {
  final List<Estimate> estimates;
  final void Function(Estimate) onOpen;
  final void Function(String projectId) onDelete;
  final String Function(Estimate)? subtitleBuilder;

  const SavedEstimatesDialog({
    super.key,
    required this.estimates,
    required this.onOpen,
    required this.onDelete,
    this.subtitleBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Estimates')),
      body: estimates.isEmpty
          ? const Center(child: Text('No saved estimates yet'))
          : ListView.separated(
              itemCount: estimates.length,
              separatorBuilder: (_, __) => const Divider(height: 0),
              itemBuilder: (context, i) {
                final e = estimates[i];
                final sub = subtitleBuilder?.call(e) ??
                    '${e.city}, ${e.region} • ${e.squareFootage.toStringAsFixed(0)} sqft';

                return ListTile(
                  title: Text(e.projectName),
                  subtitle: Text(sub),
                  onTap: () => onOpen(e),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Open',
                        icon: const Icon(Icons.open_in_new),
                        onPressed: () => onOpen(e),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => onDelete(e.projectId),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
