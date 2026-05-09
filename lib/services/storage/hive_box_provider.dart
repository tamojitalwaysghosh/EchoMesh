import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod/riverpod.dart';

const String kHiveBoxName = 'echomesh';

final hiveBoxProvider = Provider<Box<String>>((ref) {
  throw StateError('Hive box must be overridden in main()');
});
