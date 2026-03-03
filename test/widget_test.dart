import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:unimas_smartbus/constants/app_theme.dart';

void main() {
  testWidgets('Light theme app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: Center(child: Text('UNIMAS SmartBus')),
        ),
      ),
    );

    expect(find.text('UNIMAS SmartBus'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme?.useMaterial3, isTrue);
  });

  test('Dark theme smoke test', () {
    final theme = AppTheme.darkTheme;
    expect(theme.useMaterial3, isTrue);
    expect(theme.colorScheme.brightness, Brightness.dark);
  });
}
