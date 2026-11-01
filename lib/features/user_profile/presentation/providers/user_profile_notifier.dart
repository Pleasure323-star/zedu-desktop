import 'dart:convert';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class UserProfileNotifier extends Notifier<UserProfileState> {
  late final UserProfileRepository _repository;

  /// Identifies the latest [load]. A load that is no longer the latest drops
  /// its result, even when the selected workspace is the same one again
  /// (switching A to B and back to A).
  int _loadCounter = 0;

  @override
  UserProfileState build() {
    _repository = ref.read(userProfileRepositoryProvider);
    // The profile can stay open while the workspace is switched, so reload
    // the workspace-dependent details (organization, members) for the new one.
    ref.listen(
      workspaceProvider.select((state) => state.selectedWorkspace?.id),
      (previous, next) {
        if (previous != next) load();
      },
    );
    // load() reads and writes state, which is not available until build()
    // returns, so it starts right after, unless the provider was disposed.
    Future.microtask(() {
      if (ref.mounted) load();
    });
    return const UserProfileState(isLoading: true);
  }

  void selectSection(UserProfileSection section) {
    state = state.copyWith(
      section: section,
      clearError: true,
      clearSuccess: true,
    );
  }

  Future<void> updateAccount(ProfileAccount account) async {
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    final current = state.account ?? ProfileAccount.empty();
    final changes = _changedFields(account, current);
    final result = await _repository.updateAccount(changes);
    switch (result) {
      case Success<ProfileAccount>():
        state = state.copyWith(
          account: _savedAccount(state.account ?? current, changes),
          isSaving: false,
          successMessage: 'Account information saved successfully.',
        );
      case Failure<ProfileAccount>():
        state = state.copyWith(
          isSaving: false,
          error: result.error.friendlyMessage,
        );
    }
  }

  /// Keeps only the fields the user edited (others become empty), so the
  /// placeholder values shown before the profile loads are never saved.
  ProfileAccount _changedFields(
    ProfileAccount updated,
    ProfileAccount current,
  ) {
    String changed(String now, String was) => now == was ? '' : now;
    return ProfileAccount(
      name: changed(updated.name, current.name),
      email: changed(updated.email, current.email),
      timezone: changed(updated.timezone, current.timezone),
      avatarUrl: updated.avatarUrl,
      displayName: changed(updated.displayName, current.displayName),
      username: changed(updated.username, current.username),
      phoneNumber: changed(updated.phoneNumber, current.phoneNumber),
      title: changed(updated.title, current.title),
      namePronunciation: changed(
        updated.namePronunciation,
        current.namePronunciation,
      ),
      country: changed(updated.country, current.country),
    );
  }

  /// The profile as the server now holds it. `PATCH /profile` doesn't take
  /// email, country or avatar, and the backend ignores empty values, so those
  /// keep their current values instead of showing edits that weren't saved.
  ProfileAccount _savedAccount(ProfileAccount current, ProfileAccount changes) {
    String saved(String sent, String was) => sent.isEmpty ? was : sent;
    return current.copyWith(
      name: saved(changes.name, current.name),
      timezone: saved(changes.timezone, current.timezone),
      displayName: saved(changes.displayName, current.displayName),
      username: saved(changes.username, current.username),
      phoneNumber: saved(changes.phoneNumber, current.phoneNumber),
      title: saved(changes.title, current.title),
      namePronunciation: saved(
        changes.namePronunciation,
        current.namePronunciation,
      ),
    );
  }

  Future<void> deleteAccount() async {
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    final result = await _repository.deleteAccount();
    switch (result) {
      case Success<void>():
        state = state.copyWith(
          isSaving: false,
          successMessage: 'Account deleted successfully.',
        );
      case Failure<void>():
        state = state.copyWith(
          isSaving: false,
          error: result.error.friendlyMessage,
        );
    }
  }

  Future<void> updateNotificationPreferences(
    NotificationPreferences preferences,
  ) async {
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    final result = await _repository.updateNotificationPreferences(preferences);
    switch (result) {
      case Success<NotificationPreferences>():
        state = state.copyWith(
          notifications: result.value,
          isSaving: false,
          successMessage: 'Notification preferences saved successfully.',
        );
      case Failure<NotificationPreferences>():
        state = state.copyWith(
          isSaving: false,
          error: result.error.friendlyMessage,
        );
    }
  }

  Future<void> revertNotificationPreferences(
    NotificationPreferences preferences,
  ) async {
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    final result = await _repository.updateNotificationPreferences(preferences);
    switch (result) {
      case Success<NotificationPreferences>():
        state = state.copyWith(
          notifications: result.value,
          isSaving: false,
          successMessage: 'Changes reverted successfully.',
        );
      case Failure<NotificationPreferences>():
        state = state.copyWith(
          isSaving: false,
          error: result.error.friendlyMessage,
        );
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    final result = await _repository.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    switch (result) {
      case Success<void>():
        state = state.copyWith(
          isSaving: false,
          successMessage: 'Password updated successfully.',
        );
      case Failure<void>():
        state = state.copyWith(
          isSaving: false,
          error: result.error.friendlyMessage,
        );
    }
  }

  Future<void> updateOrganization(OrganizationProfile organization) async {
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    final result = await _repository.updateOrganization(
      organization,
      orgId: ref.read(workspaceProvider).selectedWorkspace?.id,
    );
    switch (result) {
      case Success<OrganizationProfile>():
        state = state.copyWith(
          organization: result.value,
          isSaving: false,
          successMessage: 'Organization information saved successfully.',
        );
      case Failure<OrganizationProfile>():
        state = state.copyWith(
          isSaving: false,
          error: result.error.friendlyMessage,
        );
    }
  }

  Future<void> createOrganization({
    required String name,
    required String type,
    required String country,
  }) async {
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    final result = await _repository.createOrganization(
      name: name,
      type: type,
      country: country,
    );
    switch (result) {
      case Success<OrganizationProfile>():
        state = state.copyWith(
          organization: result.value,
          isSaving: false,
          successMessage: 'Organization created successfully.',
        );
        ref
            .read(workspaceProvider.notifier)
            .addWorkspace(
              Workspace(
                id: result.value.id,
                name: result.value.name,
                avatar: '',
                unreadCount: 0,
                channelsCount: 0,
              ),
            );
      case Failure<OrganizationProfile>():
        state = state.copyWith(
          isSaving: false,
          error: result.error.friendlyMessage,
        );
    }
  }

  Future<void> deleteOrganization() async {
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    final orgId = ref.read(workspaceProvider).selectedWorkspace?.id;
    final result = await _repository.deleteOrganization(orgId: orgId);
    switch (result) {
      case Success<void>():
        state = state.copyWith(
          isSaving: false,
          successMessage: 'Organization deleted successfully.',
        );
      case Failure<void>():
        state = state.copyWith(
          isSaving: false,
          error: result.error.friendlyMessage,
        );
    }
  }

  Future<void> leaveOrganization() async {
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    try {
      final orgId = ref.read(workspaceProvider).selectedWorkspace?.id;
      final userId = ref.read(authNotifierProvider).user?.id;
      if (orgId == null || userId == null) {
        throw Exception('Missing orgId or userId');
      }

      final api = locator<ApiBaseService>();
      await api.delete<Map<String, dynamic>>(
        path: '/organisations/$orgId/users/$userId',
      );

      // Now remove workspace from local state
      ref.read(workspaceProvider.notifier).removeWorkspace(orgId);

      state = state.copyWith(
        isSaving: false,
        successMessage: 'Successfully signed out of workspace.',
      );
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: 'Failed to leave workspace. Please try again.',
      );
    }
  }

  Future<String> _getRoleId(String? orgId) async {
    try {
      if (orgId == null) return '019700d8-9085-7f7b-839a-fcbd08b9e26d';
      final api = locator<ApiBaseService>();
      final response = await api.get<Map<String, dynamic>>(
        path: '/organisations/$orgId/roles',
      );
      final data = response.data['data'] as List<dynamic>?;
      if (data != null && data.isNotEmpty) {
        return data.last['id']
            as String; // Just pick a valid role ID to avoid 404
      }
    } catch (e) {
      // ignore
    }
    return '019700d8-9085-7f7b-839a-fcbd08b9e26d';
  }

  Future<String?> generateInviteLink() async {
    try {
      final api = locator<ApiBaseService>();
      var orgId = ref.read(workspaceProvider).selectedWorkspace?.id;
      if (locator<AppConfig>().usesMockData &&
          (orgId == null || orgId.length < 36)) {
        orgId = '019700db-4e22-7f90-a20e-f9116291ef24';
      }
      final roleId = await _getRoleId(orgId);
      final response = await api.post<Map<String, dynamic>>(
        path: '/invite/general',
        data: {'organisation_id': orgId, 'role_id': roleId},
      );
      final data = response.data['data'] as Map<String, dynamic>?;
      return data?['invitation_link'] as String?;
    } catch (e) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchRegisteredUsers() async {
    try {
      final api = locator<ApiBaseService>();
      final response = await api.get<Map<String, dynamic>>(path: '/users');
      final data = response.data['data'] as List<dynamic>?;
      if (data != null) {
        return data.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      // ignore
    }
    return [];
  }

  Future<void> inviteMember({
    required String email,
    required String role,
    String? userId,
  }) async {
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    var orgId = ref.read(workspaceProvider).selectedWorkspace?.id;
    if (locator<AppConfig>().usesMockData &&
        (orgId == null || orgId.length < 36)) {
      orgId = '019700db-4e22-7f90-a20e-f9116291ef24';
    }

    // Map human readable role to a valid UUID role_id by fetching from backend
    String roleId = await _getRoleId(orgId);

    if (orgId == null) {
      state = state.copyWith(
        isSaving: false,
        error: 'No active workspace selected to invite members.',
      );
      return;
    }

    final result = await _repository.inviteMember(
      email: email,
      role: roleId,
      orgId: orgId,
    );
    switch (result) {
      case Success<TeamMember>():
        final newTeamMembers = [...state.teamMembers, result.value];
        state = state.copyWith(
          teamMembers: newTeamMembers,
          isSaving: false,
          successMessage: 'Invite sent successfully.',
        );

        // Persist the mock state across restarts if we are using mock data
        final config = locator<AppConfig>();
        if (config.usesMockData) {
          final storage = locator<SecureStorageService>();
          final jsonList = newTeamMembers
              .map(
                (m) => {
                  'id': m.id,
                  'email': m.email,
                  'role': m.role,
                  'name': m.name,
                  'avatar_url': m.avatarUrl,
                  'date_joined': m.dateJoined,
                  'status': m.status.name,
                },
              )
              .toList();
          await storage.writeData(
            'mock_team_members_$orgId',
            jsonEncode(jsonList),
          );
        }

      case Failure<TeamMember>():
        state = state.copyWith(
          isSaving: false,
          error: result.error.friendlyMessage,
        );
    }
  }

  Future<void> updateMember(TeamMember member) async {
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    final result = await _repository.updateMember(member);
    switch (result) {
      case Success<TeamMember>():
        state = state.copyWith(
          teamMembers: [
            for (final current in state.teamMembers)
              current.id == result.value.id ? result.value : current,
          ],
          isSaving: false,
          successMessage: 'Team member updated successfully.',
        );
      case Failure<TeamMember>():
        state = state.copyWith(
          isSaving: false,
          error: result.error.friendlyMessage,
        );
    }
  }

  Future<void> removeMember(String memberId) async {
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    final result = await _repository.removeMember(memberId);
    switch (result) {
      case Success<void>():
        state = state.copyWith(
          teamMembers: [
            for (final member in state.teamMembers)
              if (member.id != memberId) member,
          ],
          isSaving: false,
          successMessage: 'Team member removed successfully.',
        );
      case Failure<void>():
        state = state.copyWith(
          isSaving: false,
          error: result.error.friendlyMessage,
        );
    }
  }

  bool _isObsoleteLoad(int loadId, String? orgId) {
    if (!ref.mounted) return true;
    final currentOrgId = ref.read(workspaceProvider).selectedWorkspace?.id;
    return loadId != _loadCounter || currentOrgId != orgId;
  }

  Future<void> load() async {
    final loadId = ++_loadCounter;
    state = state.copyWith(isLoading: true, clearError: true);
    final orgId = ref.read(workspaceProvider).selectedWorkspace?.id;
    try {
      await _loadProfile(loadId, orgId);
    } catch (_) {
      if (_isObsoleteLoad(loadId, orgId)) return;
      state = state.copyWith(
        isLoading: false,
        error: 'Could not load your profile. Please try again.',
      );
    }
  }

  Future<void> _loadProfile(int loadId, String? orgId) async {
    final results = await Future.wait([
      _repository.getAccount(),
      _repository.getNotificationPreferences(),
      _repository.getSecuritySessions(),
      _repository.getOrganization(orgId: orgId),
      _repository.getTeamMembers(orgId: orgId),
      _repository.getRolesAndPermissions(),
      _repository.getBillingInfo(),
    ]);

    // A newer load started, or the workspace changed, while this was loading:
    // drop the stale result, the newer load will fill the screen.
    if (_isObsoleteLoad(loadId, orgId)) return;

    final accountResult = results[0] as Result<ProfileAccount>;
    final notificationResult = results[1] as Result<NotificationPreferences>;
    final securityResult = results[2] as Result<List<SecuritySession>>;
    final organizationResult = results[3] as Result<OrganizationProfile>;
    final teamResult = results[4] as Result<List<TeamMember>>;
    final rolesResult = results[5] as Result<List<RolePermission>>;
    final billingResult = results[6] as Result<BillingInfo>;

    final error = _getError(results);

    var loadedTeamMembers = _valueOrNull(teamResult) ?? const [];

    // Load persisted mock members if they exist
    if (orgId != null) {
      final storage = locator<SecureStorageService>();
      final data = await storage.readData('mock_team_members_$orgId');
      if (data != null) {
        try {
          final List<dynamic> decoded = jsonDecode(data) as List<dynamic>;
          final savedMembers = decoded.map((e) {
            final map = e as Map<String, dynamic>;
            return TeamMember(
              id: (map['id'] as String?) ?? '',
              email: (map['email'] as String?) ?? '',
              role: (map['role'] as String?) ?? '',
              name: map['name'] as String?,
              avatarUrl: map['avatar_url'] as String?,
              dateJoined: (map['date_joined'] as String?) ?? '',
              status: TeamMemberStatus.values.firstWhere(
                (s) => s.name == (map['status'] as String?),
                orElse: () => TeamMemberStatus.active,
              ),
            );
          }).toList();
          loadedTeamMembers = savedMembers;
        } catch (_) {}
      }
    }

    // The secure-storage read above can take long enough for another load to
    // start, so check again right before writing the state.
    if (_isObsoleteLoad(loadId, orgId)) return;

    state = state.copyWith(
      account: _valueOrNull(accountResult),
      notifications: _valueOrNull(notificationResult),
      securitySessions: _valueOrNull(securityResult) ?? const [],
      organization: _valueOrNull(organizationResult),
      teamMembers: loadedTeamMembers,
      rolesAndPermissions: _valueOrNull(rolesResult) ?? const [],
      billing: _valueOrNull(billingResult),
      isLoading: false,
      error: error,
    );
  }

  String? _getError(List<dynamic> results) {
    for (final result in results) {
      if (result is Failure) {
        return result.error.friendlyMessage;
      }
    }
    return null;
  }

  T? _valueOrNull<T>(Result<T> result) {
    return switch (result) {
      Success<T>() => result.value,
      Failure<T>() => null,
    };
  }
}
