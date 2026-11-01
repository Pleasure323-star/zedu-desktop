import 'dart:convert';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

abstract interface class UserProfileRemoteDataSource {
  Future<ProfileAccountModel> getAccount();
  Future<ProfileAccountModel> updateAccount(ProfileAccount account);
  Future<void> deleteAccount();
  Future<NotificationPreferencesModel> getNotificationPreferences();
  Future<NotificationPreferencesModel> updateNotificationPreferences(
    NotificationPreferences preferences,
  );
  Future<List<SecuritySessionModel>> getSecuritySessions();
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
  Future<OrganizationProfileModel> getOrganization({String? orgId});
  Future<OrganizationProfileModel> createOrganization({
    required String name,
    required String type,
    required String country,
  });
  Future<OrganizationProfileModel> updateOrganization(
    OrganizationProfile organization, {
    String? orgId,
  });
  Future<void> deleteOrganization({String? orgId});
  Future<List<TeamMemberModel>> getTeamMembers({String? orgId});
  Future<TeamMemberModel> inviteMember({
    required String email,
    required String role,
    required String orgId,
  });
  Future<TeamMemberModel> updateMember(TeamMember member);
  Future<void> removeMember(String memberId);
  Future<List<RolePermissionModel>> getRolesAndPermissions();
  Future<BillingInfoModel> getBillingInfo();
}

class UserProfileRemoteDataSourceImpl implements UserProfileRemoteDataSource {
  const UserProfileRemoteDataSourceImpl({
    required AppConfig config,
    required ApiBaseService apiBaseService,
  }) : _config = config,
       _apiBaseService = apiBaseService;

  final AppConfig _config;
  final ApiBaseService _apiBaseService;

  static const _tag = 'UserProfileRemoteDataSource';

  @override
  Future<ProfileAccountModel> getAccount() async {
    if (_config.usesMockData) return ProfileAccountModel.fromJson(_account);
    final response = await _apiBaseService.get<Map<String, dynamic>>(
      path: '/profile/account',
    );
    return ProfileAccountModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<ProfileAccountModel> updateAccount(ProfileAccount account) async {
    if (_config.usesMockData) {
      AppLogger.d('Using mock data for PATCH /profile', tag: _tag);
      return ProfileAccountModel.fromAccount(account);
    }
    // Same endpoint and multipart fields as Zedu web. Empty values are left
    // out so fields the user didn't change are never overwritten.
    final fields = <String, String>{
      'full_name': account.name,
      'display_name': account.displayName,
      'username': account.username,
      'phone': account.phoneNumber,
      'title': account.title,
      'timezone': account.timezone,
      'name_pronounciation': account.namePronunciation,
    }..removeWhere((_, value) => value.isEmpty);
    await _apiBaseService.patch<Map<String, dynamic>>(
      path: '/profile',
      data: FormData.fromMap(fields),
    );
    return ProfileAccountModel.fromAccount(account);
  }

  @override
  Future<void> deleteAccount() async {
    if (_config.usesMockData) return;
    await _apiBaseService.delete<Map<String, dynamic>>(
      path: '/profile/account',
    );
  }

  @override
  Future<NotificationPreferencesModel> getNotificationPreferences() async {
    if (_config.usesMockData) {
      return NotificationPreferencesModel.fromJson(_notifications);
    }
    final response = await _apiBaseService.get<Map<String, dynamic>>(
      path: '/profile/notifications',
    );
    return NotificationPreferencesModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<NotificationPreferencesModel> updateNotificationPreferences(
    NotificationPreferences preferences,
  ) async {
    if (_config.usesMockData) {
      return NotificationPreferencesModel(
        mode: preferences.mode,
        fromTime: preferences.fromTime,
        toTime: preferences.toTime,
        useDesktopSettings: preferences.useDesktopSettings,
        emailNotifications: preferences.emailNotifications,
      );
    }
    final response = await _apiBaseService.patch<Map<String, dynamic>>(
      path: '/profile/notifications',
      data: NotificationPreferencesModel(
        mode: preferences.mode,
        fromTime: preferences.fromTime,
        toTime: preferences.toTime,
        useDesktopSettings: preferences.useDesktopSettings,
        emailNotifications: preferences.emailNotifications,
      ).toJson(),
    );
    return NotificationPreferencesModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<List<SecuritySessionModel>> getSecuritySessions() async {
    if (_config.usesMockData) {
      return _sessions.map(SecuritySessionModel.fromJson).toList();
    }
    final response = await _apiBaseService.get<Map<String, dynamic>>(
      path: '/profile/security/sessions',
    );
    final data = response.data['data'] as List<dynamic>;
    return data
        .cast<Map<String, dynamic>>()
        .map(SecuritySessionModel.fromJson)
        .toList();
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_config.usesMockData) {
      AppLogger.d('Using mock data for PUT /auth/change-password', tag: _tag);
      return;
    }
    await _apiBaseService.put<dynamic>(
      path: '/auth/change-password',
      data: {'old_password': currentPassword, 'new_password': newPassword},
    );
  }

  @override
  Future<OrganizationProfileModel> getOrganization({String? orgId}) async {
    if (_config.usesMockData) {
      return OrganizationProfileModel.fromJson(_organization);
    }
    // The selected workspace's own endpoint returns its real name, type and
    // country; /profile/organization fails for members of other workspaces.
    final response = await _apiBaseService.get<Map<String, dynamic>>(
      path: orgId == null ? '/profile/organization' : '/organisations/$orgId',
    );
    return OrganizationProfileModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<OrganizationProfileModel> updateOrganization(
    OrganizationProfile organization, {
    String? orgId,
  }) async {
    if (_config.usesMockData) {
      return OrganizationProfileModel(
        id: organization.id,
        name: organization.name,
        natureOfBusiness: organization.natureOfBusiness,
        country: organization.country,
      );
    }
    final data = OrganizationProfileModel(
      id: organization.id,
      name: organization.name,
      natureOfBusiness: organization.natureOfBusiness,
      country: organization.country,
    ).toJson();
    // Like the load and the delete, save to the selected workspace's own
    // endpoint: /profile/organization is rejected for members of other
    // workspaces. That endpoint reads the business type from `type` (it
    // ignores `nature_of_business`), so send it under that name.
    final response = orgId == null
        ? await _apiBaseService.patch<Map<String, dynamic>>(
            path: '/profile/organization',
            data: data,
          )
        : await _apiBaseService.put<Map<String, dynamic>>(
            path: '/organisations/$orgId',
            data: {
              'id': organization.id,
              'name': organization.name,
              'type': organization.natureOfBusiness,
              'country': organization.country,
            },
          );
    return OrganizationProfileModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<OrganizationProfileModel> createOrganization({
    required String name,
    required String type,
    required String country,
  }) async {
    if (_config.usesMockData) {
      return OrganizationProfileModel(
        id: '019700db-4e22-7f90-a20e-f9116291ef24',
        name: name,
        natureOfBusiness: type,
        country: country,
      );
    }
    try {
      final response = await _apiBaseService.post<Map<String, dynamic>>(
        path: '/organisations',
        data: {'name': name, 'type': type, 'country': country},
      );
      // Small delay to ensure the event loop has processed the request
      await Future<void>.delayed(const Duration(milliseconds: 100));
      return OrganizationProfileModel.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    } catch (e) {
      if (e is DioException) {
        throw ApiFailure.fromDioException(e);
      }
      throw ApiFailure.unknown(e);
    }
  }

  @override
  Future<void> deleteOrganization({String? orgId}) async {
    if (_config.usesMockData) return;
    // Delete the workspace that is shown, not whichever organisation the
    // profile endpoint resolves to.
    await _apiBaseService.delete<Map<String, dynamic>>(
      path: orgId == null ? '/profile/organization' : '/organisations/$orgId',
    );
  }

  @override
  @override
  Future<List<TeamMemberModel>> getTeamMembers({String? orgId}) async {
    if (_config.usesMockData) {
      List<TeamMemberModel> loadedTeamMembers = [];

      // Load persisted mock members if they exist
      if (orgId != null) {
        final storage = locator<SecureStorageService>();
        final data = await storage.readData('mock_team_members_$orgId');
        if (data != null) {
          try {
            final List<dynamic> decoded = jsonDecode(data) as List<dynamic>;
            loadedTeamMembers = decoded
                .map((e) => TeamMemberModel.fromJson(e as Map<String, dynamic>))
                .toList();
          } catch (_) {}
        }
      }

      if (loadedTeamMembers.isNotEmpty) {
        return loadedTeamMembers;
      }

      final list = _members.map(TeamMemberModel.fromJson).toList();
      // Dynamically generate 1000+ mock members to demonstrate efficient search and scroll!
      if (list.length < 100) {
        final roles = ['User', 'Guess', 'Manager', 'Project Lead'];
        for (int i = 1; i <= 1000; i++) {
          list.add(
            TeamMemberModel(
              id: 'member-mock-$i',
              email: 'teammate$i@zedu.app',
              role: roles[i % roles.length],
              dateJoined: 'May ${i % 20 + 1}, 2026',
              status: TeamMemberStatus.active,
              name: 'Teammate $i',
              avatarUrl: null,
            ),
          );
        }
      }
      return list;
    }

    if (orgId == null || orgId.length < 36) {
      orgId = '019700db-4e22-7f90-a20e-f9116291ef24';
    }

    try {
      final response = await _apiBaseService.get<Map<String, dynamic>>(
        path: '/organisations/$orgId/users',
      );
      final data = response.data['data'] as List<dynamic>?;
      if (data == null) return [];

      return data.cast<Map<String, dynamic>>().map((user) {
        // Map backend user to TeamMemberModel
        return TeamMemberModel(
          id: user['id'] as String? ?? '',
          email: user['email'] as String? ?? '',
          role: user['role'] as String? ?? 'User',
          dateJoined: user['created_at'] as String? ?? '',
          status: TeamMemberStatus.active, // Or parse from user['status']
          name:
              user['name'] as String? ??
              user['username'] as String? ??
              'Unknown',
          avatarUrl: user['avatar_url'] as String?,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<TeamMemberModel> inviteMember({
    required String email,
    required String role,
    required String orgId,
  }) async {
    if (_config.usesMockData) {
      return TeamMemberModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        email: email,
        role: role,
        dateJoined: 'Pending',
        status: TeamMemberStatus.pending,
        name: email.split('@').first,
      );
    }
    final response = await _apiBaseService.post<Map<String, dynamic>>(
      path: '/invite',
      data: {
        'org_id': orgId,
        'emails': [email],
        'role_id': role,
      },
    );
    final data = response.data['data'] as Map<String, dynamic>;
    final invites = data['invitations'] as List<dynamic>? ?? [];
    if (invites.isNotEmpty) {
      final invite = invites.first as Map<String, dynamic>;
      return TeamMemberModel(
        id:
            invite['id'] as String? ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        email: invite['email'] as String? ?? email,
        role: role,
        dateJoined: invite['sent_at'] as String? ?? 'Pending',
        status: TeamMemberStatus.pending,
        name: email.split('@').first,
      );
    }
    return TeamMemberModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      email: email,
      role: role,
      dateJoined: 'Pending',
      status: TeamMemberStatus.pending,
      name: email.split('@').first,
    );
  }

  @override
  Future<TeamMemberModel> updateMember(TeamMember member) async {
    if (_config.usesMockData) {
      return TeamMemberModel(
        id: member.id,
        email: member.email,
        role: member.role,
        dateJoined: member.dateJoined,
        status: member.status,
        name: member.name,
        avatarUrl: member.avatarUrl,
      );
    }
    final response = await _apiBaseService.patch<Map<String, dynamic>>(
      path: '/profile/organization/members/${member.id}',
      data: {'email': member.email, 'role': member.role},
    );
    return TeamMemberModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<void> removeMember(String memberId) async {
    if (_config.usesMockData) return;
    await _apiBaseService.delete<Map<String, dynamic>>(
      path: '/profile/organization/members/$memberId',
    );
  }

  @override
  Future<List<RolePermissionModel>> getRolesAndPermissions() async {
    if (_config.usesMockData) {
      return _roles.map(RolePermissionModel.fromJson).toList();
    }
    final response = await _apiBaseService.get<Map<String, dynamic>>(
      path: '/profile/organization/roles',
    );
    final data = response.data['data'] as List<dynamic>;
    return data
        .cast<Map<String, dynamic>>()
        .map(RolePermissionModel.fromJson)
        .toList();
  }

  @override
  Future<BillingInfoModel> getBillingInfo() async {
    if (_config.usesMockData) {
      return BillingInfoModel.fromJson(_billing);
    }
    final response = await _apiBaseService.get<Map<String, dynamic>>(
      path: '/profile/organization/billing',
    );
    return BillingInfoModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }
}

const _account = {
  'name': 'Anonymous user',
  'email': 'anonymoususer@email.com',
  'timezone': 'Africa/Lagos',
};

const _notifications = {
  'mode': 'allMessages',
  'from_time': '12:00 AM',
  'to_time': '11:00 PM',
  'use_desktop_settings': true,
  'email_notifications': false,
};

const _organization = {
  'name': 'Anonymous user',
  'nature_of_business': 'Design agency',
  'country': 'Nigeria',
};

const _sessions = [
  {
    'device': 'Chrome',
    'location': 'Lagos',
    'date': 'May 8, 2026 1:07 PM',
    'last_active': 'May 8, 2026 3:07 PM',
    'status': 'Active',
  },
  {
    'device': 'Chrome',
    'location': 'Abuja',
    'date': 'May 8, 2026 1:07 PM',
    'last_active': 'May 8, 2026 3:07 PM',
    'status': 'Active',
  },
  {
    'device': 'Chrome',
    'location': 'Uyo',
    'date': 'May 8, 2026 1:07 PM',
    'last_active': 'May 8, 2026 3:07 PM',
    'status': 'Active',
  },
];

const _members = [
  {
    'id': 'member-1',
    'email': 'anonymoususer@gmail.com',
    'role': 'Administrator',
    'date_joined': 'May 3, 2026',
    'status': 'active',
    'name': 'Anonymoususer',
  },
  {
    'id': 'member-2',
    'email': 'ruby@zedu.app',
    'role': 'User',
    'date_joined': 'May 4, 2026',
    'status': 'active',
    'name': 'Ruby - Social Media Handler',
  },
  {
    'id': 'member-3',
    'email': 'alice@zedu.app',
    'role': 'User',
    'date_joined': 'May 5, 2026',
    'status': 'active',
    'name': 'Alice - Product Designer',
  },
  {
    'id': 'member-4',
    'email': 'bob@zedu.app',
    'role': 'User',
    'date_joined': 'May 6, 2026',
    'status': 'active',
    'name': 'Bob - Software Engineer',
  },
  {
    'id': 'member-5',
    'email': 'charlie@zedu.app',
    'role': 'Manager',
    'date_joined': 'May 7, 2026',
    'status': 'active',
    'name': 'Charlie - Product Lead',
  },
];

const _roles = [
  {
    'role': 'Administrator',
    'description': 'Full access, control',
    'permissions': [
      'Remove members from organization',
      'Invite members',
      'Create custom roles',
      'Create channels',
      'Comment on threads',
      'View billing',
      'Create webhooks',
      'View channels',
      'Change user organization role',
    ],
  },
  {
    'role': 'Guess',
    'description': 'Read-only access',
    'permissions': ['View channels'],
  },
  {
    'role': 'User',
    'description': 'Read, write, update',
    'permissions': [
      'Remove members from organization',
      'Comment on threads',
      'Create channels',
      'View channels',
    ],
  },
  {
    'role': 'Manager',
    'description': 'Read, write, approve',
    'permissions': [
      'Remove members from organization',
      'Invite members',
      'Create custom roles',
      'Create channels',
      'Comment on threads',
      'View billing',
      'Create webhooks',
      'View channels',
      'Change user organization role',
    ],
  },
  {
    'role': 'Project Lead',
    'description': 'Manage, coordinate, oversee',
    'permissions': [
      'Remove members from organization',
      'Invite members',
      'Create custom roles',
      'Create channels',
      'Comment on threads',
      'View billing',
      'Create webhooks',
      'View channels',
      'Change user organization role',
    ],
  },
];

const _billing = {
  'plan': 'Zedu Free',
  'description':
      'You are enjoying the full Zedu experience with ability to add as many users to your organisation.',
  'payment_history': <Map<String, dynamic>>[],
};
