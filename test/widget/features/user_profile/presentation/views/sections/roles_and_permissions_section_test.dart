import 'package:zedu/features/features.dart';

import '../../../../../../helpers/helpers.dart';

void main() {
  testWidgets('the page title matches the "Roles & permissions" menu item', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestMaterialApp(
        const Scaffold(body: RolesAndPermissionsSection(roles: [])),
      ),
    );

    expect(find.text('Roles & permissions'), findsOneWidget);
    expect(find.text('Roles & Permissions'), findsNothing);
  });
}
