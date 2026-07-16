import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../app/app_state.dart';
import '../../core/models/material.dart';
import '../../l10n/l10n_extensions.dart';
import '../../shared/widgets/glass_components.dart';
import '../../shared/widgets/responsive_app_scaffold.dart';
import '../auth/auth_controller.dart';
import 'original_material_repository.dart';

@visibleForTesting
int clampMaterialInitialPage(int? requestedPage, int pageCount) =>
    math.max(1, math.min(requestedPage ?? 1, math.max(1, pageCount)));

@visibleForTesting
bool materialPdfCanGoPrevious(int page) => page > 1;

@visibleForTesting
bool materialPdfCanGoNext(int page, int pageCount) =>
    pageCount > 0 && page < pageCount;

class MaterialViewerArgs {
  const MaterialViewerArgs({
    required this.materialId,
    required this.kind,
    this.initialPage,
  });

  final String materialId;
  final MaterialKind kind;
  final int? initialPage;
}

class MaterialViewerScreen extends StatefulWidget {
  const MaterialViewerScreen({required this.args, super.key});

  final MaterialViewerArgs? args;

  @override
  State<MaterialViewerScreen> createState() => _MaterialViewerScreenState();
}

class _MaterialViewerScreenState extends State<MaterialViewerScreen> {
  OriginalMaterialLoadResult? _result;
  bool _loading = true;
  bool _started = false;
  int _loadGeneration = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    _result?.release();
    setState(() {
      _result = null;
      _loading = true;
    });
    final args = widget.args;
    final user = AuthScope.read(context).user;
    if (args == null || user == null) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loading = false;
        _result = const OriginalMaterialFailure(
          OriginalMaterialFailureCode.sessionExpired,
        );
      });
      return;
    }
    final result = await AppStateScope.read(context).originalMaterialRepository
        .load(
          expectedUser: user,
          materialId: args.materialId,
          expectedKind: args.kind,
        );
    if (!mounted || generation != _loadGeneration) {
      result.release();
      return;
    }
    setState(() {
      _result = result;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _loadGeneration += 1;
    _result?.release();
    _result = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return ResponsiveAppScaffold(
      title: context.l10n.materialViewerTitle,
      showBack: true,
      body: ResponsiveContent(
        width: ResponsiveContentWidth.wide,
        child: _loading
            ? _PreviewState(
                key: const ValueKey('material-preview-loading'),
                icon: Icons.hourglass_top_outlined,
                message: context.l10n.materialPreviewLoading,
                progress: true,
              )
            : switch (result) {
                OriginalMaterialSuccess content
                    when content.handle.kind == MaterialKind.pdf =>
                  _PdfBytesViewer(
                    handle: content.handle,
                    initialPage: widget.args?.initialPage,
                    onRetry: _load,
                  ),
                OriginalMaterialSuccess content
                    when content.handle.kind == MaterialKind.image =>
                  _ImageBytesViewer(handle: content.handle, onRetry: _load),
                OriginalMaterialFailure failure => _PreviewFailure(
                  code: failure.code,
                  onRetry: _load,
                ),
                _ => _PreviewFailure(
                  code: OriginalMaterialFailureCode.materialUnavailable,
                  onRetry: _load,
                ),
              },
      ),
    );
  }
}

class _PdfBytesViewer extends StatefulWidget {
  const _PdfBytesViewer({
    required this.handle,
    required this.onRetry,
    this.initialPage,
  });

  final OriginalMaterialPreviewHandle handle;
  final int? initialPage;
  final VoidCallback onRetry;

  @override
  State<_PdfBytesViewer> createState() => _PdfBytesViewerState();
}

class _PdfBytesViewerState extends State<_PdfBytesViewer> {
  final PdfViewerController _controller = PdfViewerController();
  int _page = 1;
  int _pageCount = 0;
  bool _loadFailed = false;

  @override
  Widget build(BuildContext context) {
    if (_loadFailed) {
      return _PreviewFailure(
        code: OriginalMaterialFailureCode.materialUnavailable,
        onRetry: widget.onRetry,
      );
    }
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Expanded(
          child: Semantics(
            label: context.l10n.materialPdfPreviewSemantics,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: widget.handle.useBytes(
                (bytes) => PdfViewer.data(
                  bytes,
                  sourceName: 'private-material.pdf',
                  controller: _controller,
                  initialPageNumber: 1,
                  params: PdfViewerParams(
                    backgroundColor: colors.surfaceContainerLowest,
                    limitRenderingCache: true,
                    linkHandlerParams: null,
                    onViewerReady: (document, controller) {
                      final pageCount = controller.pageCount;
                      final clamped = clampMaterialInitialPage(
                        widget.initialPage,
                        pageCount,
                      );
                      if (!mounted) return;
                      setState(() {
                        _pageCount = pageCount;
                        _page = clamped;
                      });
                      if (clamped != 1) {
                        controller.goToPage(
                          pageNumber: clamped,
                          duration: Duration.zero,
                        );
                      }
                    },
                    onPageChanged: (page) {
                      if (!mounted || page == null) return;
                      setState(() => _page = page);
                    },
                    onDocumentLoadFinished: (documentRef, succeeded) {
                      if (!mounted || succeeded) return;
                      setState(() => _loadFailed = true);
                    },
                    loadingBannerBuilder: (context, downloaded, total) =>
                        Center(
                          child: Semantics(
                            label: context.l10n.materialPreviewLoading,
                            child: const CircularProgressIndicator(),
                          ),
                        ),
                    errorBannerBuilder:
                        (context, error, stackTrace, documentRef) => Center(
                          child: Text(context.l10n.materialPreviewUnavailable),
                        ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: context.l10n.materialPreviousPage,
                onPressed: materialPdfCanGoPrevious(_page)
                    ? () => _controller.goToPage(pageNumber: _page - 1)
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Semantics(
                liveRegion: true,
                child: Text(
                  context.l10n.materialPageOf(
                    _page,
                    _pageCount == 0 ? 1 : _pageCount,
                  ),
                ),
              ),
              IconButton(
                tooltip: context.l10n.materialNextPage,
                onPressed: materialPdfCanGoNext(_page, _pageCount)
                    ? () => _controller.goToPage(pageNumber: _page + 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ImageBytesViewer extends StatelessWidget {
  const _ImageBytesViewer({required this.handle, required this.onRetry});

  final OriginalMaterialPreviewHandle handle;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.materialImagePreviewSemantics,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 6,
            child: Center(
              child: handle.useBytes(
                (bytes) => Image.memory(
                  bytes,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  errorBuilder: (context, error, stackTrace) => _PreviewFailure(
                    code: OriginalMaterialFailureCode.materialUnavailable,
                    onRetry: onRetry,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewFailure extends StatelessWidget {
  const _PreviewFailure({required this.code, required this.onRetry});

  final OriginalMaterialFailureCode code;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _PreviewState(
      key: const ValueKey('material-preview-failure'),
      icon: Icons.broken_image_outlined,
      message: context.originalMaterialFailureMessage(code),
      action: context.l10n.materialRetry,
      onAction: onRetry,
    );
  }
}

class _PreviewState extends StatelessWidget {
  const _PreviewState({
    required this.icon,
    required this.message,
    this.progress = false,
    this.action,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String message;
  final bool progress;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GlassCard(
        reading: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (progress) ...[
              const SizedBox(height: 16),
              const CircularProgressIndicator(),
            ],
            if (action != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(action!)),
            ],
          ],
        ),
      ),
    );
  }
}
