import 'cpu_info_plus_platform_interface.dart';
import 'src/cpu_info_models.dart';

export 'src/cpu_info_models.dart';

/// Cross-platform CPU information (Android / iOS use full native collectors; others may be stubbed).
class CpuInfoPlus {
  Future<String?> getPlatformVersion() {
    return CpuInfoPlusPlatform.instance.getPlatformVersion();
  }

  /// Logical processors visible to the VM (typically matches active CPU indices).
  Future<int> getLogicalProcessorCount() {
    return CpuInfoPlusPlatform.instance.getLogicalProcessorCount();
  }

  /// Best-effort physical core count (topology/sysctl); may equal [getLogicalProcessorCount].
  Future<int> getPhysicalProcessorCount() {
    return CpuInfoPlusPlatform.instance.getPhysicalProcessorCount();
  }

  /// Android: [android.os.Build.SUPPORTED_ABIS]. iOS/macOS: a single arch label (e.g. `arm64`).
  Future<List<String>> getSupportedAbis() {
    return CpuInfoPlusPlatform.instance.getSupportedAbis();
  }

  /// Build / board / hardware identifiers when exposed by the OS.
  Future<CpuHardwareSummary> getCpuHardwareSummary() {
    return CpuInfoPlusPlatform.instance.getCpuHardwareSummary();
  }

  /// Per-CPU min / max / current frequencies (kHz). Empty when sysfs is unavailable.
  Future<CpuFrequencySnapshot> getCpuFrequencySnapshot() {
    return CpuInfoPlusPlatform.instance.getCpuFrequencySnapshot();
  }

  /// 整机快照（结构化字段）；底层详情由原生聚合，无需自行解析 Map。
  Future<FullCpuInfo> getCpuInfoReport() async {
    final merged = await _mergedAllCpuInfo();
    return FullCpuInfo.fromMergedMap(merged);
  }

  /// **推荐**：面向界面的一条龙摘要（芯片代号 + SoC 制造商 + GPU）。
  Future<SiliconOverview> getSiliconOverview() async {
    final soc = await CpuInfoPlusPlatform.instance.getSocIdentity();
    final gpu = await getGpuInfo();
    return SiliconOverview.compose(socIdentity: soc, gpu: gpu);
  }

  /// GPU 渲染信息（OpenGL ES / Metal 字符串）。
  Future<GpuInfo> getGpuInfo() {
    return CpuInfoPlusPlatform.instance.getGpuInfo();
  }

  /// 实时 CPU 各核与 **GPU 当前频率**（kHz）；无需手动下拉刷新。
  ///
  /// Android/iOS/macOS 使用原生 [EventChannel] 在后台读 sysfs；Web/Linux/Windows 为定时 [MethodChannel] 拉取。
  Stream<FrequencyTelemetry> watchFrequencyTelemetry({
    Duration interval = const Duration(seconds: 1),
  }) {
    return CpuInfoPlusPlatform.instance.watchFrequencyTelemetry(interval: interval);
  }
}

Future<Map<String, dynamic>> _mergedAllCpuInfo() async {
  final raw = await CpuInfoPlusPlatform.instance.getAllCpuInfo();
  final merged = Map<String, dynamic>.from(raw);
  final soc = _stringMapFromDynamic(merged['socIdentity']);
  final gpu = GpuInfo.fromMap(merged['gpuInfo'] as Map<Object?, Object?>?);
  merged['siliconOverview'] = SiliconOverview.compose(
    socIdentity: soc,
    gpu: gpu,
  ).toJson();
  return merged;
}

Map<String, String> _stringMapFromDynamic(Object? v) {
  if (v is! Map) return {};
  return {
    for (final e in v.entries)
      e.key.toString(): e.value?.toString() ?? '',
  };
}
