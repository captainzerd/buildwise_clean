// lib/features/project/land_ownership_page.dart
//
// Consolidates land ownership record (title deed details) and the due
// diligence checklist into a single page.
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/service_locator.dart';
import '../../core/widgets/stamp_duty_calculator.dart';
import '../../core/models/due_diligence_item.dart';
import '../../core/models/land_ownership_record.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/due_diligence_service.dart';
import '../../core/services/land_ownership_service.dart';

class LandOwnershipPage extends StatefulWidget {
  const LandOwnershipPage({
    super.key,
    required this.projectId,
    required this.projectTitle,
    required this.isOwner,
  });

  final String projectId;
  final String projectTitle;
  final bool isOwner;

  @override
  State<LandOwnershipPage> createState() => _LandOwnershipPageState();
}

class _LandOwnershipPageState extends State<LandOwnershipPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    sl<DueDiligenceService>().seedDefaultItems(widget.projectId);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Land — ${widget.projectTitle}'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(
                icon: Icon(Icons.real_estate_agent_outlined),
                text: 'Ownership',),
            Tab(icon: Icon(Icons.checklist_outlined), text: 'Due Diligence'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _OwnershipTab(
            projectId: widget.projectId,
            isOwner: widget.isOwner,
          ),
          _DueDiligenceTab(
            projectId: widget.projectId,
            isOwner: widget.isOwner,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Ownership Tab
// ─────────────────────────────────────────

class _OwnershipTab extends StatelessWidget {
  const _OwnershipTab({required this.projectId, required this.isOwner});
  final String projectId;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<LandOwnershipRecord?>(
      stream: sl<LandOwnershipService>().recordStream(projectId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final record = snap.data;
        if (record == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.real_estate_agent_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No land ownership record yet.',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                if (isOwner)
                  FilledButton.icon(
                    onPressed: () => _showEditSheet(context, null),
                    icon: const Icon(Icons.add),
                    label: const Text('Add ownership record'),
                  ),
              ],
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StatusBanner(record: record),
            const SizedBox(height: 16),
            _OwnershipCard(record: record),
            const SizedBox(height: 16),
            StampDutyCalculator(initialValueGhs: 0),
            if (isOwner) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _showEditSheet(context, record),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit ownership record'),
              ),
            ],
          ],
        );
      },
    );
  }

  void _showEditSheet(BuildContext context, LandOwnershipRecord? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _EditOwnershipSheet(
        projectId: projectId,
        existing: existing,
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.record});
  final LandOwnershipRecord record;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (record.status) {
      LandOwnershipStatus.verified => (Colors.green, Icons.verified_outlined),
      LandOwnershipStatus.inProgress => (
          Colors.amber[700]!,
          Icons.pending_outlined
        ),
      LandOwnershipStatus.disputed => (
          Colors.red,
          Icons.warning_amber_outlined
        ),
      LandOwnershipStatus.notStarted => (
          Colors.grey,
          Icons.hourglass_empty_outlined
        ),
    };
    return Card(
      color: color.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.status.label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    record.titleType.label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OwnershipCard extends StatelessWidget {
  const _OwnershipCard({required this.record});
  final LandOwnershipRecord record;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Land Details',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Divider(height: 24),
            _Row('Title Deed No.', record.titleDeedNumber ?? '—'),
            _Row('Plot No.', record.plotNumber ?? '—'),
            _Row('Locality', record.locality ?? '—'),
            _Row('Region', record.region ?? '—'),
            if (record.landArea != null)
              _Row(
                'Area',
                '${record.landArea!.toStringAsFixed(2)} ${record.landAreaUnit}',
              ),
            if (record.registrationDate != null)
              _Row(
                'Registration Date',
                DateFormat('d MMM yyyy').format(record.registrationDate!),
              ),
            if (record.encumbrances != null && record.encumbrances!.isNotEmpty)
              _Row('Encumbrances', record.encumbrances!),
            if (record.notes != null && record.notes!.isNotEmpty)
              _Row('Notes', record.notes!),
            if (record.titleDeedUrl != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final url = Uri.tryParse(record.titleDeedUrl!);
                  if (url != null) await launchUrl(url);
                },
                icon: const Icon(Icons.attachment_outlined, size: 18),
                label: const Text('View Title Deed Document'),
              ),
            ],
            if (record.siteMapUrl != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final url = Uri.tryParse(record.siteMapUrl!);
                  if (url != null) await launchUrl(url);
                },
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text('View Site Map'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: cs.secondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Edit Ownership Sheet
// ─────────────────────────────────────────

class _EditOwnershipSheet extends StatefulWidget {
  const _EditOwnershipSheet({required this.projectId, this.existing});
  final String projectId;
  final LandOwnershipRecord? existing;

  @override
  State<_EditOwnershipSheet> createState() => _EditOwnershipSheetState();
}

class _EditOwnershipSheetState extends State<_EditOwnershipSheet> {
  final _formKey = GlobalKey<FormState>();
  late LandTitleType _titleType;
  late LandOwnershipStatus _status;
  late final TextEditingController _deedCtrl;
  late final TextEditingController _plotCtrl;
  late final TextEditingController _localityCtrl;
  late final TextEditingController _regionCtrl;
  late final TextEditingController _areaCtrl;
  late final TextEditingController _encumbrancesCtrl;
  late final TextEditingController _notesCtrl;
  String _areaUnit = 'acres';
  DateTime? _registrationDate;
  String? _titleDeedUrl;
  String? _siteMapUrl;
  bool _uploadingDeed = false;
  bool _uploadingMap = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleType = e?.titleType ?? LandTitleType.other;
    _status = e?.status ?? LandOwnershipStatus.notStarted;
    _deedCtrl = TextEditingController(text: e?.titleDeedNumber ?? '');
    _plotCtrl = TextEditingController(text: e?.plotNumber ?? '');
    _localityCtrl = TextEditingController(text: e?.locality ?? '');
    _regionCtrl = TextEditingController(text: e?.region ?? '');
    _areaCtrl = TextEditingController(
      text: e?.landArea != null ? e!.landArea!.toStringAsFixed(2) : '',
    );
    _encumbrancesCtrl = TextEditingController(text: e?.encumbrances ?? '');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _areaUnit = e?.landAreaUnit ?? 'acres';
    _registrationDate = e?.registrationDate;
    _titleDeedUrl = e?.titleDeedUrl;
    _siteMapUrl = e?.siteMapUrl;
  }

  @override
  void dispose() {
    _deedCtrl.dispose();
    _plotCtrl.dispose();
    _localityCtrl.dispose();
    _regionCtrl.dispose();
    _areaCtrl.dispose();
    _encumbrancesCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDocument(bool isDeed) async {
    final uid = context.read<AuthService>().currentUser?.uid ?? 'anon';
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;
    setState(() => isDeed ? _uploadingDeed = true : _uploadingMap = true);
    try {
      final url = await sl<LandOwnershipService>().uploadDocument(
        widget.projectId,
        uid,
        isDeed ? 'title_deed' : 'site_map',
        file.path!,
        file.name,
      );
      setState(() {
        if (isDeed) {
          _titleDeedUrl = url;
        } else {
          _siteMapUrl = url;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(
          () => isDeed ? _uploadingDeed = false : _uploadingMap = false,
        );
      }
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final uid = context.read<AuthService>().currentUser?.uid ?? 'anon';
      final record = LandOwnershipRecord(
        id: widget.existing?.id ?? const Uuid().v4(),
        projectId: widget.projectId,
        ownerUid: uid,
        titleType: _titleType,
        status: _status,
        titleDeedNumber:
            _deedCtrl.text.trim().isEmpty ? null : _deedCtrl.text.trim(),
        plotNumber:
            _plotCtrl.text.trim().isEmpty ? null : _plotCtrl.text.trim(),
        locality: _localityCtrl.text.trim().isEmpty
            ? null
            : _localityCtrl.text.trim(),
        region:
            _regionCtrl.text.trim().isEmpty ? null : _regionCtrl.text.trim(),
        landArea: double.tryParse(_areaCtrl.text.trim()),
        landAreaUnit: _areaUnit,
        registrationDate: _registrationDate,
        titleDeedUrl: _titleDeedUrl,
        siteMapUrl: _siteMapUrl,
        encumbrances: _encumbrancesCtrl.text.trim().isEmpty
            ? null
            : _encumbrancesCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
      );
      await sl<LandOwnershipService>().saveRecord(widget.projectId, record);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.existing == null
                    ? 'Add Land Ownership Record'
                    : 'Edit Land Ownership Record',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              // Title type
              DropdownButtonFormField<LandTitleType>(
                decoration: const InputDecoration(
                  labelText: 'Title type',
                  border: OutlineInputBorder(),
                ),
                initialValue: _titleType,
                items: [
                  for (final t in LandTitleType.values)
                    DropdownMenuItem(value: t, child: Text(t.label)),
                ],
                onChanged: (v) => setState(() => _titleType = v ?? _titleType),
              ),
              const SizedBox(height: 12),
              // Status
              DropdownButtonFormField<LandOwnershipStatus>(
                decoration: const InputDecoration(
                  labelText: 'Verification status',
                  border: OutlineInputBorder(),
                ),
                initialValue: _status,
                items: [
                  for (final s in LandOwnershipStatus.values)
                    DropdownMenuItem(value: s, child: Text(s.label)),
                ],
                onChanged: (v) => setState(() => _status = v ?? _status),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _deedCtrl,
                decoration: const InputDecoration(
                  labelText: 'Title deed number (optional)',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _plotCtrl,
                decoration: const InputDecoration(
                  labelText: 'Plot number (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _localityCtrl,
                decoration: const InputDecoration(
                  labelText: 'Locality / Town',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _regionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Region (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              // Land area + unit
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _areaCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Land area (optional)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _areaUnit,
                    items: const [
                      DropdownMenuItem(
                        value: 'acres',
                        child: Text('acres'),
                      ),
                      DropdownMenuItem(
                        value: 'sqft',
                        child: Text('sq ft'),
                      ),
                      DropdownMenuItem(
                        value: 'sqm',
                        child: Text('sq m'),
                      ),
                      DropdownMenuItem(
                        value: 'hectares',
                        child: Text('ha'),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => _areaUnit = v ?? _areaUnit),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Registration date
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _registrationDate ?? DateTime.now(),
                    firstDate: DateTime(1950),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => _registrationDate = picked);
                  }
                },
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Registration date (optional)',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                  ),
                  child: Text(
                    _registrationDate != null
                        ? DateFormat('d MMM yyyy').format(_registrationDate!)
                        : 'Not set',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _registrationDate == null
                          ? theme.colorScheme.outline
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _encumbrancesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Encumbrances / Caveats (optional)',
                  hintText: 'e.g. Mortgage with GCB Bank',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              // Document uploads
              Text('Documents', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              _UploadRow(
                label: 'Title Deed',
                url: _titleDeedUrl,
                isUploading: _uploadingDeed,
                onTap: () => _pickDocument(true),
              ),
              const SizedBox(height: 8),
              _UploadRow(
                label: 'Site Map',
                url: _siteMapUrl,
                isUploading: _uploadingMap,
                onTap: () => _pickDocument(false),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadRow extends StatelessWidget {
  const _UploadRow({
    required this.label,
    required this.url,
    required this.isUploading,
    required this.onTap,
  });
  final String label;
  final String? url;
  final bool isUploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
              if (url != null)
                Text(
                  'Uploaded',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green[700],
                  ),
                ),
            ],
          ),
        ),
        isUploading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : OutlinedButton.icon(
                onPressed: onTap,
                icon: Icon(
                  url != null ? Icons.refresh : Icons.upload_outlined,
                  size: 16,
                ),
                label: Text(url != null ? 'Replace' : 'Upload'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
      ],
    );
  }
}

// ─────────────────────────────────────────
// Due Diligence Tab
// ─────────────────────────────────────────

class _DueDiligenceTab extends StatelessWidget {
  const _DueDiligenceTab({required this.projectId, required this.isOwner});
  final String projectId;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final service = sl<DueDiligenceService>();
    return StreamBuilder<List<DueDiligenceItem>>(
      stream: service.itemsStream(projectId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data ?? [];
        final pending =
            items.where((i) => i.status == DueDiligenceStatus.pending).length;
        final verified =
            items.where((i) => i.status == DueDiligenceStatus.verified).length;
        final failed =
            items.where((i) => i.status == DueDiligenceStatus.failed).length;

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    _StatChip(
                      label: '$pending pending',
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      label: '$verified verified',
                      color: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      label: '$failed failed',
                      color: Colors.red,
                    ),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _DueDiligenceTile(
                  item: items[i],
                  isOwner: isOwner,
                  onStatusChange: (status) => service.updateItem(
                    projectId,
                    items[i].id,
                    status: status,
                  ),
                ),
                childCount: items.length,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DueDiligenceTile extends StatelessWidget {
  const _DueDiligenceTile({
    required this.item,
    required this.isOwner,
    required this.onStatusChange,
  });
  final DueDiligenceItem item;
  final bool isOwner;
  final void Function(DueDiligenceStatus) onStatusChange;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (item.status) {
      DueDiligenceStatus.verified => (Colors.green, Icons.check_circle),
      DueDiligenceStatus.failed => (Colors.red, Icons.cancel_outlined),
      DueDiligenceStatus.pending => (
          Colors.orange,
          Icons.radio_button_unchecked
        ),
    };
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(item.title),
      subtitle: item.notes != null && item.notes!.isNotEmpty
          ? Text(item.notes!, maxLines: 2, overflow: TextOverflow.ellipsis)
          : null,
      trailing: isOwner
          ? PopupMenuButton<DueDiligenceStatus>(
              icon: const Icon(Icons.more_vert),
              onSelected: onStatusChange,
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: DueDiligenceStatus.pending,
                  child: Text('Mark Pending'),
                ),
                PopupMenuItem(
                  value: DueDiligenceStatus.verified,
                  child: Text('Mark Verified'),
                ),
                PopupMenuItem(
                  value: DueDiligenceStatus.failed,
                  child: Text('Mark Failed'),
                ),
              ],
            )
          : null,
    );
  }
}
