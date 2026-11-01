import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class _FakeProfileNotifier extends UserProfileNotifier {
  _FakeProfileNotifier(this.initial);

  final UserProfileState initial;
  int loadCalls = 0;

  @override
  UserProfileState build() => initial;

  @override
  Future<void> load() async => loadCalls++;
}

const _ada = TeamMember(
  id: 'u-1',
  email: 'ada@zedu.test',
  role: 'Admin',
  dateJoined: '2026-01-01',
  status: TeamMemberStatus.active,
  name: 'Ada Lovelace',
);

Future<_FakeProfileNotifier> _pumpPeopleCard(
  WidgetTester tester,
  UserProfileState state,
) async {
  final notifier = _FakeProfileNotifier(state);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [userProfileNotifierProvider.overrideWith(() => notifier)],
      child: buildTestMaterialApp(
        Scaffold(
          body: SidebarPopoutCard(
            HomeSidebarType.people,
            () {},
            () {},
            (_) {},
            (_) {},
          ),
        ),
      ),
    ),
  );
  return notifier;
}

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState(
    status: AuthStatus.authenticated,
    user: User(
      id: 'user-1',
      firstName: 'Test',
      lastName: 'User',
      email: 'test@example.com',
      phone: '',
      username: 'testuser',
      isVerified: true,
      isOnboarded: true,
      createdAt: DateTime(2026),
      currentOrg: 'org-1',
      currentOrganisationSlug: 'test-org',
      avatarUrl: '',
      defaultAvatarUrl: '',
    ),
  );
}

/// Hovers People in the real rail and returns how many times the profile was
/// reloaded.
Future<int> _hoverPeopleAndCountLoads(
  WidgetTester tester,
  UserProfileState state,
) async {
  tester.view.physicalSize = const Size(900, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final notifier = _FakeProfileNotifier(state);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userProfileNotifierProvider.overrideWith(() => notifier),
        authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
      ],
      child: buildTestMaterialApp(
        const Scaffold(
          body: Row(
            children: [
              AppSidebarRail(activeType: HomeSidebarType.home),
              Expanded(child: SizedBox()),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  addTearDown(mouse.removePointer);
  await mouse.moveTo(tester.getCenter(find.text('People')));
  await tester.pumpAndSettle();
  return notifier.loadCalls;
}

void main() {
  group('hovering People in the rail', () {
    testWidgets('does not reload the profile when people are loaded', (
      tester,
    ) async {
      final loads = await _hoverPeopleAndCountLoads(
        tester,
        const UserProfileState(
          teamMembers: [_ada],
          error: 'Could not load billing info.',
        ),
      );

      expect(loads, 0);
      expect(find.text('Ada Lovelace'), findsOneWidget);
    });

    testWidgets('reloads once when there are no people and an error', (
      tester,
    ) async {
      final loads = await _hoverPeopleAndCountLoads(
        tester,
        const UserProfileState(error: 'Could not load team members.'),
      );

      expect(loads, 1);
    });

    testWidgets('does not reload when there is no error', (tester) async {
      final loads = await _hoverPeopleAndCountLoads(
        tester,
        const UserProfileState(),
      );

      expect(loads, 0);
    });
  });

  group('People pop-out card', () {
    testWidgets('lists loaded people even when another request failed', (
      tester,
    ) async {
      await _pumpPeopleCard(
        tester,
        const UserProfileState(
          teamMembers: [_ada],
          error: 'Could not load billing info.',
        ),
      );

      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('Could not load billing info.'), findsNothing);
      // No fake presence label next to each person.
      expect(find.text('Active'), findsNothing);
    });

    testWidgets('shows the error when there are no people to list', (
      tester,
    ) async {
      await _pumpPeopleCard(
        tester,
        const UserProfileState(error: 'Could not load billing info.'),
      );

      expect(find.text('Could not load billing info.'), findsOneWidget);
    });

    testWidgets(
      'shows an empty message when there are no people and no error',
      (tester) async {
        await _pumpPeopleCard(tester, const UserProfileState());

        expect(find.text('No people to show'), findsOneWidget);
      },
    );
  });
}
