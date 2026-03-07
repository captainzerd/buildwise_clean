// lib/features/project/tabs/finance_tab.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/config/service_locator.dart';
import '../../../core/models/audit_event.dart';
import '../../../core/models/deletion_request.dart';
import '../../../core/models/payment_record.dart';
import '../../../core/models/phase.dart';
import '../../../core/models/project.dart';
import '../../../core/services/audit_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/deletion_request_service.dart';
import '../../../core/services/payment_service.dart';
import '../../../core/services/paystack_service.dart';
import '../../../core/services/project_service.dart';
import '../../../core/widgets/empty_state.dart';
import '../../estimate/estimate_view_page.dart';
import '../../payment/paystack_checkout_page.dart';
import 'package:uuid/uuid.dart';
import 'work_tab.dart' show CostsTab, BoqTab;

enum _FinanceSection { costs, payments, estimates, boq }

class FinanceTab extends StatefulWidget {
  const FinanceTab({
    super.key,
    required this.projectId,
    required this.project,
    required this.projectService,
    required this.paymentService,
    required this.paystackService,
    required this.deletionRequestService,
    required this.isOwner,
    required this.isBuilder,
    required this.currentUserUid,
    required this.currentUserName,
    required this.currentUserEmail,
    required this.onSectionChanged,
  });

  final String projectId;
  final Project project;
  final ProjectService projectService;
  final PaymentService paymentService;
  final PaystackService paystackService;
  final DeletionRequestService deletionRequestService;
  final bool isOwner;
  final bool isBuilder;
  final String currentUserUid;
  final String currentUserName;
  final String currentUserEmail;
  final ValueChanged<int> onSectionChanged;

  @override
  State<FinanceTab> createState() => FinanceTabState();
}

class FinanceTabState extends State<FinanceTab> {
  _FinanceSection _section = _FinanceSection.costs;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Theme.of(context).colorScheme.surface,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: SegmentedButton<_FinanceSection>(
            expandedInsets: EdgeInsets.zero,
            segments: const [
              ButtonSegment(
                value: _FinanceSection.costs,
                label: Text('Costs'),
                icon: Icon(Icons.receipt_long_outlined),
              ),
              ButtonSegment(
                value: _FinanceSection.payments,
                label: Text('Payments'),
                icon: Icon(Icons.payments_outlined),
              ),
              ButtonSegment(
                value: _FinanceSection.estimates,
                label: Text('Estimates'),
                icon: Icon(Icons.analytics_outlined),
              ),
              ButtonSegment(
                value: _FinanceSection.boq,
                label: Text('BOQ'),
                icon: Icon(Icons.table_chart_outlined),
              ),
            ],
            selected: {_section},
            onSelectionChanged: (s) {
              setState(() => _section = s.first);
              widget.onSectionChanged(s.first.index);
            },
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: IndexedStack(
            index: _section.index,
            children: [
              CostsTab(
                projectId: widget.projectId,
                currencySymbol: widget.project.currencySymbol,
                projectService: widget.projectService,
                isBuilder: widget.isBuilder,
                currentUserUid: widget.currentUserUid,
                currentUserName: widget.currentUserName,
                deletionRequestService: widget.deletionRequestService,
              ),
              _PaymentsTab(
                projectId: widget.projectId,
                paymentService: widget.paymentService,
                isBuilder: widget.isBuilder,
                isOwner: widget.isOwner,
                currentUserUid: widget.currentUserUid,
                currentUserName: widget.currentUserName,
                currentUserEmail: widget.currentUserEmail,
                deletionRequestService: widget.deletionRequestService,
                paystackService: widget.paystackService,
              ),
              _EstimatesTab(
                projectId: widget.projectId,
                projectService: widget.projectService,
              ),
              BoqTab(projectId: widget.projectId),
            ],
          ),
        ),
      ],
    );
  }
}

class _EstimatesTab extends StatelessWidget {
  const _EstimatesTab({
    required this.projectId,
    required this.projectService,
  });

  final String projectId;
  final ProjectService projectService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      stream: projectService.estimatesStream(projectId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data ?? [];
        if (docs.isEmpty) {
          return const EmptyState(
            icon: Icons.analytics_outlined,
            title: 'No estimates yet',
            message: 'Tap the attach button to link a saved estimate.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 4),
          itemBuilder: (_, i) => _EstimateTile(
            doc: docs[i],
            projectId: projectId,
            projectService: projectService,
          ),
        );
      },
    );
  }
}

class _EstimateTile extends StatelessWidget {
  const _EstimateTile({
    required this.doc,
    required this.projectId,
    required this.projectService,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final String projectId;
  final ProjectService projectService;

  @override
  Widget build(BuildContext context) {
    final m = doc.data();
    final name = (m['projectName'] as String?) ??
        (m['projectNameInput'] as String?) ??
        'Estimate';
    final totalGhs = (m['grandTotalGhs'] as num?)?.toDouble();
    final createdTs = m['createdAt'];
    DateTime? created;
    if (createdTs is Timestamp) created = createdTs.toDate();
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cs.primaryContainer,
          child: Icon(
            Icons.analytics_outlined,
            color: cs.onPrimaryContainer,
            size: 20,
          ),
        ),
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [
            if (totalGhs != null) '₵ ${NumberFormat('#,##0').format(totalGhs)}',
            if (created != null) DateFormat('d MMM yyyy').format(created),
          ].join(' · '),
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: cs.outline),
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: cs.error),
          tooltip: 'Remove',
          onPressed: () => _confirmRemove(context),
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => EstimateViewPage(docRef: doc.reference),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove estimate?'),
        content: const Text(
          'This will unlink the estimate from this project.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await projectService.deleteEstimate(projectId, doc.id);
    }
  }
}

// ── Attach estimate sheet ──────────────────────────────────────────────────────

class ProjectAttachEstimateSheet extends StatefulWidget {
  const ProjectAttachEstimateSheet({
    super.key,
    required this.projectId,
    required this.uploaderUid,
    required this.projectService,
  });

  final String projectId;
  final String uploaderUid;
  final ProjectService projectService;

  @override
  State<ProjectAttachEstimateSheet> createState() => ProjectAttachEstimateSheetState();
}

class ProjectAttachEstimateSheetState extends State<ProjectAttachEstimateSheet> {
  bool _attaching = false;

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      get _savedEstimates => FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uploaderUid)
          .collection('estimates')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map(
            (s) => s.docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>>(),
          );

  Future<void> _attach(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    setState(() => _attaching = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.projectService.linkEstimate(
        widget.projectId,
        doc.data(),
      );
      if (mounted) {
        Navigator.of(context).pop();
        messenger.showSnackBar(
          const SnackBar(content: Text('Estimate attached to project.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _attaching = false);
        messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Text(
            'Attach a Saved Estimate',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (_attaching) const LinearProgressIndicator(),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          child:
              StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
            stream: _savedEstimates,
            builder: (ctx, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data!;
              if (docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No saved estimates found.\nGenerate an estimate first.',
                    textAlign: TextAlign.center,
                  ),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(height: 0),
                itemBuilder: (_, i) {
                  final m = docs[i].data();
                  final name = (m['projectName'] as String?) ??
                      (m['projectNameInput'] as String?) ??
                      'Estimate';
                  final totalGhs = (m['grandTotalGhs'] as num?)?.toDouble();
                  final createdTs = m['createdAt'];
                  DateTime? created;
                  if (createdTs is Timestamp) {
                    created = createdTs.toDate();
                  }
                  return ListTile(
                    title: Text(name, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      [
                        if (totalGhs != null)
                          '₵ ${NumberFormat('#,##0').format(totalGhs)}',
                        if (created != null)
                          DateFormat('d MMM yyyy').format(created),
                      ].join(' · '),
                    ),
                    onTap: _attaching ? null : () => _attach(docs[i]),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Payments tab ───────────────────────────────────────────────────────────────


class _PaymentsTab extends StatefulWidget {
  const _PaymentsTab({
    required this.projectId,
    required this.paymentService,
    required this.isBuilder,
    required this.isOwner,
    required this.currentUserUid,
    required this.currentUserName,
    required this.currentUserEmail,
    required this.deletionRequestService,
    required this.paystackService,
  });
  final String projectId;
  final PaymentService paymentService;
  final bool isBuilder;
  final bool isOwner;
  final String currentUserUid;
  final String currentUserName;
  final String currentUserEmail;
  final DeletionRequestService deletionRequestService;
  final PaystackService paystackService;

  @override
  State<_PaymentsTab> createState() => _PaymentsTabState();
}

class _PaymentsTabState extends State<_PaymentsTab> {
  String _paymentQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PaymentRecord>>(
      stream: widget.paymentService.paymentsStream(widget.projectId),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final allPayments = snap.data ?? [];
        final payments = _paymentQuery.isEmpty
            ? allPayments
            : allPayments.where((p) {
                final q = _paymentQuery.toLowerCase();
                return p.description.toLowerCase().contains(q) ||
                    p.method.label.toLowerCase().contains(q) ||
                    (p.reference ?? '').toLowerCase().contains(q) ||
                    (p.phaseTitle ?? '').toLowerCase().contains(q);
              }).toList();

        if (allPayments.isEmpty) {
          return EmptyState(
            icon: Icons.payments_outlined,
            title: 'No payments recorded',
            message: 'Record your first payment transaction.',
            actionLabel: 'Record payment',
            onAction: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (_) => ProjectAddPaymentSheet(
                projectId: widget.projectId,
                authorUid: widget.currentUserUid,
                paymentService: widget.paymentService,
                projectService: sl<ProjectService>(),
              ),
            ),
          );
        }

        // Summary totals from all payments (not filtered)
        double totalOut = 0;
        double totalIn = 0;
        for (final p in allPayments) {
          if (p.direction == PaymentDirection.outbound) {
            totalOut += p.amountGhs;
          } else {
            totalIn += p.amountGhs;
          }
        }
        final net = totalIn - totalOut;
        final fmt = NumberFormat('#,##0.00');
        final cs = Theme.of(context).colorScheme;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search payments…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _paymentQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _paymentQuery = '');
                          },
                        )
                      : null,
                  isDense: true,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onChanged: (v) => setState(() => _paymentQuery = v),
              ),
            ),
            // Summary card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: _SummaryColumn(
                        label: 'Paid Out',
                        value: 'GHS ${fmt.format(totalOut)}',
                        color: cs.error,
                      ),
                    ),
                    const VerticalDivider(width: 24),
                    Expanded(
                      child: _SummaryColumn(
                        label: 'Received',
                        value: 'GHS ${fmt.format(totalIn)}',
                        color: Colors.green,
                      ),
                    ),
                    const VerticalDivider(width: 24),
                    Expanded(
                      child: _SummaryColumn(
                        label: 'Net',
                        value: 'GHS ${fmt.format(net.abs())}',
                        color: net >= 0 ? Colors.green : cs.error,
                        prefix: net >= 0 ? '+' : '-',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (widget.isOwner) ...[
              _PaystackButton(
                projectId: widget.projectId,
                currentUserEmail: widget.currentUserEmail,
                paystackService: widget.paystackService,
              ),
              const SizedBox(height: 12),
            ],
            if (payments.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No matching payments'),
                ),
              )
            else
              ...payments.map(
                (p) => _PaymentCard(
                  payment: p,
                  isBuilder: widget.isBuilder,
                  onDelete: () => widget.paymentService.deletePayment(
                    projectId: widget.projectId,
                    paymentId: p.id,
                  ),
                  onRequestDeletion: () => _requestPaymentDeletion(
                    context,
                    p,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _requestPaymentDeletion(
    BuildContext context,
    PaymentRecord payment,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Request deletion?'),
        content: Text(
          'Send a deletion request to the owner for:\n\n'
          '"${payment.description}" — GHS ${NumberFormat('#,##0.00').format(payment.amountGhs)}\n\n'
          'The record will only be deleted after the owner approves.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send Request'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.deletionRequestService.request(
        DeletionRequest(
          itemId: payment.id,
          projectId: widget.projectId,
          itemType: DeletionItemType.payment,
          itemDescription: payment.description,
          requestedByUid: widget.currentUserUid,
          requestedByName: widget.currentUserName,
          status: DeletionStatus.pending,
          createdAt: DateTime.now(),
          amountGhs: payment.amountGhs,
        ),
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('Deletion request sent to owner.')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}

class _SummaryColumn extends StatelessWidget {
  const _SummaryColumn({
    required this.label,
    required this.value,
    required this.color,
    this.prefix = '',
  });
  final String label;
  final String value;
  final Color color;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          '$prefix$value',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.payment,
    required this.isBuilder,
    required this.onDelete,
    required this.onRequestDeletion,
  });
  final PaymentRecord payment;
  final bool isBuilder;
  final VoidCallback onDelete;
  final VoidCallback onRequestDeletion;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = NumberFormat('#,##0.00');
    final dateFmt = DateFormat('d MMM yyyy');
    final isOut = payment.direction == PaymentDirection.outbound;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          radius: 20,
          backgroundColor:
              isOut ? cs.errorContainer : Colors.green.withValues(alpha: 0.15),
          child: Icon(
            isOut ? Icons.arrow_upward : Icons.arrow_downward,
            size: 18,
            color: isOut ? cs.error : Colors.green,
          ),
        ),
        title: Text(payment.description),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${payment.method.label}${payment.mobileMoneyNetwork != null ? ' (${payment.mobileMoneyNetwork!.label})' : ''} · ${dateFmt.format(payment.paymentDate)}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            if (payment.mobileMoneyPhone != null &&
                payment.mobileMoneyPhone!.isNotEmpty)
              Text(
                'Phone: ${payment.mobileMoneyPhone}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.outline,
                    ),
              ),
            if (payment.phaseTitle != null)
              Text(
                'Phase: ${payment.phaseTitle}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.outline,
                    ),
              ),
            if (payment.reference != null && payment.reference!.isNotEmpty)
              Text(
                'Ref: ${payment.reference}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.outline,
                    ),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'GHS ${fmt.format(payment.amountGhs)}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isOut ? cs.error : Colors.green,
              ),
            ),
            if (isBuilder)
              GestureDetector(
                onTap: onRequestDeletion,
                child: Icon(
                  Icons.flag_outlined,
                  size: 16,
                  color: cs.error,
                ),
              )
            else
              GestureDetector(
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Delete payment?'),
                      content: const Text(
                          'This record will be permanently removed.',),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton.tonal(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) onDelete();
                },
                child: Icon(Icons.delete_outline, size: 16, color: cs.outline),
              ),
          ],
        ),
        isThreeLine: payment.phaseTitle != null || payment.reference != null,
      ),
    );
  }
}

// ── Add Payment Sheet ──────────────────────────────────────────────────────────


class ProjectAddPaymentSheet extends StatefulWidget {
  const ProjectAddPaymentSheet({
    super.key,
    required this.projectId,
    required this.authorUid,
    required this.paymentService,
    required this.projectService,
  });
  final String projectId;
  final String authorUid;
  final PaymentService paymentService;
  final ProjectService projectService;

  @override
  State<ProjectAddPaymentSheet> createState() => ProjectAddPaymentSheetState();
}

class ProjectAddPaymentSheetState extends State<ProjectAddPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _momoPhoneCtrl = TextEditingController();

  PaymentDirection _direction = PaymentDirection.outbound;
  PaymentMethod _method = PaymentMethod.cash;
  MobileMoneyNetwork _momoNetwork = MobileMoneyNetwork.mtn;
  DateTime _paymentDate = DateTime.now();
  String? _selectedPhaseId;
  String? _selectedPhaseTitle;
  bool _saving = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    _refCtrl.dispose();
    _momoPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _paymentDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    // Capture before async gap.
    final auditService = sl<AuditService>();
    final actorName =
        context.read<AuthService>().currentUser?.displayName ?? '';
    try {
      final isMomo = _method == PaymentMethod.mobileMoney;
      final payment = PaymentRecord(
        id: '',
        authorUid: widget.authorUid,
        direction: _direction,
        amountGhs: double.parse(_amountCtrl.text.replaceAll(',', '')),
        description: _descCtrl.text.trim(),
        method: _method,
        paymentDate: _paymentDate,
        createdAt: DateTime.now(),
        reference: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
        phaseId: _selectedPhaseId,
        phaseTitle: _selectedPhaseTitle,
        mobileMoneyNetwork: isMomo ? _momoNetwork : null,
        mobileMoneyPhone: isMomo && _momoPhoneCtrl.text.trim().isNotEmpty
            ? _momoPhoneCtrl.text.trim()
            : null,
      );
      await widget.paymentService.addPayment(
        projectId: widget.projectId,
        payment: payment,
      );
      unawaited(
        auditService.logEvent(
          projectId: widget.projectId,
          type: AuditEventType.paymentAdded,
          actorUid: widget.authorUid,
          actorName: actorName,
          description:
              'Recorded payment: ${_direction.label} GHS ${payment.amountGhs.toStringAsFixed(2)} \u2014 ${_descCtrl.text.trim()}',
          metadata: {
            'amountGhs': payment.amountGhs,
            'direction': _direction.name,
          },
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM yyyy');

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Record Payment',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),

              // Direction toggle
              SegmentedButton<PaymentDirection>(
                segments: PaymentDirection.values
                    .map(
                      (d) => ButtonSegment(
                        value: d,
                        label: Text(d.label),
                        icon: Icon(
                          d == PaymentDirection.outbound
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                        ),
                      ),
                    )
                    .toList(),
                selected: {_direction},
                onSelectionChanged: (s) => setState(() => _direction = s.first),
              ),
              const SizedBox(height: 12),

              // Description
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              // Amount
              TextFormField(
                controller: _amountCtrl,
                decoration: const InputDecoration(
                  labelText: 'Amount (GHS) *',
                  prefixText: 'GHS ',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final n = double.tryParse(v.replaceAll(',', ''));
                  if (n == null || n <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Payment method
              DropdownButtonFormField<PaymentMethod>(
                initialValue: _method,
                decoration: const InputDecoration(
                  labelText: 'Payment method',
                  border: OutlineInputBorder(),
                ),
                items: PaymentMethod.values
                    .map(
                      (m) => DropdownMenuItem(value: m, child: Text(m.label)),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _method = v);
                },
              ),

              // MoMo-specific fields
              if (_method == PaymentMethod.mobileMoney) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<MobileMoneyNetwork>(
                  initialValue: _momoNetwork,
                  decoration: const InputDecoration(
                    labelText: 'Network *',
                    border: OutlineInputBorder(),
                  ),
                  items: MobileMoneyNetwork.values
                      .map(
                        (n) => DropdownMenuItem(value: n, child: Text(n.label)),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _momoNetwork = v);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _momoPhoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Mobile money phone (optional)',
                    hintText: 'e.g. 0241234567',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
              ],
              const SizedBox(height: 12),

              // Date picker
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Payment date'),
                subtitle: Text(dateFmt.format(_paymentDate)),
                onTap: _pickDate,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Reference (optional)
              TextFormField(
                controller: _refCtrl,
                decoration: const InputDecoration(
                  labelText: 'Reference / receipt no. (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              // Phase link (optional) — streams phases
              StreamBuilder<List<Phase>>(
                stream: widget.projectService.phasesStream(widget.projectId),
                builder: (ctx, snap) {
                  final phases = snap.data ?? [];
                  if (phases.isEmpty) return const SizedBox.shrink();
                  return DropdownButtonFormField<String>(
                    initialValue: _selectedPhaseId,
                    decoration: const InputDecoration(
                      labelText: 'Link to phase (optional)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        child: Text('None'),
                      ),
                      ...phases.map(
                        (ph) => DropdownMenuItem(
                          value: ph.id,
                          child: Text(ph.name),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _selectedPhaseId = v;
                        _selectedPhaseTitle = phases
                            .where((ph) => ph.id == v)
                            .map((ph) => ph.name)
                            .firstOrNull;
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: 20),

              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Payment'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Deletion requests section (owner view in Overview tab) ─────────────────────


class _PaystackButton extends StatefulWidget {
  const _PaystackButton({
    required this.projectId,
    required this.currentUserEmail,
    required this.paystackService,
  });

  final String projectId;
  final String currentUserEmail;
  final PaystackService paystackService;

  @override
  State<_PaystackButton> createState() => _PaystackButtonState();
}

class _PaystackButtonState extends State<_PaystackButton> {
  bool _loading = false;

  Future<void> _launch() async {
    final amountCtrl = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pay via Paystack'),
        content: TextField(
          controller: amountCtrl,
          decoration: const InputDecoration(
            labelText: 'Amount (GHS)',
            prefixText: 'GH₵ ',
            border: OutlineInputBorder(),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(amountCtrl.text.trim());
              Navigator.of(ctx).pop(v);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (amount == null || amount <= 0 || !mounted) return;

    setState(() => _loading = true);
    try {
      final ref = const Uuid().v4();
      final result = await widget.paystackService.initTransaction(
        amountGhs: amount,
        email: widget.currentUserEmail.isNotEmpty
            ? widget.currentUserEmail
            : 'noreply@wysebrix.com',
        reference: ref,
        metadata: {'projectId': widget.projectId},
      );
      if (!mounted) return;
      final checkoutResult =
          await Navigator.of(context).push<PaystackCheckoutResult>(
        MaterialPageRoute(
          builder: (_) => PaystackCheckoutPage(
            authorizationUrl: result.authorizationUrl,
            reference: result.reference,
          ),
        ),
      );
      if (!mounted) return;
      if (checkoutResult?.success == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payment successful! Ref: ${checkoutResult!.reference ?? result.reference}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Paystack error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _loading ? null : _launch,
        icon: _loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white,),
              )
            : const Icon(Icons.credit_card_outlined, size: 18),
        label: const Text('Pay via Paystack'),
      ),
    );
  }
}

// ── Chat tab ───────────────────────────────────────────────────────────────────

