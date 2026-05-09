import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  test('Hive persists string box', () async {
    final temp = Directory.systemTemp.createTempSync('echomesh_hive_');
    addTearDown(() {
      if (temp.existsSync()) {
        temp.deleteSync(recursive: true);
      }
    });

    Hive.init(temp.path);
    final box = await Hive.openBox<String>('echomesh');
    await box.put('ping', 'pong');
    expect(box.get('ping'), 'pong');
    await box.close();
  });
}
