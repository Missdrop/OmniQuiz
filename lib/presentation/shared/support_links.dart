// Opens user-reviewed report drafts without attaching study materials or account credentials.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/localization.dart';

// No question, source material, credentials or account identifiers in this URL.
final aiReportUri = Uri.https('github.com', '/Missdrop/OmniQuiz/issues/new', {
  'title': 'AI content report / AI 内容反馈',
  'body':
      'Describe the incorrect or inappropriate AI content and what you expected.\n'
      '请描述错误或不当的 AI 内容，以及预期结果。\n\n'
      'Reports are public. Do not include private study materials, account details or credentials.\n'
      '报告公开可见。请勿包含私人资料、账号信息或密钥。',
});

Future<void> openSupportLink(
  BuildContext context,
  Uri uri,
  String title,
) async {
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  } catch (_) {}
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SelectableText(uri.toString()),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.close),
        ),
      ],
    ),
  );
}
