// Loads the bundled policy for the resolved UI locale, including when the device is offline.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/localization.dart';

/// Displays bundled, localized privacy text without a network dependency.
class PrivacyPolicyPage extends StatefulWidget {
  const PrivacyPolicyPage({super.key});
  @override
  State<PrivacyPolicyPage> createState() => _PrivacyPolicyPageState();
}

class _PrivacyPolicyPageState extends State<PrivacyPolicyPage> {
  String? _language;
  late Future<String> _text;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = Localizations.localeOf(context).languageCode == 'zh'
        ? 'zh'
        : 'en';
    if (_language != language) {
      _language = language;
      _text = rootBundle.loadString('assets/legal/privacy_$language.txt');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.privacyPolicy)),
    body: FutureBuilder<String>(
      future: _text,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text(context.l10n.privacyLoadFailed));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: SelectableText(
                snapshot.data!,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(height: 1.7),
              ),
            ),
          ),
        );
      },
    ),
  );
}
