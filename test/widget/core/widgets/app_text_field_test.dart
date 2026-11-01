import 'package:zedu/core/core.dart';
import '../../../helpers/helpers.dart';

void main() {
  group('AppTextField password visibility toggle', () {
    testWidgets('labels the toggle with the action it performs', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        buildTestMaterialApp(
          Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: AppTextField(
                controller: TextEditingController(text: 'secret123'),
                hint: 'Password',
                isPassword: true,
              ),
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Show password'), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Hide password'), findsOneWidget);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

      semantics.dispose();
    });
  });
}
