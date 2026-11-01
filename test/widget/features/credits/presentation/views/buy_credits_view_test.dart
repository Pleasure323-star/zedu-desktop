import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class MockCreditsRepository extends Mock implements CreditsRepository {}

class FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState(
    status: AuthStatus.authenticated,
    user: User(
      id: 'sample-user',
      firstName: 'Sample',
      lastName: 'User',
      email: 'sample@example.com',
      phone: '',
      username: 'SampleUser',
      isVerified: true,
      isOnboarded: true,
      createdAt: DateTime.utc(2026, 1, 1),
      currentOrg: 'test-org',
      currentOrganisationSlug: 'test-org',
      avatarUrl: '',
      defaultAvatarUrl: '',
      creditBalance: 100,
    ),
  );
}

class FakeUserProfileNotifier extends UserProfileNotifier {
  @override
  UserProfileState build() =>
      const UserProfileState(section: UserProfileSection.billing);
}

void main() {
  for (final balance in [0, 25]) {
    testWidgets('Billing and user menu show the loaded balance of $balance', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = MockCreditsRepository();
      final usage = Completer<Result<CreditUsage>>();
      when(
        repository.getPackages,
      ).thenAnswer((_) async => const Success<List<CreditPackage>>([]));
      when(
        () => repository.getUsage('test-org'),
      ).thenAnswer((_) => usage.future);
      when(
        () => repository.getUsageReport('test-org'),
      ).thenAnswer((_) async => const Success(CreditUsageReport.empty));
      when(
        () => repository.getTransactions('test-org'),
      ).thenAnswer((_) async => const Success<List<CreditTransaction>>([]));

      final container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(FakeAuthNotifier.new),
          userProfileNotifierProvider.overrideWith(FakeUserProfileNotifier.new),
          creditsRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: buildTestMaterialApp(const BuyCreditsView()),
        ),
      );
      await tester.pump();
      expect(
        container.read(creditsNotifierProvider).status,
        CreditsStatus.loading,
      );
      expect(find.text('100 AI credits'), findsOneWidget);

      usage.complete(
        Success(
          CreditUsage(
            balance: balance,
            totalPurchased: 100,
            totalConsumed: 100 - balance,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        container.read(creditsNotifierProvider).status,
        CreditsStatus.ready,
      );
      expect(container.read(authNotifierProvider).user!.creditBalance, 100);
      expect(find.text('$balance AI credits'), findsOneWidget);
      expect(find.text('100 AI credits'), findsNothing);

      await tester.tap(find.byType(TopUserMenu));
      await tester.pumpAndSettle();
      expect(find.text('AI Credits: $balance'), findsOneWidget);
      expect(find.text('$balance AI credits'), findsOneWidget);
      expect(tester.takeException(), isNull);
      verify(() => repository.getUsage('test-org')).called(1);
    });
  }
}
