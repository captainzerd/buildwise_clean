// lib/features/project/widgets/whatsapp_contact_button.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class WhatsAppContactButton extends StatelessWidget {
  const WhatsAppContactButton({
    super.key,
    required this.phone,
    required this.label,
    this.message,
  });

  final String phone;
  final String label;
  final String? message;

  Future<void> _launch() async {
    // Strip to digits and + only, prepend + if missing country code
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.isEmpty) return;
    final encoded = Uri.encodeComponent(
      message ?? 'Hello, I am contacting you via WyseBrix.',
    );
    final uri = Uri.parse('https://wa.me/$cleaned?text=$encoded');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: phone.isNotEmpty ? _launch : null,
      icon: const Icon(Icons.chat_outlined),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF25D366),
        foregroundColor: Colors.white,
      ),
    );
  }
}
