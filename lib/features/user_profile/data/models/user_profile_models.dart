import 'package:zedu/features/features.dart';

class ProfileAccountModel extends ProfileAccount {
  const ProfileAccountModel({
    required super.name,
    required super.email,
    required super.timezone,
    super.avatarUrl,
    super.displayName,
    super.username,
    super.phoneNumber,
    super.title,
    super.namePronunciation,
    super.country,
  });

  factory ProfileAccountModel.fromAccount(ProfileAccount account) {
    return ProfileAccountModel(
      name: account.name,
      email: account.email,
      timezone: account.timezone,
      avatarUrl: account.avatarUrl,
      displayName: account.displayName,
      username: account.username,
      phoneNumber: account.phoneNumber,
      title: account.title,
      namePronunciation: account.namePronunciation,
      country: account.country,
    );
  }

  factory ProfileAccountModel.fromJson(Map<String, dynamic> json) {
    return ProfileAccountModel(
      name: json['name'] as String? ?? 'Anonymous user',
      email: json['email'] as String? ?? 'anonymoususer@email.com',
      timezone: json['timezone'] as String? ?? 'Africa/Lagos',
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'email': email,
    'timezone': timezone,
    'avatar_url': avatarUrl,
  };
}

class NotificationPreferencesModel extends NotificationPreferences {
  const NotificationPreferencesModel({
    required super.mode,
    required super.fromTime,
    required super.toTime,
    required super.useDesktopSettings,
    required super.emailNotifications,
  });

  factory NotificationPreferencesModel.fromJson(Map<String, dynamic> json) {
    return NotificationPreferencesModel(
      mode: _modeFromJson(json['mode'] as String?),
      fromTime: json['from_time'] as String? ?? '12:00 AM',
      toTime: json['to_time'] as String? ?? '11:00 PM',
      useDesktopSettings: json['use_desktop_settings'] as bool? ?? true,
      emailNotifications: json['email_notifications'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'from_time': fromTime,
    'to_time': toTime,
    'use_desktop_settings': useDesktopSettings,
    'email_notifications': emailNotifications,
  };

  static NotificationMode _modeFromJson(String? value) {
    return switch (value) {
      'mentionsOnly' || 'mentions_only' => NotificationMode.mentionsOnly,
      'none' => NotificationMode.none,
      _ => NotificationMode.allMessages,
    };
  }
}

class OrganizationProfileModel extends OrganizationProfile {
  const OrganizationProfileModel({
    required super.id,
    required super.name,
    required super.natureOfBusiness,
    required super.country,
  });

  factory OrganizationProfileModel.fromJson(Map<String, dynamic> json) {
    return OrganizationProfileModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      natureOfBusiness:
          json['nature_of_business'] as String? ??
          json['type'] as String? ??
          '',
      country: json['country'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'nature_of_business': natureOfBusiness,
    'country': country,
  };
}

class SecuritySessionModel extends SecuritySession {
  const SecuritySessionModel({
    required super.device,
    required super.location,
    required super.date,
    required super.lastActive,
    required super.status,
  });

  factory SecuritySessionModel.fromJson(Map<String, dynamic> json) {
    return SecuritySessionModel(
      device: json['device'] as String? ?? 'Chrome',
      location: json['location'] as String? ?? 'Lagos',
      date: json['date'] as String? ?? 'May 8, 2026 1:07 PM',
      lastActive: json['last_active'] as String? ?? 'May 8, 2026 3:07 PM',
      status: json['status'] as String? ?? 'Active',
    );
  }
}

class TeamMemberModel extends TeamMember {
  const TeamMemberModel({
    required super.id,
    required super.email,
    required super.role,
    required super.dateJoined,
    required super.status,
    super.name,
    super.avatarUrl,
  });

  factory TeamMemberModel.fromJson(Map<String, dynamic> json) {
    return TeamMemberModel(
      id: json['id'] as String? ?? 'member-1',
      email: json['email'] as String? ?? 'anonymoususer@gmail.com',
      role: json['role'] as String? ?? 'Administrator',
      dateJoined: json['date_joined'] as String? ?? 'May 3, 2026',
      status: _statusFromJson(json['status'] as String?),
      name: json['name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  static TeamMemberStatus _statusFromJson(String? value) {
    return switch (value) {
      'pending' => TeamMemberStatus.pending,
      'inactive' => TeamMemberStatus.inactive,
      _ => TeamMemberStatus.active,
    };
  }
}

class RolePermissionModel extends RolePermission {
  const RolePermissionModel({
    required super.role,
    required super.description,
    required super.permissions,
  });

  factory RolePermissionModel.fromJson(Map<String, dynamic> json) {
    return RolePermissionModel(
      role: json['role'] as String? ?? 'User',
      description: json['description'] as String? ?? '',
      permissions:
          (json['permissions'] as List<dynamic>?)?.cast<String>() ?? const [],
    );
  }
}

class BillingInfoModel extends BillingInfo {
  const BillingInfoModel({
    required super.plan,
    required super.description,
    super.paymentHistory,
  });

  factory BillingInfoModel.fromJson(Map<String, dynamic> json) {
    return BillingInfoModel(
      plan: json['plan'] as String? ?? 'Zedu Free',
      description: json['description'] as String? ?? '',
      paymentHistory:
          (json['payment_history'] as List<dynamic>?)
              ?.map(
                (e) => PaymentRecordModel.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
    );
  }
}

class PaymentRecordModel extends PaymentRecord {
  const PaymentRecordModel({
    required super.id,
    required super.description,
    required super.amount,
    required super.date,
    required super.status,
  });

  factory PaymentRecordModel.fromJson(Map<String, dynamic> json) {
    return PaymentRecordModel(
      id: json['id'] as String? ?? '',
      description: json['description'] as String? ?? 'Subscription Payment',
      amount: json['amount'] as String? ?? '',
      date: json['date'] as String? ?? '',
      status: json['status'] as String? ?? '',
    );
  }
}
