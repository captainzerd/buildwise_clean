import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/service_locator.dart';
import '../../core/models/payment_record.dart';
import '../../core/models/project.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/builder_profile_service.dart';
import '../../core/services/invoice_service.dart';
import '../../core/services/payment_service.dart';

/// Generates a Ghana VAT-compliant PDF invoice for a project.
class InvoicePage extends StatefulWidget {
  const InvoicePage({super.key, required this.project});

  final Project project;

  @override
  State<InvoicePage> createState() => _InvoicePageState();
}

class _InvoicePageState extends State<InvoicePage> {
  final _formKey = GlobalKey<FormState>();
  final _invoiceNumCtrl = TextEditingController();
  final _issuerNameCtrl = TextEditingController();
  final _issuerPhoneCtrl = TextEditingController();
  final _issuerAddressCtrl = TextEditingController();
  final _issuerTinCtrl = TextEditingController();
  final _clientNameCtrl = TextEditingController();
  final _clientPhoneCtrl = TextEditingController();
  final _clientAddressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  final List<_LineItemController> _items = [];
  DateTime _issueDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  bool _generating = false;
  bool _markingPaid = false;

  @override
  void initState() {
    super.initState();
    _invoiceNumCtrl.text = 'INV-${const Uuid().v4().substring(0, 8).toUpperCase()}';
    _clientNameCtrl.text = widget.project.ownerName ?? '';
    _loadIssuerProfile();
    _addItem();
  }

  Future<void> _loadIssuerProfile() async {
    final auth = context.read<AuthService>();
    final uid = auth.currentUser?.uid;
    if (uid == null) return;
    try {
      final profile = await context
          .read<BuilderProfileService>()
          .profileStream(uid)
          .first;
      if (profile != null && mounted) {
        _issuerNameCtrl.text = profile.displayName;
        _issuerPhoneCtrl.text = profile.phone ?? '';
        _issuerTinCtrl.text = profile.graTin ?? '';
        _issuerAddressCtrl.text = profile.location ?? '';
      } else if (mounted) {
        _issuerNameCtrl.text =
            auth.currentUser?.displayName ?? '';
      }
    } catch (_) {
      if (mounted) {
        _issuerNameCtrl.text =
            context.read<AuthService>().currentUser?.displayName ?? '';
      }
    }
  }

  void _addItem() {
    setState(() => _items.add(_LineItemController()));
  }

  void _removeItem(int index) {
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  @override
  void dispose() {
    _invoiceNumCtrl.dispose();
    _issuerNameCtrl.dispose();
    _issuerPhoneCtrl.dispose();
    _issuerAddressCtrl.dispose();
    _issuerTinCtrl.dispose();
    _clientNameCtrl.dispose();
    _clientPhoneCtrl.dispose();
    _clientAddressCtrl.dispose();
    _notesCtrl.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  double get _subtotal => _items.fold<double>(
        0.0,
        (sum, it) =>
            sum +
            (double.tryParse(it.qtyCtrl.text) ?? 0) *
                (double.tryParse(it.priceCtrl.text.replaceAll(',', '')) ?? 0),
      );

  Future<void> _markAsPaid() async {
    final total = GhanaVat.total(_subtotal);
    final numFmt = NumberFormat('#,##0.00');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as Paid?'),
        content: Text(
          'Record a payment of GHS ${numFmt.format(total)} '
          'for invoice ${_invoiceNumCtrl.text.trim()}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Record Payment'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _markingPaid = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final uid = context.read<AuthService>().currentUser?.uid ?? '';
      final now = DateTime.now();
      await sl<PaymentService>().addPayment(
        projectId: widget.project.id,
        payment: PaymentRecord(
          id: '',
          authorUid: uid,
          direction: PaymentDirection.inbound,
          amountGhs: total,
          description: 'Invoice ${_invoiceNumCtrl.text.trim()}',
          method: PaymentMethod.bankTransfer,
          paymentDate: now,
          createdAt: now,
          reference: _invoiceNumCtrl.text.trim(),
        ),
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('Payment recorded')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to record payment: $e')),
      );
    } finally {
      if (mounted) setState(() => _markingPaid = false);
    }
  }

  Future<void> _generate() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one line item.')),
      );
      return;
    }

    setState(() => _generating = true);
    try {
      final data = InvoiceData(
        invoiceNumber: _invoiceNumCtrl.text.trim(),
        issueDate: _issueDate,
        dueDate: _dueDate,
        issuerName: _issuerNameCtrl.text.trim(),
        issuerPhone: _issuerPhoneCtrl.text.trim(),
        issuerTin: _issuerTinCtrl.text.trim().isEmpty
            ? null
            : _issuerTinCtrl.text.trim(),
        issuerAddress: _issuerAddressCtrl.text.trim().isEmpty
            ? null
            : _issuerAddressCtrl.text.trim(),
        clientName: _clientNameCtrl.text.trim(),
        clientPhone: _clientPhoneCtrl.text.trim().isEmpty
            ? null
            : _clientPhoneCtrl.text.trim(),
        clientAddress: _clientAddressCtrl.text.trim().isEmpty
            ? null
            : _clientAddressCtrl.text.trim(),
        projectTitle: widget.project.title,
        lineItems: _items
            .map(
              (it) => InvoiceLineItem(
                description: it.descCtrl.text.trim(),
                quantity:
                    double.tryParse(it.qtyCtrl.text.trim()) ?? 1,
                unitPriceGhs: double.tryParse(
                      it.priceCtrl.text.replaceAll(',', '').trim(),
                    ) ??
                    0,
              ),
            )
            .toList(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );

      final pdfBytes = await InvoiceService().generatePdf(data);

      if (mounted) {
        await Printing.sharePdf(
          bytes: pdfBytes,
          filename:
              '${_invoiceNumCtrl.text.trim()}_${widget.project.title.replaceAll(' ', '_')}.pdf',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating invoice: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final numFmt = NumberFormat('#,##0.00');
    final subtotal = _subtotal;

    return Scaffold(
      appBar: AppBar(title: const Text('VAT Invoice')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Generate a Ghana VAT-compliant invoice.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 16),

            // ── Invoice meta ──────────────────────────────────────────
            _SectionHeader(title: 'Invoice Details'),
            const SizedBox(height: 10),
            TextFormField(
              controller: _invoiceNumCtrl,
              decoration: const InputDecoration(
                labelText: 'Invoice number *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _DateTile(
                    label: 'Issue date',
                    date: _issueDate,
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _issueDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2040),
                      );
                      if (d != null) setState(() => _issueDate = d);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateTile(
                    label: 'Due date',
                    date: _dueDate,
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _dueDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2040),
                      );
                      if (d != null) setState(() => _dueDate = d);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Issuer ────────────────────────────────────────────────
            _SectionHeader(title: 'Your Details (Issuer)'),
            const SizedBox(height: 10),
            TextFormField(
              controller: _issuerNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Your name / company *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _issuerPhoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Phone *',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _issuerTinCtrl,
              decoration: const InputDecoration(
                labelText: 'GRA TIN (optional)',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _issuerAddressCtrl,
              decoration: const InputDecoration(
                labelText: 'Address (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // ── Client ────────────────────────────────────────────────
            _SectionHeader(title: 'Client Details'),
            const SizedBox(height: 10),
            TextFormField(
              controller: _clientNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Client name *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _clientPhoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Client phone (optional)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _clientAddressCtrl,
              decoration: const InputDecoration(
                labelText: 'Client address (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // ── Line items ────────────────────────────────────────────
            _SectionHeader(title: 'Line Items'),
            const SizedBox(height: 10),
            for (int i = 0; i < _items.length; i++)
              _LineItemRow(
                index: i,
                ctrl: _items[i],
                onRemove: _items.length > 1 ? () => _removeItem(i) : null,
                onChanged: () => setState(() {}),
              ),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add line item'),
              onPressed: _addItem,
            ),
            const SizedBox(height: 16),

            // ── VAT summary ───────────────────────────────────────────
            _SectionHeader(title: 'Tax Summary'),
            const SizedBox(height: 8),
            _TaxRow(
              label: 'Subtotal',
              value: 'GHS ${numFmt.format(subtotal)}',
            ),
            _TaxRow(
              label: 'VAT (15%)',
              value: 'GHS ${numFmt.format(GhanaVat.vatAmount(subtotal))}',
            ),
            _TaxRow(
              label: 'NHIL (2.5%)',
              value: 'GHS ${numFmt.format(GhanaVat.nhilAmount(subtotal))}',
            ),
            _TaxRow(
              label: 'GETFund (2.5%)',
              value:
                  'GHS ${numFmt.format(GhanaVat.getFundAmount(subtotal))}',
            ),
            const Divider(),
            _TaxRow(
              label: 'TOTAL',
              value: 'GHS ${numFmt.format(GhanaVat.total(subtotal))}',
              bold: true,
            ),
            const SizedBox(height: 16),

            // ── Notes ─────────────────────────────────────────────────
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Payment terms, bank details, etc.',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _generating ? null : _generate,
                icon: _generating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined),
                label: Text(_generating ? 'Generating…' : 'Generate & Share PDF'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: (_markingPaid || _subtotal <= 0) ? null : _markAsPaid,
                icon: _markingPaid
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline, size: 18),
                label: Text(_markingPaid ? 'Recording…' : 'Mark as Paid'),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      );
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.date,
    required this.onTap,
  });
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        child: Text(
          DateFormat('d MMM yyyy').format(date),
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }
}

class _TaxRow extends StatelessWidget {
  const _TaxRow({required this.label, required this.value, this.bold = false});
  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _LineItemController {
  final descCtrl = TextEditingController();
  final qtyCtrl = TextEditingController(text: '1');
  final priceCtrl = TextEditingController();

  void dispose() {
    descCtrl.dispose();
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}

class _LineItemRow extends StatelessWidget {
  const _LineItemRow({
    required this.index,
    required this.ctrl,
    required this.onChanged,
    this.onRemove,
  });
  final int index;
  final _LineItemController ctrl;
  final VoidCallback? onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Item ${index + 1}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const Spacer(),
                if (onRemove != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: onRemove,
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Remove',
                  ),
              ],
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: ctrl.descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description *',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => onChanged(),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: ctrl.qtyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Qty *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => onChanged(),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (double.tryParse(v) == null) return 'Invalid';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: TextFormField(
                    controller: ctrl.priceCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Unit price (GHS) *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => onChanged(),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (double.tryParse(v.replaceAll(',', '')) == null) {
                        return 'Invalid';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
