import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class _FakeProfile extends UserProfileNotifier {
  _FakeProfile(this.account);
  final ProfileAccount account;

  @override
  UserProfileState build() => UserProfileState(account: account);
}

User _user({bool online = true}) => User(
  id: 'me',
  firstName: 'Anidu',
  lastName: 'Hassanat',
  email: 'hassanat@example.com',
  phone: '',
  username: 'hassanat',
  isVerified: true,
  isOnboarded: true,
  createdAt: DateTime(2026, 10, 17),
  currentOrg: 'org-1',
  currentOrganisationSlug: 'org-1',
  avatarUrl: '',
  defaultAvatarUrl: '',
  status: UserStatus(online: online),
);

/// Signed in; toggling away/active works unless [fails] (a server error).
class _FakeAuth extends AuthNotifier {
  _FakeAuth({this.fails = false});
  final bool fails;

  @override
  AuthState build() =>
      AuthState(status: AuthStatus.authenticated, user: _user());

  @override
  Future<void> toggleOnlineStatus() async {
    if (fails) return;
    final online = !state.user!.status.online;
    state = AuthState(
      status: AuthStatus.authenticated,
      user: _user(online: online),
    );
  }
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  String username = 'hassanat',
  bool statusFails = false,
}) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      userProfileNotifierProvider.overrideWith(
        () => _FakeProfile(
          ProfileAccount(
            name: 'Anidu Hassanat',
            email: 'hassanat@example.com',
            timezone: 'Africa/Lagos',
            username: username,
          ),
        ),
      ),
      authNotifierProvider.overrideWith(() => _FakeAuth(fails: statusFails)),
    ],
  );
  addTearDown(container.dispose);
  container.read(personalProfilePanelProvider.notifier).state = true;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        // The ink-sparkle shader isn't available under flutter_test.
        theme: AppTheme.light.copyWith(splashFactory: NoSplash.splashFactory),
        home: const Scaffold(body: PersonalProfilePanel()),
      ),
    ),
  );
  return container;
}

/// Taps [finder] and checks the toast, then lets the toast time out.
Future<void> _tapAndExpectToast(
  WidgetTester t,
  Finder finder,
  String toast,
) async {
  await t.tap(finder);
  await t.pump();
  expect(find.text(toast), findsOneWidget);
  await t.pump(const Duration(seconds: 5));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('shows Mute, Hide, View Files and Copy, but no Favourite', (
    t,
  ) async {
    await _pump(t);
    for (final label in ['Mute', 'Hide', 'View Files']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byTooltip('Copy your username'), findsOneWidget);
    expect(find.byIcon(Icons.star_outline), findsNothing);
  });

  testWidgets('Mute pauses notifications for an hour; Unmute resumes them', (
    t,
  ) async {
    final c = await _pump(t);
    await _tapAndExpectToast(
      t,
      find.text('Mute'),
      'Notifications paused for 1 hour',
    );
    final left = c
        .read(notificationSettingsProvider)
        .dndUntil!
        .difference(DateTime.now());
    expect(left.inSeconds, closeTo(3600, 10)); // paused for one hour
    expect(find.text('Active, Notifications paused'), findsOneWidget);

    await _tapAndExpectToast(t, find.text('Unmute'), 'Notifications resumed');
    expect(c.read(notificationSettingsProvider).isDndActive, isFalse);

    // A pause that runs out ends by itself, and the panel shows Mute again.
    await _tapAndExpectToast(
      t,
      find.text('Mute'),
      'Notifications paused for 1 hour',
    );
    await t.pump(const Duration(hours: 1));
    expect(find.text('Mute'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
  });

  testWidgets('Hide sets you as away; Show sets you active', (t) async {
    await _pump(t);
    await _tapAndExpectToast(t, find.text('Hide'), 'You are now away');
    expect(find.text('Away'), findsOneWidget);

    await _tapAndExpectToast(t, find.text('Show'), 'You are now active');
    expect(find.text('Active'), findsOneWidget);
  });

  testWidgets('Hide says so when the status change fails', (t) async {
    await _pump(t, statusFails: true);
    await _tapAndExpectToast(
      t,
      find.text('Hide'),
      "Couldn't change your status. Please try again.",
    );
    expect(find.text('Active'), findsOneWidget);
  });

  testWidgets('View Files opens the Files tab and closes the panel', (t) async {
    final c = await _pump(t);
    await t.tap(find.text('View Files'));
    await t.pump();
    expect(c.read(homeSidebarProvider), HomeSidebarType.files);
    expect(c.read(personalProfilePanelProvider), isFalse);
  });

  testWidgets('Copy copies the @username, or the email without one', (t) async {
    String? copied;
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await _pump(t);
    await _tapAndExpectToast(
      t,
      find.byTooltip('Copy your username'),
      'Copied @hassanat',
    );
    expect(copied, '@hassanat');

    await _pump(t, username: '');
    await _tapAndExpectToast(
      t,
      find.byTooltip('Copy your email'),
      'Copied hassanat@example.com',
    );
    expect(copied, 'hassanat@example.com');
  });
}
