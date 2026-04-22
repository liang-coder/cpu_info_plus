import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'cpu_info_plus_method_channel.dart';
import 'src/cpu_info_models.dart';

abstract class CpuInfoPlusPlatform extends PlatformInterface {
  /// Constructs a CpuInfoPlusPlatform.
  CpuInfoPlusPlatform() : super(token: _token);

  static final Object _token = Object();

  static CpuInfoPlusPlatform _instance = MethodChannelCpuInfoPlus();

  /// The default instance of [CpuInfoPlusPlatform] to use.
  ///
  /// Defaults to [MethodChannelCpuInfoPlus].
  static CpuInfoPlusPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [CpuInfoPlusPlatform] when
  /// they register themselves.
  static set instance(CpuInfoPlusPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('getPlatformVersion has not been implemented.');
  }

  Future<int> getLogicalProcessorCount() {
    throw UnimplementedError('getLogicalProcessorCount has not been implemented.');
  }

  Future<int> getPhysicalProcessorCount() {
    throw UnimplementedError('getPhysicalProcessorCount has not been implemented.');
  }

  Future<List<String>> getSupportedAbis() {
    throw UnimplementedError('getSupportedAbis has not been implemented.');
  }

  Future<CpuHardwareSummary> getCpuHardwareSummary() {
    throw UnimplementedError('getCpuHardwareSummary has not been implemented.');
  }

  Future<CpuFrequencySnapshot> getCpuFrequencySnapshot() {
    throw UnimplementedError('getCpuFrequencySnapshot has not been implemented.');
  }

  Future<Map<String, String>> getCpuDetailedProperties() {
    throw UnimplementedError('getCpuDetailedProperties has not been implemented.');
  }

  Future<Map<String, dynamic>> getAllCpuInfo() {
    throw UnimplementedError('getAllCpuInfo has not been implemented.');
  }

  /// 区分「CPU 厂商寄存器 ID」与「SoC/平台线索」（含系统属性等）；不同平台字段差异大。
  Future<Map<String, String>> getSocIdentity() {
    throw UnimplementedError('getSocIdentity has not been implemented.');
  }

  /// GPU 供应商/渲染器字符串等（Android：EGL+GLES；iOS/macOS：Metal）。
  Future<GpuInfo> getGpuInfo() {
    throw UnimplementedError('getGpuInfo has not been implemented.');
  }

  /// 实时 CPU/GPU 频率流（Android/iOS/macOS：原生 EventChannel；Linux/Windows/Web：定时拉取）。
  Stream<FrequencyTelemetry> watchFrequencyTelemetry({
    Duration interval = const Duration(seconds: 1),
  }) {
    throw UnimplementedError('watchFrequencyTelemetry has not been implemented.');
  }
}
