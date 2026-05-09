import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_theme.dart';
import '../../models/local_user_profile.dart';
import '../../providers/profile_provider.dart';
import '../../repositories/profile_repository.dart';
import '../../services/echomesh_ble_notifier.dart';
import '../../shared/widgets/em_primary_button.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _name = TextEditingController();
  final _emergency = TextEditingController();
  String? _avatarPath;
  String? _meshId;

  @override
  void initState() {
    super.initState();
    final existing = ref.read(profileRepositoryProvider).profile;
    if (existing != null) {
      _name.text = existing.username;
      _emergency.text = existing.emergencyInfo;
      _avatarPath = existing.avatarPath;
      _meshId = existing.meshId.isEmpty ? const Uuid().v4() : existing.meshId;
    } else {
      _meshId = const Uuid().v4();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _emergency.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final pick = ImagePicker();
    final x = await pick.pickImage(source: ImageSource.gallery, maxWidth: 1024);
    if (x == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final dest = File('${dir.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await File(x.path).copy(dest.path);
    setState(() => _avatarPath = dest.path);
  }

  Future<void> _save() async {
    final n = _name.text.trim();
    if (n.isEmpty) return;
    final mesh = _meshId ?? const Uuid().v4();
    final p = LocalUserProfile(
      username: n,
      meshId: mesh,
      avatarPath: _avatarPath,
      emergencyInfo: _emergency.text.trim(),
    );
    await ref.read(profileRepositoryProvider).save(p);
    ref.read(profileTickProvider.notifier).bump();
    await ref.read(echomeshBleProvider.notifier).restartPeripheral(p.username);
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Operator profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Stored only on this device. Used for BLE discovery name and message signatures.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.onSurfaceMuted),
          ),
          const SizedBox(height: 24),
          Center(
            child: GestureDetector(
              onTap: _pickAvatar,
              child: CircleAvatar(
                radius: 48,
                backgroundColor: AppTheme.surfaceVariant,
                backgroundImage: _avatarPath != null ? FileImage(File(_avatarPath!)) : null,
                child: _avatarPath == null
                    ? Icon(Icons.add_a_photo_outlined, color: AppTheme.onSurfaceMuted)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(onPressed: _pickAvatar, child: const Text('Set portrait')),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Call sign / name'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emergency,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Emergency notes',
              hintText: 'Blood type, allergies, rally point…',
            ),
          ),
          const SizedBox(height: 32),
          EmPrimaryButton(
            label: 'Save & enter dashboard',
            onPressed: _save,
          ),
          const SizedBox(height: 12),
          Text(
            'Android hosts a BLE service so other EchoMesh devices can connect. iOS can scan and connect to Android peers.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.onSurfaceMuted),
          ),
        ],
      ),
    );
  }
}
