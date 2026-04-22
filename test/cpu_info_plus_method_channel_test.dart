import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cpu_info_plus/cpu_info_plus_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelCpuInfoPlus();
  const channel = MethodChannel('cpu_info_plus');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'getPlatformVersion':
            return '42';
          case 'getLogicalProcessorCount':
            return 4;
          case 'getPhysicalProcessorCount':
            return 4;
          case 'getSupportedAbis':
            return ['arm64-v8a'];
          case 'getCpuHardwareSummary':
            return {'hardware': 'test'};
          case 'getCpuFrequencySnapshot':
            return {
              'minHzPerCpu': [100],
              'maxHzPerCpu': [200],
              'currentHzPerCpu': [150],
            };
          case 'getCpuDetailedProperties':
            return {'a': 'b'};
          case 'getSocIdentity':
            return {'prop_ro_hardware': 'qcom'};
          case 'getGpuInfo':
            return {'api': 'OpenGL ES', 'vendor': 'Qualcomm', 'renderer': 'Adreno'};
          case 'getAllCpuInfo':
            return {'platform': 'android'};
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });

  test('getLogicalProcessorCount', () async {
    expect(await platform.getLogicalProcessorCount(), 4);
  });

  test('getCpuFrequencySnapshot', () async {
    final f = await platform.getCpuFrequencySnapshot();
    expect(f.minHzPerCpu, [100]);
    expect(f.maxHzPerCpu, [200]);
    expect(f.currentHzPerCpu, [150]);
  });

  test('getAllCpuInfo', () async {
    final m = await platform.getAllCpuInfo();
    expect(m['platform'], 'android');
  });

  test('getSocIdentity', () async {
    final m = await platform.getSocIdentity();
    expect(m['prop_ro_hardware'], 'qcom');
  });

  test('getGpuInfo', () async {
    final g = await platform.getGpuInfo();
    expect(g.api, 'OpenGL ES');
    expect(g.vendor, 'Qualcomm');
  });
}
