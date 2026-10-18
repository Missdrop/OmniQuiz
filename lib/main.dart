import 'package:flutter/material.dart';

import 'app/theme.dart';

void main() => runApp(
  MaterialApp(
    title: 'OmniQuiz',
    theme: buildTheme(),
    home: const Scaffold(body: Center(child: Text('OmniQuiz'))),
  ),
);
