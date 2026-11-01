import 'package:zedu/features/features.dart';

/// Current user as returned by `GET /profile`.
///
/// The profile payload differs from the login `user` object: it has no
/// organisation block and uses ISO-8601 dates, so it is parsed separately
/// and mapped onto the same [User] entity.
class ProfileModel {
  const ProfileModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.username,
    required this.avatarUrl,
    required this.defaultAvatarUrl,
    required this.createdAt,
    required this.isActive,
    this.isVerified = true,
    this.isOnboarded = true,
    this.currentOrg = '',
    this.currentOrganisationSlug = '',
  });

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String username;
  final String avatarUrl;
  final String defaultAvatarUrl;
  final DateTime createdAt;
  final bool isActive;
  final bool isVerified;
  final bool isOnboarded;
  final String currentOrg;
  final String currentOrganisationSlug;

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      // `id` is the profile row; `userId` is the user the session belongs to.
      id:
          json['userId'] as String? ??
          json['user_id'] as String? ??
          json['id'] as String,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      email: json['email'] as String,
      phone: json['phone'] as String? ?? '',
      username: json['username'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String? ?? '',
      defaultAvatarUrl: json['default_avatar_url'] as String? ?? '',
      createdAt: _parseDate(json['created_at']),
      isActive: json['is_active'] as bool? ?? true,
      isVerified: json['is_verified'] as bool? ?? true,
      isOnboarded: json['is_onboarded'] as bool? ?? true,
      currentOrg:
          json['organisation_id'] as String? ??
          json['current_org'] as String? ??
          '',
      currentOrganisationSlug:
          json['current_organisation_slug'] as String? ?? '',
    );
  }

  User toEntity() => User(
    id: id,
    firstName: firstName,
    lastName: lastName,
    email: email,
    phone: phone,
    username: username,
    isVerified: isVerified,
    isOnboarded: isOnboarded,
    createdAt: createdAt,
    currentOrg: currentOrg,
    currentOrganisationSlug: currentOrganisationSlug,
    avatarUrl: avatarUrl,
    defaultAvatarUrl: defaultAvatarUrl,
  );

  /// Accepts ISO-8601 strings and epoch-seconds strings.
  static DateTime _parseDate(Object? raw) {
    if (raw is String) {
      final iso = DateTime.tryParse(raw);
      if (iso != null) return iso;
      final seconds = int.tryParse(raw);
      if (seconds != null) {
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      }
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
