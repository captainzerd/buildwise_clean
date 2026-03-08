import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/config/service_locator.dart';
import '../../../core/models/material_receipt.dart';
import '../../../core/services/receipt_service.dart';

class ReceiptUploadSection extends StatefulWidget {
  const ReceiptUploadSection({
    super.key,
    required this.projectId,
    required this.phaseId,
    required this.uploadedByUid,
  });

  final String projectId;
  final String phaseId;
  final String uploadedByUid;

  @override
  State<ReceiptUploadSection> createState() => _ReceiptUploadSectionState();
}

class _ReceiptUploadSectionState extends State<ReceiptUploadSection> {
  final _receiptService = sl<ReceiptService>();

  void _showAddReceiptSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddReceiptSheet(
        projectId: widget.projectId,
        phaseId: widget.phaseId,
        uploadedByUid: widget.uploadedByUid,
        receiptService: _receiptService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final nf = NumberFormat('#,##0.00');

    return StreamBuilder<List<MaterialReceipt>>(
      stream: _receiptService.receiptsStream(widget.projectId, widget.phaseId),
      builder: (context, snapshot) {
        final receipts = snapshot.data ?? [];
        final total = receipts.fold<double>(0, (s, r) => s + r.amountGhs);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 16,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  'Material Receipts',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'GH₵${nf.format(total)} submitted',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (snapshot.connectionState == ConnectionState.waiting &&
                receipts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              ),
            if (receipts.isNotEmpty) ...[
              ...receipts.map((r) => _ReceiptRow(receipt: r)),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add_outlined, size: 16),
                label: const Text('Add Receipt'),
                onPressed: _showAddReceiptSheet,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.receipt});

  final MaterialReceipt receipt;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final nf = NumberFormat('#,##0.00');
    final df = DateFormat('d MMM yyyy');

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.receipt_outlined, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  receipt.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  '${receipt.supplierName}  •  ${df.format(receipt.purchaseDate)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'GH₵${nf.format(receipt.amountGhs)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _AddReceiptSheet extends StatefulWidget {
  const _AddReceiptSheet({
    required this.projectId,
    required this.phaseId,
    required this.uploadedByUid,
    required this.receiptService,
  });

  final String projectId;
  final String phaseId;
  final String uploadedByUid;
  final ReceiptService receiptService;

  @override
  State<_AddReceiptSheet> createState() => _AddReceiptSheetState();
}

class _AddReceiptSheetState extends State<_AddReceiptSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionCtrl = TextEditingController();
  final _supplierCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  DateTime _purchaseDate = DateTime.now();
  File? _receiptFile;
  bool _uploading = false;
  double _uploadProgress = 0;

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    _supplierCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await _showSourceSheet();
    if (source == null || !mounted) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 2048,
    );
    if (file != null && mounted) {
      setState(() => _receiptFile = File(file.path));
    }
  }

  Future<ImageSource?> _showSourceSheet() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() => _purchaseDate = picked);
    }
  }

  Future<void> _submit() async {
    if (_uploading) return; // guard against double-tap before setState rebuilds
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_receiptFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please attach a receipt photo.')),
      );
      return;
    }

    setState(() {
      _uploading = true;
      _uploadProgress = 0;
    });

    try {
      final receiptId = widget.receiptService.newReceiptId();

      final url = await widget.receiptService.uploadReceiptFile(
        projectId: widget.projectId,
        phaseId: widget.phaseId,
        file: _receiptFile!,
        receiptId: receiptId,
        onProgress: (p) {
          if (mounted) setState(() => _uploadProgress = p);
        },
      );

      final amountGhs =
          double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0;

      await widget.receiptService.addReceipt(
        MaterialReceipt(
          id: receiptId,
          projectId: widget.projectId,
          phaseId: widget.phaseId,
          description: _descriptionCtrl.text.trim(),
          supplierName: _supplierCtrl.text.trim(),
          amountGhs: amountGhs,
          receiptUrl: url,
          purchaseDate: _purchaseDate,
          uploadedByUid: widget.uploadedByUid,
          uploadedAt: DateTime.now(),
        ),
      );

      if (mounted) {
        // Capture messenger before pop — context is invalid after the sheet is
        // removed from the tree.
        final sm = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        sm.showSnackBar(
          const SnackBar(content: Text('Receipt uploaded successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM yyyy');

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Material Receipt',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionCtrl,
              decoration: const InputDecoration(
                labelText: 'What was purchased?',
                hintText: 'e.g. 50 bags Portland cement - Ghacem',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _supplierCtrl,
              decoration: const InputDecoration(
                labelText: 'Supplier name',
                hintText: 'e.g. Ghacem Depot, Tema',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountCtrl,
              decoration: const InputDecoration(
                labelText: 'Amount (GHS)',
                prefixText: 'GH₵ ',
                border: OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final parsed = double.tryParse(v.replaceAll(',', ''));
                if (parsed == null || parsed <= 0) {
                  return 'Enter a valid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today_outlined, size: 16),
              label: Text('Purchase date: ${df.format(_purchaseDate)}'),
              onPressed: _uploading ? null : _pickDate,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.attach_file_outlined, size: 16),
              label: Text(
                _receiptFile != null
                    ? _receiptFile!.path.split('/').last
                    : 'Attach receipt photo',
              ),
              onPressed: _uploading ? null : _pickImage,
            ),
            if (_uploading) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _uploadProgress),
              const SizedBox(height: 4),
              Text(
                'Uploading… ${(_uploadProgress * 100).toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _uploading ? null : _submit,
                child: const Text('Save Receipt'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
