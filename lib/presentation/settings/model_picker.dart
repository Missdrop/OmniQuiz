// Filters discovered model identifiers while allowing settings to retain a stable selection.

import 'package:flutter/material.dart';

import '../../l10n/localization.dart';

/// A searchable view over model IDs; it does not fetch or activate provider connections.
class ModelPicker extends StatefulWidget {
  const ModelPicker({super.key, required this.models});
  final List<String> models;

  @override
  State<ModelPicker> createState() => _ModelPickerState();
}

class _ModelPickerState extends State<ModelPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final matches = widget.models
        .where((model) => model.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    return AlertDialog(
      title: Text(context.l10n.chooseModel),
      scrollable: true,
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(labelText: context.l10n.searchModels),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height:
                  (matches.length * MediaQuery.textScalerOf(context).scale(64))
                      .clamp(0.0, 240.0),
              child: ListView.builder(
                itemCount: matches.length,
                itemBuilder: (context, index) => ListTile(
                  title: Text(matches[index]),
                  onTap: () => Navigator.pop(context, matches[index]),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
      ],
    );
  }
}
