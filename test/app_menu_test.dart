import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/ui/app_menu.dart';

void main() {
  testWidgets('selection fields support intrinsic dialog layout', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => AlertDialog(
                  scrollable: true,
                  content: SizedBox(
                    width: 520,
                    child: AppSelectField<String>(
                      initialValue: 'A',
                      decoration: const InputDecoration(
                        labelText: 'Teaching mode',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'A', child: Text('Guided')),
                      ],
                      onChanged: (_) {},
                    ),
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await t.tap(find.byType(AppSelectField<String>));
    await t.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsOneWidget);
  });

  testWidgets('outside dismissal clears the expanded field highlight', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppSelectField<String>(
            initialValue: 'A',
            items: const [DropdownMenuItem(value: 'A', child: Text('Alpha'))],
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await t.tap(find.byType(AppSelectField<String>));
    await t.pumpAndSettle();
    expect(
      t.widget<InputDecorator>(find.byType(InputDecorator)).isFocused,
      true,
    );
    await t.tapAt(const Offset(700, 550));
    await t.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNothing);
    expect(
      t.widget<InputDecorator>(find.byType(InputDecorator)).isFocused,
      false,
    );
  });

  testWidgets('selection commits after closing and follows external changes', (
    t,
  ) async {
    String? value = 'A';
    var callbacks = 0;
    late StateSetter rebuild;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, set) {
              rebuild = set;
              return AppSelectField<String>(
                initialValue: value,
                items: const [
                  DropdownMenuItem(value: 'A', child: Text('Alpha')),
                  DropdownMenuItem(value: 'B', child: Text('Beta')),
                ],
                onChanged: (v) => set(() {
                  value = v;
                  callbacks++;
                }),
              );
            },
          ),
        ),
      ),
    );
    await t.tap(find.byType(AppSelectField<String>));
    await t.pumpAndSettle();
    await t.tap(find.text('Beta'));
    await t.pumpAndSettle();
    expect(value, 'B');
    expect(callbacks, 1);
    expect(find.byType(MenuItemButton), findsNothing);
    rebuild(() => value = 'A');
    await t.pumpAndSettle();
    expect(find.text('Alpha'), findsOneWidget);
    await t.tap(find.byType(AppSelectField<String>));
    await t.pumpAndSettle();
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(callbacks, 1);
    expect(find.byType(MenuItemButton), findsNothing);
  });
  testWidgets('reduced motion and disabled items retain selection rules', (
    t,
  ) async {
    var calls = 0;
    await t.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(800, 600),
            disableAnimations: true,
          ),
          child: Scaffold(
            body: AppSelectField<String>(
              initialValue: 'A',
              items: const [
                DropdownMenuItem(value: 'A', child: Text('Alpha')),
                DropdownMenuItem(
                  value: 'B',
                  enabled: false,
                  child: Text('Beta'),
                ),
              ],
              onChanged: (_) => calls++,
            ),
          ),
        ),
      ),
    );
    await t.tap(find.byType(AppSelectField<String>));
    await t.pumpAndSettle();
    expect(t.widget<MenuAnchor>(find.byType(MenuAnchor)).animated, false);
    await t.tap(find.text('Beta'));
    await t.pumpAndSettle();
    expect(calls, 0);
  });
}
