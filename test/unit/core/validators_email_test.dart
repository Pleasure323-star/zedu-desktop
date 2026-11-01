import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';

void main() {
  // The Edit profile, Edit account and Invite Team Member forms all validate
  // with `Validators.validateEmail(context, v.trim())`.
  Future<String?> validate(WidgetTester tester, String value) async {
    String? result;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          result = Validators.validateEmail(context, value.trim());
          return const SizedBox.shrink();
        },
      ),
    );
    return result;
  }

  testWidgets('rejects a lone @ and an address with no domain', (tester) async {
    expect(await validate(tester, '@'), isNotNull);
    expect(await validate(tester, 'name@'), isNotNull);
  });

  testWidgets('accepts a valid address, ignoring surrounding spaces', (
    tester,
  ) async {
    expect(await validate(tester, '  ada@example.com  '), isNull);
  });
}
