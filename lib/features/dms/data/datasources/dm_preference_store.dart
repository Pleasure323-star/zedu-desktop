import 'dart:convert';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Client-side persistence for small DM-wide choice sets ("pin this
/// conversation", "mute this person"), keyed by user and organisation.
///
/// Same shape as [DmDraftStore]: desktop-local storage via the app's
/// existing FlutterSecureStorage (SecureStorageService), with the same
/// `user:org:scope` namespacing, JSON encoding and swallow-storage-errors
/// rules. Each store instance holds a couple of named keys; values are
/// string sets encoded as JSON arrays.
class DmPreferenceStore {
  final SecureStorageService _storage;

  /// Storage key prefix scoped to the signed-in user and org, matching
  /// [DmDraftStore], so another account never sees these choices.
  final String _keyPrefix;

  DmPreferenceStore(
    this._storage, {
    required String userId,
    required String orgId,
  }) : _keyPrefix = 'dm_prefs_${userId}_${orgId}_';

  /// Reads the ids saved under [key]; an empty set when storage is empty
  /// (first launch, nothing saved yet) or unreadable.
  Future<Set<String>> load(String key) async {
    try {
      final raw = await _storage.readData('$_keyPrefix$key');
      if (raw == null) return const {};
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const {};
      return Set<String>.from(decoded.whereType<String>());
    } catch (_) {
      return const {};
    }
  }

  /// Writes [ids] under [key]; removes the entry when [ids] is empty so
  /// storage does not keep stale keys around.
  Future<void> save(String key, Set<String> ids) async {
    try {
      if (ids.isEmpty) {
        await _storage.deleteValue('$_keyPrefix$key');
        return;
      }
      await _storage.writeData('$_keyPrefix$key', jsonEncode(ids.toList()));
    } catch (_) {
      // Storage failure should not break the UI action that saved.
    }
  }
}

final dmPreferenceStoreProvider = Provider<DmPreferenceStore?>((ref) {
  // Rebuilt on a user or org change so consumers reload the right namespaced
  // keys, mirroring dmDraftStoreProvider.
  // Null when secure storage is not registered (widget tests build screens
  // without setupLocator): consumers then skip persistence quietly, like
  // user_profile_remote_datasource's locator.isRegistered guards.
  if (!locator.isRegistered<SecureStorageService>()) return null;
  final userId = ref.watch(
    authNotifierProvider.select((state) => state.user?.id ?? ''),
  );
  final orgId = ref.watch(currentOrgIdProvider);
  return DmPreferenceStore(
    locator<SecureStorageService>(),
    userId: userId,
    orgId: orgId,
  );
});
