import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

class DeviceIdService {
  static final DeviceIdService _instance = DeviceIdService._internal();
  factory DeviceIdService() => _instance;
  DeviceIdService._internal();

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  Future<String> getDeviceId() async {
    if (Platform.isAndroid) {
      final info = await _deviceInfo.androidInfo;
      // Note: some versions of device_info_plus don't expose androidId.
      // We use the most stable available values from the plugin.
      final id = info.id.isNotEmpty ? info.id : info.model;
      return 'android:$id';
    }
    if (Platform.isIOS) {
      final info = await _deviceInfo.iosInfo;
      final id = info.identifierForVendor ?? 'ios';
      return 'ios:$id';
    }
    if (Platform.isWindows) {
      final info = await _deviceInfo.windowsInfo;
      return 'windows:${info.deviceId}';
    }
    if (Platform.isMacOS) {
      final info = await _deviceInfo.macOsInfo;
      return 'macos:${info.systemGUID ?? info.model}';
    }
    if (Platform.isLinux) {
      final info = await _deviceInfo.linuxInfo;
      return 'linux:${info.machineId ?? info.name}';
    }
    return 'unknown';
  }
}

