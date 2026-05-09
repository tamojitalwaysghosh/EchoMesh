import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod/riverpod.dart';

import '../services/storage/hive_box_provider.dart';

class PrefsRepository {
  PrefsRepository(this._box);

  final Box<String> _box;

  static const _kOnboarding = 'prefs_onboarding_done';
  static const _kLastRemote = 'prefs_last_remote_id';
  static const _kLastPeerName = 'prefs_last_peer_name';
  static const _kPeerAliases = 'peer_aliases_json';
  static const _kPeerAvatars = 'peer_avatars_b64_json';

  bool get onboardingComplete => _box.get(_kOnboarding) == '1';

  Future<void> setOnboardingComplete() => _box.put(_kOnboarding, '1');

  String? get lastConnectedRemoteId => _box.get(_kLastRemote);

  Future<void> setLastConnected({required String remoteId, required String peerName}) async {
    await _box.put(_kLastRemote, remoteId);
    await _box.put(_kLastPeerName, peerName);
  }

  String? get lastPeerName => _box.get(_kLastPeerName);

  Future<void> clearLastConnected() async {
    await _box.delete(_kLastRemote);
    await _box.delete(_kLastPeerName);
  }

  Map<String, String> get peerAliases {
    final raw = _box.get(_kPeerAliases);
    if (raw == null || raw.isEmpty) return {};
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return m.map((k, v) => MapEntry(k.toUpperCase(), '$v'));
    } catch (_) {
      return {};
    }
  }

  Future<void> rememberPeerAlias(String remoteId, String displayName) async {
    final m = Map<String, String>.from(peerAliases);
    m[remoteId.toUpperCase()] = displayName;
    await _box.put(_kPeerAliases, jsonEncode(m));
  }

  Map<String, String> get peerAvatarsBase64 {
    final raw = _box.get(_kPeerAvatars);
    if (raw == null || raw.isEmpty) return {};
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return m.map((k, v) => MapEntry(k.toUpperCase(), '$v'));
    } catch (_) {
      return {};
    }
  }

  Future<void> rememberPeerAvatarBase64(String remoteId, String base64JpegOrPng) async {
    final m = Map<String, String>.from(peerAvatarsBase64);
    m[remoteId.toUpperCase()] = base64JpegOrPng;
    await _box.put(_kPeerAvatars, jsonEncode(m));
  }
}

final prefsRepositoryProvider = Provider<PrefsRepository>((ref) {
  return PrefsRepository(ref.watch(hiveBoxProvider));
});
