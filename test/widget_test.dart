// test/widget_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_music_player/main.dart';

void main() {
  testWidgets('Basic app startup test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MusicPlayerApp());

    // Simple test to verify app builds
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
