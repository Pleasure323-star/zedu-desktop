import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

const _feedback = 'Could not open this file. Please try again.';
const _link = 'https://files.zedu.test/report.pdf';
const _launcherChannel = MethodChannel('plugins.flutter.io/url_launcher');

class _Profile extends UserProfileNotifier {
  @override
  UserProfileState build() => const UserProfileState();
}

class _Repository implements FilesRepository {
  _Repository(this.link);

  final String link;

  @override
  Future<Result<FilesPage>> fetchFiles(FilesQuery query) async => Success(
    FilesPage(
      files: [WorkspaceFile(id: 'file-1', name: 'report.pdf', link: link)],
    ),
  );

  @override
  Future<Result<FoldersPage>> fetchFolders({
    required FilesScope view,
    String? parentId,
    int page = 1,
  }) async => const Success(FoldersPage(folders: []));

  @override
  Future<Result<void>> createFolder({
    required String name,
    required String orgId,
    String? parentId,
  }) async => const Success(null);

  @override
  Future<Result<WorkspaceFile>> uploadFile(XFile file) async =>
      Success(WorkspaceFile(id: 'file-2', name: 'upload.pdf', link: link));
}

class _Launcher {
  bool supported = true;
  bool launched = true;
  String? throwOn;
  Completer<bool>? pendingLaunch;
  final calls = <String>[];

  Future<Object?> handle(MethodCall call) async {
    calls.add(call.method);
    if (call.method == throwOn) {
      throw PlatformException(
        code: 'launch_error',
        message: 'Private path C:/Users/example/private/report.pdf',
      );
    }
    if (call.method == 'canLaunch') return supported;
    if (call.method == 'launch') return pendingLaunch?.future ?? launched;
    throw StateError('Unexpected launcher method: ${call.method}');
  }
}

Future<void> _pump(
  WidgetTester tester,
  _Launcher launcher, {
  String link = _link,
}) async {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    _launcherChannel,
    launcher.handle,
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _launcherChannel,
      null,
    ),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentOrgIdProvider.overrideWithValue('org-1'),
        userProfileNotifierProvider.overrideWith(_Profile.new),
        filesRepositoryProvider.overrideWithValue(_Repository(link)),
      ],
      child: buildTestMaterialApp(const Scaffold(body: FilesView())),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Files').last);
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('report.pdf'));
  await tester.pumpAndSettle();
}

void main() {
  for (final link in ['', 'relative/report.pdf', 'http://[invalid']) {
    testWidgets('invalid link "$link" reports failure without launching', (
      tester,
    ) async {
      final launcher = _Launcher();
      await _pump(tester, launcher, link: link);
      await _open(tester);

      expect(find.text(_feedback), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(launcher.calls, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('unsupported link reports failure and can retry successfully', (
    tester,
  ) async {
    final launcher = _Launcher()..supported = false;
    await _pump(tester, launcher);
    await _open(tester);

    expect(find.text(_feedback), findsOneWidget);
    expect(launcher.calls, ['canLaunch']);
    launcher.supported = true;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(launcher.calls, ['canLaunch', 'canLaunch', 'launch']);
    expect(find.text(_feedback), findsNothing);
    expect(find.text('report.pdf'), findsOneWidget);
  });

  testWidgets('a false launch result reports failure', (tester) async {
    final launcher = _Launcher()..launched = false;
    await _pump(tester, launcher);
    await _open(tester);

    expect(launcher.calls, ['canLaunch', 'launch']);
    expect(find.text(_feedback), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final method in ['canLaunch', 'launch']) {
    testWidgets(
      '$method exception gives safe feedback and leaves page usable',
      (tester) async {
        final launcher = _Launcher()..throwOn = method;
        await _pump(tester, launcher);
        await _open(tester);

        expect(find.text(_feedback), findsOneWidget);
        expect(find.textContaining('Private path'), findsNothing);
        expect(find.textContaining('launch_error'), findsNothing);
        expect(tester.takeException(), isNull);
        launcher.throwOn = null;
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        expect(find.text(_feedback), findsNothing);
        expect(launcher.calls.last, 'launch');
      },
    );
  }

  testWidgets('successful opening does not display an error', (tester) async {
    final launcher = _Launcher();
    await _pump(tester, launcher);
    await _open(tester);

    expect(launcher.calls, ['canLaunch', 'launch']);
    expect(find.text(_feedback), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a failed launch after leaving Files does not use disposed context',
    (tester) async {
      final pending = Completer<bool>();
      final launcher = _Launcher()..pendingLaunch = pending;
      await _pump(tester, launcher);
      await tester.tap(find.text('report.pdf'));
      await tester.pump();
      expect(launcher.calls, ['canLaunch', 'launch']);

      await tester.pumpWidget(buildTestMaterialApp(const Scaffold()));
      pending.complete(false);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(_feedback), findsNothing);
    },
  );
}
