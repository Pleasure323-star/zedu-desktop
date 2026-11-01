import '../../../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockApiBaseService extends Mock implements ApiBaseService {}

const _demoNames = [
  'HNG Workspace',
  'TeamFlow Collective',
  'Coffee & Code House',
  'ConnectHub',
];

void main() {
  group('WorkspaceNotifier', () {
    late MockApiBaseService mockApi;

    void registerConfig({required bool usesMockData}) {
      locator.registerSingleton<AppConfig>(
        AppConfig(
          apiBaseUrl: 'https://api.example.com',
          usesMockData: usesMockData,
        ),
      );
    }

    void stubOrganisations(List<Map<String, dynamic>> orgs) {
      when(
        () => mockApi.get<Map<String, dynamic>>(path: '/users/organisations'),
      ).thenAnswer(
        (_) async => ApiResponseModel(data: {'data': orgs}, statusCode: 200),
      );
    }

    Future<WorkspaceState> loadWorkspaces(ProviderContainer container) async {
      container.read(workspaceProvider);
      await container.read(workspaceProvider.notifier).fetchWorkspaces();
      return container.read(workspaceProvider);
    }

    setUp(() {
      mockApi = MockApiBaseService();
      locator.registerSingleton<ApiBaseService>(mockApi);
    });

    tearDown(() async {
      await locator.reset();
    });

    test('starts with no organisations instead of demo data', () async {
      registerConfig(usesMockData: false);
      stubOrganisations([]);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(workspaceProvider);

      expect(state.workspaces, isEmpty);
      expect(state.selectedWorkspace, isNull);
      // Let the background fetch started by build() finish before teardown.
      await pumpEventQueue();
    });

    test('shows no organisations when the user belongs to none', () async {
      registerConfig(usesMockData: false);
      stubOrganisations([]);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = await loadWorkspaces(container);

      expect(state.workspaces, isEmpty);
      expect(state.selectedWorkspace, isNull);
      expect(state.errorMessage, isNull);
    });

    test('shows exactly the organisations returned by the server', () async {
      registerConfig(usesMockData: false);
      stubOrganisations([
        {'id': 'org-1', 'name': 'Riverside Academy', 'logo_url': ''},
        {'id': 'org-2', 'name': 'Cohort 13', 'logo_url': ''},
      ]);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = await loadWorkspaces(container);

      expect(state.workspaces.map((w) => w.name), [
        'Riverside Academy',
        'Cohort 13',
      ]);
      expect(state.selectedWorkspace?.id, 'org-1');
      expect(state.workspaces.every((w) => w.unreadCount == 0), isTrue);
    });

    test('a newly created organisation is the only one listed', () async {
      registerConfig(usesMockData: false);
      stubOrganisations([]);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await loadWorkspaces(container);

      container
          .read(workspaceProvider.notifier)
          .addWorkspace(
            const Workspace(
              id: 'org-new',
              name: 'Riverside Academy',
              avatar: '',
            ),
          );

      final state = container.read(workspaceProvider);
      expect(state.workspaces.map((w) => w.name), ['Riverside Academy']);
      expect(state.selectedWorkspace?.id, 'org-new');
    });

    test('sets an error and no demo data when loading fails', () async {
      registerConfig(usesMockData: false);
      when(
        () => mockApi.get<Map<String, dynamic>>(path: '/users/organisations'),
      ).thenThrow(Exception('network down'));
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = await loadWorkspaces(container);

      expect(state.workspaces, isEmpty);
      expect(state.selectedWorkspace, isNull);
      expect(state.errorMessage, WorkspaceNotifier.loadErrorMessage);
    });

    test('a successful retry clears the error', () async {
      registerConfig(usesMockData: false);
      when(
        () => mockApi.get<Map<String, dynamic>>(path: '/users/organisations'),
      ).thenThrow(Exception('network down'));
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await loadWorkspaces(container);

      stubOrganisations([
        {'id': 'org-1', 'name': 'Riverside Academy', 'logo_url': ''},
      ]);
      await container.read(workspaceProvider.notifier).fetchWorkspaces();

      final state = container.read(workspaceProvider);
      expect(state.errorMessage, isNull);
      expect(state.workspaces.map((w) => w.name), ['Riverside Academy']);
    });

    test('keeps the demo organisations in mock-data mode', () async {
      registerConfig(usesMockData: true);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = await loadWorkspaces(container);

      expect(state.workspaces.map((w) => w.name), _demoNames);
      verifyNever(
        () => mockApi.get<Map<String, dynamic>>(path: any(named: 'path')),
      );
    });
  });
}
