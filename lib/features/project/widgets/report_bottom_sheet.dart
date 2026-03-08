// lib/features/project/widgets/report_bottom_sheet.dart

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../core/config/service_locator.dart';
import '../../../core/models/phase.dart';
import '../../../core/models/project.dart';
import '../../../core/services/payment_service.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/services/project_service.dart';

class ReportBottomSheet extends StatefulWidget {
  const ReportBottomSheet({
    super.key,
    required this.project,
  });

  final Project project;

  @override
  State<ReportBottomSheet> createState() => _ReportBottomSheetState();
}

class _ReportBottomSheetState extends State<ReportBottomSheet> {
  bool _generating = false;

  Future<void> _generate() async {
    if (_generating) return;
    setState(() => _generating = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      final projectService = sl<ProjectService>();
      final paymentService = sl<PaymentService>();
      final phases = await projectService.phasesStream(widget.project.id).first;
      final costs = await projectService.costEntriesStream(widget.project.id).first;
      final payments = await paymentService.paymentsStream(widget.project.id).first;

      // One photo per completed phase, preferring the last URL in each phase's list
      final photoUrls = phases
          .where((p) => p.status == PhaseStatus.completed && p.completionPhotoUrls.isNotEmpty)
          .map((p) => p.completionPhotoUrls.last)
          .take(6)
          .toList();

      final data = ProjectReportData(
        project: widget.project,
        phases: phases,
        costs: costs,
        payments: payments,
        photoUrls: photoUrls,
      );
      final bytes = await PdfService().generateProjectReport(data);
      final safeName = widget.project.title.replaceAll(RegExp(r'[^\w\s\-]'), '_').trim();
      await Printing.sharePdf(bytes: bytes, filename: '${safeName}_report.pdf');
      nav.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _generating = false);
        messenger.showSnackBar(SnackBar(
          content: Text('Report failed: $e'),
          duration: const Duration(seconds: 10),
        ),);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final project = widget.project;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Generate Progress Report', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            project.title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.outline),
          ),
          const SizedBox(height: 20),
          const _InfoRow(icon: Icons.summarize_outlined, label: 'Project summary & budget status'),
          const _InfoRow(icon: Icons.checklist_rounded, label: 'Phase completion table'),
          const _InfoRow(icon: Icons.attach_money_rounded, label: 'Cost breakdown & payment history'),
          const _InfoRow(icon: Icons.photo_library_outlined, label: 'Up to 6 progress photos'),
          const _InfoRow(icon: Icons.flag_outlined, label: 'Next milestone'),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _generating ? null : _generate,
              icon: _generating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined),
              label: Text(_generating ? 'Generating\u2026' : 'Generate & Share PDF'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
