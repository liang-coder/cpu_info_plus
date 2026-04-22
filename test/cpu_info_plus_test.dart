import 'package:flutter_test/flutter_test.dart';
import 'package:cpu_info_plus/cpu_info_plus.dart';
import 'package:cpu_info_plus/cpu_info_plus_platform_interface.dart';
import 'package:cpu_info_plus/cpu_info_plus_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockCpuInfoPlusPlatform
    with MockPlatformInterfaceMixin
    implements CpuInfoPlusPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<int> getLogicalProcessorCount() => Future.value(8);

  @override
  Future<int> getPhysicalProcessorCount() => Future.value(8);

  @override
  Future<List<String>> getSupportedAbis() => Future.value(const ['arm64']);

  @override
  Future<CpuHardwareSummary> getCpuHardwareSummary() => Future.value(
        const CpuHardwareSummary(manufacturer: 'm'),
      );

  @override
  Future<CpuFrequencySnapshot> getCpuFrequencySnapshot() => Future.value(
        const CpuFrequencySnapshot(minHzPerCpu: [], maxHzPerCpu: [], currentHzPerCpu: []),
      );

  @override
  Future<Map<String, String>> getCpuDetailedProperties() => Future.value({'k': 'v'});

  @override
  Future<Map<String, dynamic>> getAllCpuInfo() => Future.value({'platform': 'test'});

  @override
  Future<Map<String, String>> getSocIdentity() => Future.value({'a': 'b'});

  @override
  Future<GpuInfo> getGpuInfo() => Future.value(
        const GpuInfo(api: 'test', vendor: 'v'),
      );

  @override
  Stream<FrequencyTelemetry> watchFrequencyTelemetry({
    Duration interval = const Duration(seconds: 1),
  }) =>
      Stream<FrequencyTelemetry>.empty();
}

void main() {
  final CpuInfoPlusPlatform initialPlatform = CpuInfoPlusPlatform.instance;

  test('$MethodChannelCpuInfoPlus is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelCpuInfoPlus>());
  });

  test('getPlatformVersion', () async {
    final cpuInfoPlusPlugin = CpuInfoPlus();
    final fakePlatform = MockCpuInfoPlusPlatform();
    CpuInfoPlusPlatform.instance = fakePlatform;

    expect(await cpuInfoPlusPlugin.getPlatformVersion(), '42');
  });

  test('SiliconOverview maps QTI/QCOM to Qualcomm for display', () {
    final viaQti = SiliconOverview.compose(
      socIdentity: {'build_soc_manufacturer': 'qti'},
      gpu: const GpuInfo(api: 'OpenGL ES'),
    );
    expect(viaQti.socManufacturer, 'Qualcomm');

    final viaQcom = SiliconOverview.compose(
      socIdentity: {'prop_ro.soc.manufacturer': 'qcom'},
      gpu: const GpuInfo(api: 'OpenGL ES'),
    );
    expect(viaQcom.socManufacturer, 'Qualcomm');
  });
}
