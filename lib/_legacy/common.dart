import 'package:flutter/material.dart';

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600));
  }
}

class InlineInfo extends StatelessWidget {
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  const InlineInfo({
    super.key,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.info_outline, size: 16),
        const SizedBox(width: 6),
        Expanded(child: Text(message)),
        TextButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }
}

class LabeledTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final double? width;

  const LabeledTextField({
    super.key,
    required this.label,
    required this.controller,
    this.validator,
    this.keyboardType,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final field = TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
    if (width != null) return SizedBox(width: width, child: field);
    return field;
  }
}

// Convenience extension for .firstOrNull
extension FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
