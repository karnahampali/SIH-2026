import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pramaan/main.dart';

void main() {
  testWidgets('PRAMAAN app launches', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: PramaanApp()),
    );
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
