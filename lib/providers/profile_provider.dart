import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/local_user_profile.dart';
import '../repositories/profile_repository.dart';

class ProfileTickNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final profileTickProvider = NotifierProvider<ProfileTickNotifier, int>(ProfileTickNotifier.new);

final profileProvider = Provider<LocalUserProfile?>((ref) {
  ref.watch(profileTickProvider);
  return ref.watch(profileRepositoryProvider).profile;
});
