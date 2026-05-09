import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionsService {
  static Future<bool> ensureBlePermissions() async {
    if (!await FlutterBluePlus.isSupported) return false;

    final scan = await Permission.bluetoothScan.request();
    final connect = await Permission.bluetoothConnect.request();
    final advertise = await Permission.bluetoothAdvertise.request();
    if (scan.isGranted && connect.isGranted && advertise.isGranted) {
      return true;
    }

    final loc = await Permission.locationWhenInUse.request();
    return loc.isGranted &&
        scan.isGranted &&
        connect.isGranted &&
        advertise.isGranted;
  }
}
