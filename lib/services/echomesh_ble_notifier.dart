import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod/riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/app_constants.dart';
import '../core/constants/ble_uuids.dart';
import '../models/wire_payload.dart';
import '../repositories/chat_repository.dart';
import '../repositories/prefs_repository.dart';
import '../repositories/profile_repository.dart';
import 'ble_host_platform.dart';
import 'notification_service.dart';
import 'permissions_service.dart';

class EchomeshBleState {
  const EchomeshBleState({
    required this.scanResults,
    required this.scanning,
    required this.adapterOn,
    required this.connectedRemoteId,
    required this.connecting,
    required this.hostingActive,
    required this.lastSeenMsById,
    this.linkError,
  });

  final List<ScanResult> scanResults;
  final bool scanning;
  final bool adapterOn;
  final String? connectedRemoteId;
  final bool connecting;
  final bool hostingActive;
  final Map<String, int> lastSeenMsById;
  final String? linkError;

  static EchomeshBleState initial() => const EchomeshBleState(
    scanResults: [],
    scanning: false,
    adapterOn: false,
    connectedRemoteId: null,
    connecting: false,
    hostingActive: false,
    lastSeenMsById: {},
  );

  EchomeshBleState copyWith({
    List<ScanResult>? scanResults,
    bool? scanning,
    bool? adapterOn,
    String? connectedRemoteId,
    bool clearConnected = false,
    bool? connecting,
    bool? hostingActive,
    Map<String, int>? lastSeenMsById,
    String? linkError,
    bool clearLinkError = false,
  }) {
    return EchomeshBleState(
      scanResults: scanResults ?? this.scanResults,
      scanning: scanning ?? this.scanning,
      adapterOn: adapterOn ?? this.adapterOn,
      connectedRemoteId: clearConnected
          ? null
          : (connectedRemoteId ?? this.connectedRemoteId),
      connecting: connecting ?? this.connecting,
      hostingActive: hostingActive ?? this.hostingActive,
      lastSeenMsById: lastSeenMsById ?? this.lastSeenMsById,
      linkError: clearLinkError ? null : (linkError ?? this.linkError),
    );
  }
}

final echomeshBleProvider =
    NotifierProvider<EchomeshBleNotifier, EchomeshBleState>(
      EchomeshBleNotifier.new,
    );

class EchomeshBleNotifier extends Notifier<EchomeshBleState> {
  StreamSubscription<List<ScanResult>>? _scanResSub;
  StreamSubscription<BluetoothAdapterState>? _adapterSub;
  StreamSubscription<String>? _hostInSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  StreamSubscription<List<int>>? _txSub;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _rx;

  Timer? _reconnectTimer;
  String? _reconnectTargetId;
  String? _reconnectPeerName;

  final _uuid = const Uuid();

  ChatRepository get _chat => ref.read(chatRepositoryProvider);
  ProfileRepository get _profileRepo => ref.read(profileRepositoryProvider);
  PrefsRepository get _prefs => ref.read(prefsRepositoryProvider);

  @override
  EchomeshBleState build() {
    ref.onDispose(() {
      _dispose();
    });
    return EchomeshBleState.initial();
  }

  void _dispose() {
    _scanResSub?.cancel();
    _adapterSub?.cancel();
    _hostInSub?.cancel();
    _connSub?.cancel();
    _txSub?.cancel();
    _reconnectTimer?.cancel();
  }

  Future<void> bootstrap() async {
    final permsOk = await PermissionsService.ensureBlePermissions();
    if (!permsOk) {
      state = state.copyWith(linkError: 'Bluetooth permissions are required');
    }

    try {
      _adapterSub ??= FlutterBluePlus.adapterState.listen((s) {
        // On some Android devices the first value can be `unknown`.
        // Treat `unknown` as "not determined yet", not as "Bluetooth off".
        if (s == BluetoothAdapterState.unknown) return;

        final on = s == BluetoothAdapterState.on;
        if (on) {
          state = state.copyWith(adapterOn: true, clearLinkError: true);
        } else {
          state = state.copyWith(
            adapterOn: false,
            linkError: 'Bluetooth radio off',
          );
          _scheduleReconnect();
        }
      });

      final adapter = await FlutterBluePlus.adapterState.first.timeout(
        const Duration(seconds: 3),
      );
      if (adapter != BluetoothAdapterState.unknown) {
        state = state.copyWith(adapterOn: adapter == BluetoothAdapterState.on);
      }
    } catch (_) {
      state = state.copyWith(
        adapterOn: false,
        linkError: 'Bluetooth not available',
      );
    }

    try {
      _hostInSub ??= BleHostPlatform.incomingPayloads().listen(_onWireFromHost);
    } catch (_) {}

    try {
      final p = _profileRepo.profile;
      if (p != null) {
        await restartPeripheral(p.username);
      }
    } catch (_) {}
  }

  Future<void> restartPeripheral(String username) async {
    final permsOk = await PermissionsService.ensureBlePermissions();
    if (!permsOk) {
      state = state.copyWith(
        hostingActive: false,
        linkError: 'Grant Bluetooth permissions',
      );
      return;
    }
    final ok = await BleHostPlatform.start(displayName: username);
    state = state.copyWith(
      hostingActive: ok,
      linkError: ok ? null : 'Unable to start BLE host',
      clearLinkError: ok,
    );
  }

  Future<void> startScanning() async {
    if (state.scanning) return;

    // Refresh adapter state right before scan (bootstrap may not have updated yet).
    try {
      final adapter = await FlutterBluePlus.adapterState
          .where((s) => s != BluetoothAdapterState.unknown)
          .first
          .timeout(const Duration(seconds: 3));
      final on = adapter == BluetoothAdapterState.on;
      state = state.copyWith(adapterOn: on, clearLinkError: on);
    } catch (_) {
      // keep existing state; startScan will still throw a useful PlatformException
    }

    if (!state.adapterOn) {
      state = state.copyWith(
        linkError: 'Bluetooth must be turned on to scan',
        scanning: false,
      );
      return;
    }

    final permsOk = await PermissionsService.ensureBlePermissions();
    if (!permsOk) {
      state = state.copyWith(linkError: 'Grant Bluetooth permissions to scan');
      return;
    }
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    state = state.copyWith(scanning: true, scanResults: []);
    try {
      await FlutterBluePlus.startScan(
        // Prefer service UUID filtering (more reliable than name filtering).
        withServices: [EchoMeshBleUuids.service],
        // NOTE: On Android, flutter_blue_plus asserts that `withKeywords` cannot be
        // combined with other filters (like `withServices`). So we avoid keywords here.
        continuousUpdates: true,
        removeIfGone: const Duration(seconds: 5),
        androidScanMode: AndroidScanMode.lowLatency,
      );
      await _scanResSub?.cancel();
      _scanResSub = FlutterBluePlus.scanResults.listen((results) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final nextSeen = Map<String, int>.from(state.lastSeenMsById);
        for (final r in results) {
          nextSeen[r.device.remoteId.str.toUpperCase()] = now;
        }
        state = state.copyWith(
          scanResults: List<ScanResult>.from(results),
          lastSeenMsById: nextSeen,
        );
      });
    } catch (e) {
      // Handle platform exceptions like "Bluetooth must be turned on"
      debugPrint('EchoMesh startScan failed: $e');
      final msg = e.toString().toLowerCase();
      final looksLikeBtOff =
          msg.contains('bluetooth must be turned on') ||
          (msg.contains('bluetooth') && msg.contains('off'));
      state = state.copyWith(
        scanning: false,
        adapterOn: looksLikeBtOff ? false : state.adapterOn,
        linkError: looksLikeBtOff
            ? 'Bluetooth is off. Turn it on and try again.'
            : 'Unable to scan right now. Please try again.',
      );
    }
  }

  Future<void> stopScanning() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    await _scanResSub?.cancel();
    _scanResSub = null;
    state = state.copyWith(scanning: false);
  }

  /// Opens Bluetooth settings so user can enable Bluetooth
  /// Returns true if settings opened successfully
  Future<bool> openBluetoothSettings() async {
    try {
      await FlutterBluePlus.turnOn();
      // Give the system a moment to update adapter state.
      try {
        final adapter = await FlutterBluePlus.adapterState
            .where((s) => s == BluetoothAdapterState.on)
            .first
            .timeout(const Duration(seconds: 6));
        state = state.copyWith(adapterOn: adapter == BluetoothAdapterState.on);
      } catch (_) {}
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> connectTo(ScanResult result) async {
    final remoteId = result.device.remoteId.str;
    final name = result.device.advName.isNotEmpty
        ? result.device.advName
        : (result.device.platformName.isNotEmpty
              ? result.device.platformName
              : remoteId);
    await _prefs.rememberPeerAlias(remoteId, name);
    state = state.copyWith(connecting: true, clearLinkError: true);
    try {
      await stopScanning();
      await _device?.disconnect();
      _cleanupGattSubscription();
      _device = result.device;
      await _device!.connect(
        license: License.free,
        timeout: const Duration(seconds: 15),
      );
      await _device!.connectionState
          .where((e) => e == BluetoothConnectionState.connected)
          .first
          .timeout(const Duration(seconds: 20));
      await _finishCentralGatt(remoteId, name);
      unawaited(
        NotificationService.notify(
          title: 'Connected',
          body: 'Link active with $name',
        ),
      );
      unawaited(_sendMyAvatarIfAny(threadId: remoteId));

      // MTU negotiation is optional and can hang/timeout on some stacks.
      // Do not block the connection flow on it.
      unawaited(() async {
        try {
          // 247 is widely supported; 512 frequently fails.
          await _device!
              .requestMtu(247)
              .timeout(const Duration(seconds: 3));
        } catch (_) {}
      }());
    } catch (e) {
      // Detect Bluetooth off errors
      final errorMsg = e.toString().toLowerCase();
      if (errorMsg.contains('bluetooth') && errorMsg.contains('off')) {
        state = state.copyWith(
          connecting: false,
          adapterOn: false,
          linkError: 'Bluetooth is off. Please enable Bluetooth to connect.',
        );
      } else {
        state = state.copyWith(connecting: false, linkError: '$e');
      }
    }
  }

  Future<void> _finishCentralGatt(String remoteId, String peerName) async {
    final d = _device;
    if (d == null) {
      state = state.copyWith(connecting: false, linkError: 'Device lost');
      return;
    }
    final services = await d.discoverServices();
    BluetoothCharacteristic? rx;
    BluetoothCharacteristic? tx;
    for (final s in services) {
      if (s.uuid == EchoMeshBleUuids.service) {
        for (final c in s.characteristics) {
          if (c.uuid == EchoMeshBleUuids.rx) rx = c;
          if (c.uuid == EchoMeshBleUuids.tx) tx = c;
        }
      }
    }
    if (rx == null || tx == null) {
      state = state.copyWith(
        connecting: false,
        linkError: 'Peer is not broadcasting EchoMesh',
      );
      return;
    }
    _rx = rx;
    await tx.setNotifyValue(true, timeout: 15);
    await _txSub?.cancel();
    _txSub = tx.lastValueStream.listen(_onWireFromCentral);
    _reconnectTargetId = remoteId;
    _reconnectPeerName = peerName;
    await _prefs.setLastConnected(remoteId: remoteId, peerName: peerName);
    _attachConnectionListener();
    state = state.copyWith(
      connectedRemoteId: remoteId,
      connecting: false,
      clearLinkError: true,
    );
  }

  Future<void> _sendMyAvatarIfAny({required String threadId}) async {
    final profile = _profileRepo.profile;
    final path = profile?.avatarPath;
    if (profile == null || path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (!await file.exists()) return;
      final bytes = await file.readAsBytes();
      // Keep payload reasonably small for BLE.
      if (bytes.length > 24 * 1024) return;
      final b64 = base64Encode(bytes);
      final p = WirePayload(
        id: _uuid.v4(),
        senderId: profile.meshId,
        senderHandle: profile.username,
        text: '',
        ts: DateTime.now().millisecondsSinceEpoch,
        kind: 'avatar',
        avatarBase64: b64,
      );
      await _pushPayload(p, threadId: threadId);
    } catch (e) {
      debugPrint('Send avatar failed: $e');
    }
  }

  void _attachConnectionListener() {
    _connSub?.cancel();
    final d = _device;
    if (d == null) return;
    _connSub = d.connectionState.listen((s) {
      if (s == BluetoothConnectionState.disconnected) {
        state = state.copyWith(clearConnected: true);
        _cleanupGattSubscription();
        unawaited(
          NotificationService.notify(
            title: 'Disconnected',
            body: 'Link dropped',
          ),
        );
        _scheduleReconnect();
      }
    });
  }

  void _cleanupGattSubscription() {
    _txSub?.cancel();
    _txSub = null;
    _rx = null;
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    final id = _reconnectTargetId;
    if (id == null || id.isEmpty) return;
    if (!state.adapterOn) {
      // Bluetooth is off, don't schedule but set error message
      state = state.copyWith(
        linkError: 'Bluetooth is off. Turn it on to reconnect.',
      );
      return;
    }
    _reconnectTimer = Timer(AppConstants.reconnectDelay, () async {
      if (state.connectedRemoteId != null) return;
      final name = _reconnectPeerName ?? _prefs.lastPeerName ?? id;
      try {
        state = state.copyWith(connecting: true, clearLinkError: true);
        final d = BluetoothDevice.fromId(id);
        _device = d;
        await d.connect(
          license: License.free,
          timeout: const Duration(seconds: 20),
        );
        await d.connectionState
            .where((e) => e == BluetoothConnectionState.connected)
            .first
            .timeout(const Duration(seconds: 25));
        await _finishCentralGatt(id, name);

        unawaited(() async {
          try {
            await d.requestMtu(247).timeout(const Duration(seconds: 3));
          } catch (_) {}
        }());
      } catch (e) {
        // Check if Bluetooth was turned off
        final errorMsg = e.toString().toLowerCase();
        if (errorMsg.contains('bluetooth') && errorMsg.contains('off')) {
          state = state.copyWith(
            connecting: false,
            adapterOn: false,
            linkError: 'Bluetooth is off. Turn it on to reconnect.',
          );
        } else {
          state = state.copyWith(
            connecting: false,
            linkError: 'Reconnecting… ($e)',
          );
          _scheduleReconnect();
        }
      }
    });
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTargetId = null;
    _reconnectPeerName = null;
    _cleanupGattSubscription();
    try {
      await _device?.disconnect();
    } catch (_) {}
    _device = null;
    state = state.copyWith(clearConnected: true);
  }

  Future<void> sendText({
    required String threadId,
    required String text,
    required bool emergency,
  }) async {
    final profile = _profileRepo.profile;
    if (profile == null || profile.meshId.isEmpty) return;

    final payload = WirePayload(
      id: _uuid.v4(),
      senderId: profile.meshId,
      senderHandle: profile.username,
      text: text,
      ts: DateTime.now().millisecondsSinceEpoch,
      emergency: emergency,
      kind: 'msg',
    );

    await _chat.addOutgoing(
      threadId: threadId,
      text: text,
      emergency: emergency,
      delivered: false,
    );

    try {
      await _pushPayload(payload, threadId: threadId);
    } catch (_) {
      // stays undelivered — operator can retry when link returns
    }
  }

  Future<void> sendReadReceipt({
    required String threadId,
    required String messageId,
  }) async {
    await _sendAck(threadId: threadId, ackFor: messageId, ackType: 'read');
  }

  Future<void> _sendAck({
    required String threadId,
    required String ackFor,
    required String ackType,
  }) async {
    final profile = _profileRepo.profile;
    if (profile == null || profile.meshId.isEmpty) return;
    final p = WirePayload(
      id: _uuid.v4(),
      senderId: profile.meshId,
      senderHandle: profile.username,
      text: '',
      ts: DateTime.now().millisecondsSinceEpoch,
      kind: 'ack',
      ackFor: ackFor,
      ackType: ackType,
    );
    try {
      await _pushPayload(p, threadId: threadId);
    } catch (e) {
      debugPrint('Ack send failed: $e');
    }
  }

  Future<void> _pushPayload(WirePayload p, {required String threadId}) async {
    final bytes = utf8.encode(p.encode());
    final active = state.connectedRemoteId?.toUpperCase();
    final target = threadId.toUpperCase();
    if (active != null &&
        active == target &&
        _rx != null &&
        (_device?.isConnected ?? false)) {
      await _rx!.write(
        List<int>.from(bytes),
        withoutResponse: true,
        timeout: 15,
      );
      return;
    }
    if (BleHostPlatform.isSupported) {
      await BleHostPlatform.notifyWire(p.encode());
      return;
    }
    throw StateError('No link');
  }

  void _onWireFromCentral(List<int> value) {
    if (value.isEmpty) return;
    final raw = utf8.decode(value);
    final wp = WirePayload.tryDecode(raw);
    if (wp == null) return;
    final peer = state.connectedRemoteId ?? _reconnectTargetId;
    if (peer == null) return;
    final alias = wp.senderHandle ?? _prefs.peerAliases[peer.toUpperCase()];
    unawaited(_handleWire(threadId: peer, wp: wp, displayAlias: alias));
  }

  void _onWireFromHost(String framed) {
    final pipe = framed.indexOf('|');
    if (pipe <= 0) return;
    final origin = framed.substring(0, pipe).trim();
    final json = framed.substring(pipe + 1);
    if (origin == 'evt') {
      // evt|conn|CONNECTED|AA:BB:CC:DD:EE:FF
      final parts = json.split('|');
      if (parts.length >= 3 && parts[0] == 'conn') {
        final st = parts[1];
        final id = parts[2].trim();
        if (id.isNotEmpty) {
          final friendly =
              _prefs.peerAliases[id.toUpperCase()] ??
              (id.length >= 8 ? 'Peer ${id.substring(0, 8)}' : 'Peer');
          if (st == 'CONNECTED') {
            state = state.copyWith(connectedRemoteId: id, clearLinkError: true);
            unawaited(
              NotificationService.notify(
                title: 'Connected',
                body: 'Link active with $friendly',
              ),
            );
          } else if (st == 'DISCONNECTED') {
            state = state.copyWith(clearConnected: true);
            unawaited(
              NotificationService.notify(
                title: 'Disconnected',
                body: 'Link dropped with $friendly',
              ),
            );
          }
        }
      }
      return;
    }
    final wp = WirePayload.tryDecode(json);
    if (wp == null) return;
    final alias = wp.senderHandle ?? origin;
    unawaited(_handleWire(threadId: origin, wp: wp, displayAlias: alias));
  }

  Future<void> _handleWire({
    required String threadId,
    required WirePayload wp,
    String? displayAlias,
  }) async {
    if (wp.kind == 'ack') {
      final forId = wp.ackFor;
      final ty = wp.ackType;
      if (forId == null || ty == null) return;
      if (ty == 'delivered') {
        await _chat.markDelivered(threadId, forId);
      } else if (ty == 'read') {
        await _chat.markReadByPeer(threadId, forId);
      }
      return;
    }
    if (wp.kind == 'avatar') {
      final b64 = wp.avatarBase64;
      if (b64 != null && b64.isNotEmpty) {
        await _prefs.rememberPeerAvatarBase64(threadId, b64);
      }
      return;
    }
    await _ingest(threadId: threadId, wp: wp, displayAlias: displayAlias);
    // Delivered receipt.
    await _sendAck(threadId: threadId, ackFor: wp.id, ackType: 'delivered');
  }

  Future<void> _ingest({
    required String threadId,
    required WirePayload wp,
    String? displayAlias,
  }) async {
    if (displayAlias != null && displayAlias.isNotEmpty) {
      await _prefs.rememberPeerAlias(threadId, displayAlias);
    }
    await _chat.addIncoming(
      threadId: threadId,
      text: wp.text,
      emergency: wp.emergency,
      wireMessageId: wp.id,
    );
    unawaited(
      NotificationService.notify(
        title: wp.emergency ? 'SOS message' : 'New message',
        body: '${displayAlias ?? threadId}: ${wp.text}',
      ),
    );
  }

  int nearbyEchoMeshCount(List<ScanResult> results) => results.length;
}
