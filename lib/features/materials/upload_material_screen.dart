import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/models/material.dart';
import '../../core/models/subject.dart';
import '../auth/auth_controller.dart';
import 'material_upload.dart';

class UploadMaterialArgs {
  const UploadMaterialArgs({required this.subject, required this.kind});

  final Subject subject;
  final MaterialKind kind;
}

class UploadMaterialScreen extends StatefulWidget {
  const UploadMaterialScreen({required this.args, super.key});

  final UploadMaterialArgs args;

  @override
  State<UploadMaterialScreen> createState() => _UploadMaterialScreenState();
}

class _UploadMaterialScreenState extends State<UploadMaterialScreen> {
  SelectedMaterialFile? selectedFile;
  String? pickerError;

  bool get isPdf => widget.args.kind == MaterialKind.pdf;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.watch(context);
    final selected = selectedFile;
    return Scaffold(
      appBar: AppBar(title: Text(isPdf ? 'Upload PDF' : 'Upload image')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.args.subject.name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            isPdf
                ? 'PDF files up to 10 MiB.'
                : 'PNG, JPG, JPEG, or WEBP images up to 8 MiB.',
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: state.isUploadingMaterial ? null : _pickFile,
            icon: Icon(
              isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
            ),
            label: Text(isPdf ? 'Choose PDF' : 'Choose image'),
          ),
          if (selected != null) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: Icon(
                  isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
                ),
                title: Text(selected.name),
                subtitle: Text(formatFileSize(selected.reportedSizeBytes)),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: state.isUploadingMaterial ? null : _upload,
              icon: state.isUploadingMaterial
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(
                state.isUploadingMaterial
                    ? state.uploadStage ?? 'Uploading material'
                    : 'Upload material',
              ),
            ),
          ],
          if (pickerError != null || state.uploadError != null) ...[
            const SizedBox(height: 12),
            Text(
              pickerError ?? state.uploadError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (state.isUploadingMaterial) ...[
            const SizedBox(height: 12),
            state.uploadProgress == null
                ? const LinearProgressIndicator()
                : LinearProgressIndicator(value: state.uploadProgress),
          ],
        ],
      ),
    );
  }

  Future<void> _pickFile() async {
    try {
      final selected = await AppStateScope.read(
        context,
      ).pickMaterialFile(widget.args.kind);
      if (!mounted || selected == null) return;
      validateMaterialUploadSelection(selected, widget.args.kind);
      setState(() {
        selectedFile = selected;
        pickerError = null;
      });
    } on MaterialUploadValidationException catch (error) {
      if (!mounted) return;
      setState(() => pickerError = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => pickerError = 'Could not open the file picker.');
    }
  }

  Future<void> _upload() async {
    final selected = selectedFile;
    if (selected == null) return;
    final uploaded = await AppStateScope.read(context).uploadMaterialFor(
      AuthScope.read(context).user,
      subjectId: widget.args.subject.id,
      kind: widget.args.kind,
      selectedFile: selected,
    );
    if (!mounted || !uploaded) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Material uploaded.')));
    Navigator.pop(context);
  }
}
