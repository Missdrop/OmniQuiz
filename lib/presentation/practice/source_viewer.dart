// Opens the original cited PDF at its page, after checking the imported revision.

import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../application/ports/repositories.dart';
import '../../domain/models.dart';
import '../../l10n/localization.dart';
import '../../infrastructure/platform/folder_permissions.dart';

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
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: context.l10n.close,
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.source.documentName,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
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
        body: SafeArea(
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
                padding: const EdgeInsets.all(24),
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
                      const SizedBox(height: 20),
                    ],
                    Text(
                      widget.source.location,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 20),
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
      ),
    );
  }
}
