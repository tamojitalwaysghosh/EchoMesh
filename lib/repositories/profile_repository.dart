import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod/riverpod.dart';

import '../models/local_user_profile.dart';
import '../services/storage/hive_box_provider.dart';

class ProfileRepository {
  ProfileRepository(this._box);

  final Box<String> _box;
  static const _kProfile = 'profile_json';

  LocalUserProfile? get profile {
    final raw = _box.get(_kProfile);
    if (raw == null || raw.isEmpty) return null;
    try {
      return LocalUserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(LocalUserProfile p) async {
    await _box.put(_kProfile, jsonEncode(p.toJson()));
  }

  Future<void> clear() => _box.delete(_kProfile);
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(hiveBoxProvider));
});
