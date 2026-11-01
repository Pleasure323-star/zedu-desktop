import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class UserProfileRepositoryImpl implements UserProfileRepository {
  const UserProfileRepositoryImpl({required UserProfileRemoteDataSource remote})
    : _remote = remote;

  final UserProfileRemoteDataSource _remote;

  static const _tag = 'UserProfileRepository';

  @override
  Future<Result<ProfileAccount>> getAccount() => _guard(_remote.getAccount);

  @override
  Future<Result<ProfileAccount>> updateAccount(ProfileAccount account) {
    return _guard(() => _remote.updateAccount(account));
  }

  @override
  Future<Result<void>> deleteAccount() => _guard(_remote.deleteAccount);

  @override
  Future<Result<NotificationPreferences>> getNotificationPreferences() {
    return _guard(_remote.getNotificationPreferences);
  }

  @override
  Future<Result<NotificationPreferences>> updateNotificationPreferences(
    NotificationPreferences preferences,
  ) {
    return _guard(() => _remote.updateNotificationPreferences(preferences));
  }

  @override
  Future<Result<List<SecuritySession>>> getSecuritySessions() {
    return _guard(_remote.getSecuritySessions);
  }

  @override
  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return _guard(
      () => _remote.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      ),
    );
  }

  @override
  Future<Result<OrganizationProfile>> getOrganization({String? orgId}) {
    return _guard(() => _remote.getOrganization(orgId: orgId));
  }

  @override
  Future<Result<OrganizationProfile>> createOrganization({
    required String name,
    required String type,
    required String country,
  }) {
    return _guard(
      () =>
          _remote.createOrganization(name: name, type: type, country: country),
    );
  }

  @override
  Future<Result<OrganizationProfile>> updateOrganization(
    OrganizationProfile organization, {
    String? orgId,
  }) {
    return _guard(() => _remote.updateOrganization(organization, orgId: orgId));
  }

  @override
  Future<Result<void>> deleteOrganization({String? orgId}) {
    return _guard(() => _remote.deleteOrganization(orgId: orgId));
  }

  @override
  Future<Result<List<TeamMember>>> getTeamMembers({String? orgId}) {
    return _guard(() => _remote.getTeamMembers(orgId: orgId));
  }

  @override
  Future<Result<TeamMember>> inviteMember({
    required String email,
    required String role,
    required String orgId,
  }) {
    return _guard(
      () => _remote.inviteMember(email: email, role: role, orgId: orgId),
    );
  }

  @override
  Future<Result<TeamMember>> updateMember(TeamMember member) {
    return _guard(() => _remote.updateMember(member));
  }

  @override
  Future<Result<void>> removeMember(String memberId) {
    return _guard(() => _remote.removeMember(memberId));
  }

  @override
  Future<Result<List<RolePermission>>> getRolesAndPermissions() {
    return _guard(_remote.getRolesAndPermissions);
  }

  @override
  Future<Result<BillingInfo>> getBillingInfo() {
    return _guard(_remote.getBillingInfo);
  }

  Future<Result<T>> _guard<T>(Future<T> Function() operation) async {
    try {
      return Success(await operation());
    } on ApiFailure catch (failure) {
      AppLogger.w('Profile request failed - ${failure.message}', tag: _tag);
      return Failure(failure);
    } catch (error) {
      AppLogger.e('Unexpected profile error', tag: _tag, error: error);
      return Failure(ApiFailure.unknown(error));
    }
  }
}
