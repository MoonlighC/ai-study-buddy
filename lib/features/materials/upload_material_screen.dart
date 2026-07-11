import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/models/material.dart';
import '../../core/models/subject.dart';
import '../../l10n/l10n_extensions.dart';
import '../../l10n/localized_formatters.dart';
import '../auth/auth_controller.dart';
import '../../shared/widgets/glass_components.dart';
import '../../shared/widgets/responsive_app_scaffold.dart';
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
    final l10n = context.l10n;
    return ResponsiveAppScaffold(
      title: isPdf ? l10n.uploadPdfTitle : l10n.uploadImageTitle,
      subtitle: widget.args.subject.name,
      showBack: true,
      body: ResponsiveContent(
        width: ResponsiveContentWidth.reading,
        child: ListView(
          key: const ValueKey('upload-material-scroll-view'),
          children: [
            Text(
              widget.args.subject.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(isPdf ? l10n.uploadPdfGuidance : l10n.uploadImageGuidance),
            const SizedBox(height: 16),
            GlassCard(
              key: const ValueKey('upload-picker-surface'),
              reading: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GlassStatusChip(
                    label: isPdf ? l10n.uploadPdfKind : l10n.uploadImageKind,
                    icon: isPdf
                        ? Icons.picture_as_pdf_outlined
                        : Icons.image_outlined,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: state.isUploadingMaterial ? null : _pickFile,
                    icon: Icon(
                      isPdf
                          ? Icons.picture_as_pdf_outlined
                          : Icons.image_outlined,
                    ),
                    label: Text(
                      isPdf ? l10n.uploadChoosePdf : l10n.uploadChooseImage,
                    ),
                  ),
                ],
              ),
            ),
            if (selected != null) ...[
              const SizedBox(height: 16),
              GlassCard(
                key: const ValueKey('selected-file-metadata'),
                child: AppListRow(
                  leading: Icon(
                    isPdf
                        ? Icons.picture_as_pdf_outlined
                        : Icons.image_outlined,
                  ),
                  title: Text(selected.name),
                  subtitle: Text(
                    '${isPdf ? l10n.uploadPdfKind : l10n.uploadImageKind} · ${LocalizedFormatters.fileSize(l10n, selected.reportedSizeBytes)}',
                  ),
                  showDivider: false,
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
                      ? context.localizedSafeMessage(
                          state.uploadStage ?? 'Uploading material',
                        )
                      : l10n.uploadMaterial,
                ),
              ),
            ],
            if (pickerError != null || state.uploadError != null) ...[
              const SizedBox(height: 12),
              Text(
                context.localizedSafeMessage(pickerError ?? state.uploadError!),
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
      setState(() => pickerError = context.l10n.errorCouldNotOpenFilePicker);
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
    ).showSnackBar(SnackBar(content: Text(context.l10n.materialUploaded)));
    Navigator.pop(context);
  }
}
