import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zedu/features/features.dart';

import '../../../../../../helpers/helpers.dart';

void main() {
  testWidgets('Invite People opens the invite dialog', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: buildTestMaterialApp(
          Scaffold(
            body: BillingSection(
              billing: BillingInfo.empty(),
              onInvite: ({required email, required role}) async {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Invite People'));
    await tester.pumpAndSettle();

    expect(find.text('Invite Team Member'), findsOneWidget);
  });
}
