import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../core/models/material.dart';
import '../../core/models/subject.dart';
import '../../l10n/l10n_extensions.dart';
import '../../l10n/localized_formatters.dart';
import '../../shared/widgets/glass_components.dart';
import '../../shared/widgets/responsive_app_scaffold.dart';
import '../auth/auth_controller.dart';
import 'material_upload.dart';
import 'material_upload_queue.dart';
import 'material_analysis_repository.dart';

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
  MaterialFilePickerBatch? _selection;
  String? _pickerError;
  bool _picking = false;
  AnalysisProcessingMode _analysisMode = AnalysisProcessingMode.recommended;
  bool _staleRowsReconciled = false;

  bool get isPdf => widget.args.kind == MaterialKind.pdf;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_staleRowsReconciled) return;
    _staleRowsReconciled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = AppStateScope.read(context);
      final stale = state.materialUploadQueue.pruneStaleAuthoritativeRows(
        state.materials.map((material) => material.id).toSet(),
      );
      if (stale.isEmpty || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.uploadStaleMaterialRemoved)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.watch(context);
    final queue = state.materialUploadQueue;
    final l10n = context.l10n;
    return ResponsiveAppScaffold(
      title: isPdf ? l10n.uploadPdfTitle : l10n.uploadImageTitle,
      subtitle: widget.args.subject.name,
      showBack: true,
      body: ResponsiveContent(
        width: ResponsiveContentWidth.reading,
        child: ListenableBuilder(
          listenable: queue,
          builder: (context, _) {
            final items = queue.items
                .where(
                  (item) =>
                      item.subjectId == widget.args.subject.id &&
                      item.kind == widget.args.kind,
                )
                .toList(growable: false);
            final succeeded = items
                .where(
                  (item) =>
                      item.status == MaterialUploadQueueStatus.completed ||
                      item.status ==
                          MaterialUploadQueueStatus.completedWithWarnings,
                )
                .length;
            final skipped = items
                .where(
                  (item) => item.status == MaterialUploadQueueStatus.skipped,
                )
                .length;
            final failed = items
                .where(
                  (item) => item.status == MaterialUploadQueueStatus.failed,
                )
                .length;
            return ListView(
              key: const ValueKey('upload-material-scroll-view'),
              children: [
                Text(
                  widget.args.subject.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(isPdf ? l10n.uploadPdfGuidance : l10n.uploadImageGuidance),
                const SizedBox(height: 4),
                Text(l10n.uploadMaximumFiles),
                const SizedBox(height: 16),
                GlassCard(
                  key: const ValueKey('upload-picker-surface'),
                  reading: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GlassStatusChip(
                        label: isPdf
                            ? l10n.uploadPdfKind
                            : l10n.uploadImageKind,
                        icon: isPdf
                            ? Icons.picture_as_pdf_outlined
                            : Icons.image_outlined,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _picking ? null : _pickFiles,
                        icon: _picking
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                isPdf
                                    ? Icons.picture_as_pdf_outlined
                                    : Icons.image_outlined,
                              ),
                        label: Text(
                          isPdf ? l10n.uploadChoosePdf : l10n.uploadChooseImage,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.uploadSelectMultiple,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                if (_selection case final selection?) ...[
                  const SizedBox(height: 16),
                  _SelectionCard(selection: selection, kind: widget.args.kind),
                  if (selection.validFiles.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => _enqueue(selection),
                      icon: const Icon(Icons.cloud_upload_outlined),
                      label: Text(l10n.uploadMaterial),
                    ),
                  ],
                ],
                if (items.isEmpty) ...[
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.auto_awesome_outlined),
                    title: Text(l10n.analysisRecommended),
                    subtitle: Text(l10n.analysisRecommendedDescription),
                  ),
                  ExpansionTile(
                    key: const ValueKey('analysis-advanced-settings'),
                    tilePadding: EdgeInsets.zero,
                    title: Text(l10n.analysisAdvancedSettings),
                    children: [
                      RadioGroup<AnalysisProcessingMode>(
                        groupValue: _analysisMode,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _analysisMode = value);
                          }
                        },
                        child: Column(
                          children: [
                            RadioListTile<AnalysisProcessingMode>(
                              value: AnalysisProcessingMode.recommended,
                              title: Text(l10n.analysisRecommended),
                            ),
                            RadioListTile<AnalysisProcessingMode>(
                              value: AnalysisProcessingMode.economy,
                              title: Text(l10n.analysisEconomy),
                              subtitle: Text(l10n.analysisEconomyWarning),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                if (_pickerError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _pickerError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                if (items.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    l10n.materialSelectedFiles(items.length),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (succeeded > 0 && (skipped > 0 || failed > 0)) ...[
                    Text(l10n.uploadPartialSuccess),
                    const SizedBox(height: 4),
                  ],
                  Text(l10n.materialBatchResult(failed, skipped, succeeded)),
                  const SizedBox(height: 12),
                  for (final item in items) ...[
                    _QueueItemCard(item: item, state: state),
                    const SizedBox(height: 10),
                  ],
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _pickFiles() async {
    setState(() {
      _picking = true;
      _pickerError = null;
    });
    try {
      final selection = await AppStateScope.read(
        context,
      ).pickMaterialFiles(widget.args.kind);
      if (!mounted || selection == null) return;
      setState(() {
        _selection = selection;
        _pickerError =
            selection.errorCode == MaterialFileBatchErrorCode.tooManyFiles
            ? context.l10n.materialMaximumFilesError
            : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _pickerError = context.l10n.errorCouldNotOpenFilePicker);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _enqueue(MaterialFilePickerBatch selection) {
    final added = AppStateScope.read(context).enqueueMaterialBatch(
      AuthScope.read(context).user,
      subjectId: widget.args.subject.id,
      kind: widget.args.kind,
      batch: selection,
      analysisMode: _analysisMode,
    );
    if (!added) return;
    setState(() => _selection = null);
  }
}

class _SelectionCard extends StatelessWidget {
  const _SelectionCard({required this.selection, required this.kind});

  final MaterialFilePickerBatch selection;
  final MaterialKind kind;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      key: const ValueKey('selected-file-metadata'),
      child: Column(
        children: [
          for (final result in selection.results)
            AppListRow(
              leading: Icon(
                result.isValid
                    ? (kind == MaterialKind.pdf
                          ? Icons.picture_as_pdf_outlined
                          : Icons.image_outlined)
                    : Icons.error_outline,
              ),
              title: Text(result.file.name),
              subtitle: Text(
                result.isValid
                    ? LocalizedFormatters.fileSize(
                        context.l10n,
                        result.file.reportedSizeBytes,
                      )
                    : '${LocalizedFormatters.fileSize(context.l10n, result.file.reportedSizeBytes)} · ${_validationMessage(context, result.errorCode!)}',
              ),
              showDivider: result != selection.results.last,
            ),
        ],
      ),
    );
  }
}

class _QueueItemCard extends StatelessWidget {
  const _QueueItemCard({required this.item, required this.state});

  final MaterialUploadQueueItem item;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final failed = item.status == MaterialUploadQueueStatus.failed;
    final completed =
        item.status == MaterialUploadQueueStatus.completed ||
        item.status == MaterialUploadQueueStatus.completedWithWarnings;
    final retryable = state.materialUploadQueue.canRetry(item.queueId);
    final skipped = item.status == MaterialUploadQueueStatus.skipped;
    return GlassCard(
      key: ValueKey('upload-queue-${item.queueId}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppListRow(
            leading: Icon(
              completed
                  ? Icons.check_circle_outline
                  : skipped
                  ? Icons.block_outlined
                  : failed
                  ? Icons.error_outline
                  : Icons.cloud_upload_outlined,
            ),
            title: Text(item.fileName),
            subtitle: Text(_queueStatus(context, item)),
            showDivider: false,
            trailing: completed
                ? IconButton(
                    tooltip: context.l10n.materialDetailTitle,
                    onPressed: () => _openMaterial(context),
                    icon: const Icon(Icons.open_in_new),
                  )
                : null,
          ),
          if (item.status == MaterialUploadQueueStatus.uploading ||
              item.status == MaterialUploadQueueStatus.processing) ...[
            const SizedBox(height: 8),
            item.progress == null
                ? const LinearProgressIndicator()
                : LinearProgressIndicator(value: item.progress),
          ],
          if (retryable) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => state.materialUploadQueue.retry(item.queueId),
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.materialRetry),
            ),
          ] else if (failed) ...[
            const SizedBox(height: 8),
            Text(context.l10n.uploadTerminalFailureNoRetry),
          ],
        ],
      ),
    );
  }

  void _openMaterial(BuildContext context) {
    final materialId = item.authoritativeMaterialId;
    final material = materialId == null ? null : state.materialById(materialId);
    if (material == null) {
      if (materialId != null) {
        state.materialUploadQueue.removeAuthoritativeMaterial(materialId);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.uploadStaleMaterialRemoved)),
      );
      return;
    }
    Navigator.pushNamed(context, AppRoutes.materialDetail, arguments: material);
  }
}

String _queueStatus(BuildContext context, MaterialUploadQueueItem item) {
  if (item.status == MaterialUploadQueueStatus.failed) {
    return context.materialUploadQueueErrorMessage(item.errorCode);
  }
  return switch (item.status) {
    MaterialUploadQueueStatus.queued => context.l10n.uploadQueued,
    MaterialUploadQueueStatus.uploading => context.l10n.uploadUploading,
    MaterialUploadQueueStatus.processing => context.l10n.uploadProcessing,
    MaterialUploadQueueStatus.completed => context.l10n.uploadCompleted,
    MaterialUploadQueueStatus.completedWithWarnings =>
      context.l10n.analysisCompletedWithWarnings,
    MaterialUploadQueueStatus.userRetryRequired =>
      context.l10n.uploadUserRetryRequired,
    MaterialUploadQueueStatus.skipped =>
      context.materialUploadQueueErrorMessage(item.errorCode),
    MaterialUploadQueueStatus.failed => context.l10n.uploadFailed,
    MaterialUploadQueueStatus.deletedStale =>
      context.l10n.uploadStaleMaterialRemoved,
  };
}

String _validationMessage(
  BuildContext context,
  MaterialFileValidationCode code,
) => switch (code) {
  MaterialFileValidationCode.unsupportedFile =>
    context.l10n.materialUnsupportedFileType,
  MaterialFileValidationCode.invalidFile => context.l10n.materialInvalidFile,
  MaterialFileValidationCode.emptyFile => context.localizedSafeMessage(
    'The selected file is empty.',
  ),
  MaterialFileValidationCode.fileTooLarge => context.l10n.materialFileTooLarge,
};
