// Expands an inline source preview after checking the imported file revision.

import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../application/ports/repositories.dart';
import '../../domain/models.dart';
import '../../l10n/localization.dart';
import '../../infrastructure/platform/folder_permissions.dart';

/// Expands a source underneath its button; changing questions resets the preview.
class SourceCitation extends StatefulWidget {
  const SourceCitation({
    super.key,
    required this.source,
    required this.materials,
    this.libraryDirectory,
    this.trailing,
  });
  final Widget? trailing;
  final SourceChunk source;
  final MaterialRepository materials;
  final String? libraryDirectory;
  @override
  State<SourceCitation> createState() => _SourceCitationState();
}

class _SourceCitationState extends State<SourceCitation> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    final page = RegExp(r'^Page (\d+)')
        .firstMatch(widget.source.location)
        ?.group(1);
    final controls = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.sourceName(widget.source.documentName) +
              (page == null ? '' : ' · ${context.l10n.sourcePage(page)}'),
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        OutlinedButton.icon(
          onPressed: () => setState(() => _expanded = !_expanded),
          icon: Icon(
            _expanded ? Icons.expand_less : Icons.description_outlined,
          ),
          label: Text(
            _expanded ? context.l10n.hideSource : context.l10n.fullSource,
          ),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.trailing == null)
          controls
        else
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 740) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(flex: 2, child: controls),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 3,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: widget.trailing!,
                      ),
                    ),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  controls,
                  const SizedBox(height: 8),
                  widget.trailing!,
                ],
              );
            },
          ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              height: (MediaQuery.sizeOf(context).height * .55).clamp(
                280.0,
                600.0,
              ),
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SourceViewer(
                source: widget.source,
                materials: widget.materials,
                libraryDirectory: widget.libraryDirectory,
              ),
            ),
          ),
      ],
    );
  }
}

/// A PDF is rendered from verified bytes so a replaced file cannot mislead a citation.
class SourceViewer extends StatefulWidget {
  const SourceViewer({
    super.key,
    required this.source,
    required this.materials,
    this.libraryDirectory,
  });
  final SourceChunk source;
  final MaterialRepository materials;
  final String? libraryDirectory;
  @override
  State<SourceViewer> createState() => _SourceViewerState();
}

class _SourceViewerState extends State<SourceViewer> {
  final _controller = PdfViewerController();
  late final Future<Uint8List?> _pdf = _load();
  Future<Uint8List?> _load() async {
    if (!widget.source.documentName.toLowerCase().endsWith('.pdf')) return null;
    try {
      if (widget.libraryDirectory != null) {
        await FolderPermissions.restore(widget.libraryDirectory!);
      }
      final documents = await widget.materials.documents();
      final source = documents
          .where((d) => d.id == widget.source.documentId)
          .firstOrNull;
      if (source == null || source.revision != widget.source.revision) {
        return null;
      }
      final file = File(source.origin);
      if (await FileSystemEntity.type(file.path, followLinks: false) !=
              FileSystemEntityType.file ||
          await file.length() > 20 * 1024 * 1024) {
        return null;
      }
      final bytes = await file.readAsBytes();
      if (sha256.convert(bytes).toString() != widget.source.revision) {
        return null;
      }
      await pdfrxFlutterInitialize();
      return bytes;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final page =
        int.tryParse(
          RegExp(r'^Page (\d+)').firstMatch(widget.source.location)?.group(1) ??
              '',
        ) ??
        1;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              tooltip: context.l10n.zoomOut,
              icon: const Icon(Icons.zoom_out),
              onPressed: () {
                if (_controller.isReady) _controller.zoomDown();
              },
            ),
            IconButton(
              tooltip: context.l10n.zoomIn,
              icon: const Icon(Icons.zoom_in),
              onPressed: () {
                if (_controller.isReady) _controller.zoomUp();
              },
            ),
          ],
        ),
        Expanded(
          child: FutureBuilder<Uint8List?>(
            future: _pdf,
            builder: (context, state) {
              if (state.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state.data != null) {
                return PdfViewer.data(
                  state.data!,
                  sourceName: widget.source.revision,
                  initialPageNumber: page,
                  controller: _controller,
                );
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.source.documentName.toLowerCase().endsWith(
                      '.pdf',
                    )) ...[
                      Text(
                        context.l10n.pdfSourceUnavailable,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    SelectableText(
                      widget.source.text,
                      style: const TextStyle(height: 1.8),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
