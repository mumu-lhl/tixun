import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/features/library/chat_study_actions.dart';

void main() {
  testWidgets(
    'Expanded Python output uses its own scroll storage, separate from tile state',
    (t) async {
      final op = AiToolOperation(
        id: 'py-1',
        runId: 'run',
        sessionId: 'session',
        name: 'run_python',
        arguments: '{"code":"print(9)","purpose":"核对积分"}',
        status: 'succeeded',
        result: '{"ok":true,"stdout":"9"}',
        createdAt: DateTime(2026),
      );
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              key: const PageStorageKey('conversation'),
              children: [PythonHistoryCard(op)],
            ),
          ),
        ),
      );
      await t.tap(find.text('Python · 执行完成'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('9'), findsOneWidget);
      await t.tap(find.text('Python · 执行完成'));
      await t.pumpAndSettle();
      await t.tap(find.text('Python · 执行完成'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('9'), findsOneWidget);
    },
  );
}
