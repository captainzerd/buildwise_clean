import '../../core/config/service_locator.dart';
// lib/features/project/project_templates_page.dart
//
// Lists the owner's saved project templates and lets them create a new project
// pre-filled from a chosen template.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/models/project_template.dart';
import '../../core/services/project_template_service.dart';
import '../../core/services/auth_service.dart';
import 'create_project_page.dart';

class ProjectTemplatesPage extends StatelessWidget {
  const ProjectTemplatesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthService>().currentUser?.uid ?? '';
    final svc = sl<ProjectTemplateService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Project Templates')),
      body: StreamBuilder<List<ProjectTemplate>>(
        stream: svc.templatesStream(uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final templates = snap.data ?? [];
          if (templates.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bookmark_border,
                    size: 64,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No templates yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Open a project → ⋮ → Save as Template',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: templates.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _TemplateTile(
              template: templates[i],
              svc: svc,
            ),
          );
        },
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({required this.template, required this.svc});

  final ProjectTemplate template;
  final ProjectTemplateService svc;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = NumberFormat('#,##0');

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cs.primaryContainer,
          child: Icon(Icons.bookmark_outlined, color: cs.onPrimaryContainer),
        ),
        title: Text(template.name),
        subtitle: Text(
          [
            if (template.region.isNotEmpty) template.region,
            'Budget GHS ${fmt.format(template.budget)}',
            '${template.phases.length} phase${template.phases.length == 1 ? '' : 's'}',
          ].join(' · '),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: cs.outline,
              ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton.tonal(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      CreateProjectPage(template: template),
                ),
              ),
              child: const Text('Use'),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: cs.error,
              tooltip: 'Delete template',
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete template?'),
        content: Text(
          'Delete "${template.name}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await svc.deleteTemplate(template.id);
    }
  }
}
