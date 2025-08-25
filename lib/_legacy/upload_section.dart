import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class UploadSection extends StatelessWidget {
  final VoidCallback onPickFiles;
  final List<PlatformFile> files;
  const UploadSection({
    super.key,
    required this.onPickFiles,
    required this.files,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      children: [
        SizedBox(
          width: 220,
          child: OutlinedButton.icon(
            onPressed: onPickFiles,
            icon: const Icon(Icons.upload_file),
            label: const Text('Upload plans/images'),
          ),
        ),
        if (files.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Uploaded files',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: files
                    .map(
                      (f) => Chip(
                        avatar: const Icon(Icons.insert_drive_file, size: 16),
                        label: Text(f.name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
      ],
    );
  }
}

class PrimaryActions extends StatelessWidget {
  final VoidCallback onGenerate;
  const PrimaryActions({super.key, required this.onGenerate});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: FilledButton.icon(
        onPressed: onGenerate,
        icon: const Icon(Icons.calculate),
        label: const Text('Generate'),
      ),
    );
  }
}
