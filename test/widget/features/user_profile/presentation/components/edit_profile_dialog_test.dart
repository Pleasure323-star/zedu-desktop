import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

void main() {
  const account = ProfileAccount(
    name: 'Ada Lovelace',
    email: 'ada@example.com',
    timezone: 'Africa/Lagos',
  );

  Future<void> openDialog(
    WidgetTester tester,
    ValueChanged<ProfileAccount> onSave,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      buildTestMaterialApp(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showEditProfileDialog(context, account, onSave),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('rejects an unsupported manually entered country', (
    tester,
  ) async {
    ProfileAccount? saved;
    await openDialog(tester, (account) => saved = account);

    await tester.enterText(find.byType(TextFormField).last, 'ugggge');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('Select a country from the list'), findsOneWidget);
    expect(saved, isNull);
  });

  testWidgets('passes the selected country to the save callback', (
    tester,
  ) async {
    ProfileAccount? saved;
    await openDialog(tester, (account) => saved = account);

    final countryField = find.byType(TextFormField).last;
    await tester.tap(countryField);
    await tester.enterText(countryField, 'Nige');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nigeria').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(saved?.country, 'Nigeria');
  });

  testWidgets('accepts and normalizes a typed country without selecting it', (
    tester,
  ) async {
    ProfileAccount? saved;
    await openDialog(tester, (account) => saved = account);

    await tester.enterText(find.byType(TextFormField).last, 'nigeria');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('Select a country from the list'), findsNothing);
    expect(saved?.country, 'Nigeria');
  });
}
