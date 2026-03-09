// lib/features/project/da_contacts_page.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/permit.dart';

class DaContactsPage extends StatefulWidget {
  const DaContactsPage({super.key});

  @override
  State<DaContactsPage> createState() => _DaContactsPageState();
}

class _DaContactsPageState extends State<DaContactsPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.toLowerCase().trim());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<DaContact> get _filtered {
    if (_query.isEmpty) return daContacts;
    return daContacts
        .where(
          (c) =>
              c.name.toLowerCase().contains(_query) ||
              c.region.toLowerCase().contains(_query),
        )
        .toList();
  }

  Future<void> _launchPhone(BuildContext context, String phone) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(' ', ''));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Cannot dial $phone')),
      );
    }
  }

  Future<void> _launchWebsite(BuildContext context, String website) async {
    final messenger = ScaffoldMessenger.of(context);
    final url = website.startsWith('http') ? website : 'https://$website';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Cannot open $website')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final contacts = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Text('DA Contact Directory'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by name or region…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: contacts.isEmpty
                ? const Center(child: Text('No contacts match your search.'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: contacts.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) => _DaContactTile(
                      contact: contacts[i],
                      onPhone: () => _launchPhone(context, contacts[i].phone),
                      onWebsite: contacts[i].website.isNotEmpty
                          ? () =>
                              _launchWebsite(context, contacts[i].website)
                          : null,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _DaContactTile extends StatelessWidget {
  const _DaContactTile({
    required this.contact,
    required this.onPhone,
    this.onWebsite,
  });

  final DaContact contact;
  final VoidCallback onPhone;
  final VoidCallback? onWebsite;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            contact.name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 2),
          Text(
            contact.region,
            style: TextStyle(
              color: colorScheme.onSurface.withAlpha(140),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _ContactButton(
                icon: Icons.phone_outlined,
                label: contact.phone,
                onTap: onPhone,
              ),
              if (onWebsite != null) ...[
                const SizedBox(width: 12),
                _ContactButton(
                  icon: Icons.language_outlined,
                  label: contact.website,
                  onTap: onWebsite!,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ContactButton extends StatelessWidget {
  const _ContactButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
