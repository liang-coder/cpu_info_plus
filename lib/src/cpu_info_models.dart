// Typed wrappers for CPU information returned from native code.

library;

class CpuCoreCounts {
  const CpuCoreCounts({
    required this.logical,
    required this.physical,
  });

  final int logical;
  final int physical;

  factory CpuCoreCounts.fromMap(Map<Object?, Object?> map) {
    return CpuCoreCounts(
      logical: _asInt(map['logical']) ?? 0,
      physical: _asInt(map['physical']) ?? 0,
    );
  }

  Map<String, int> toJson() => {
        'logical': logical,
        'physical': physical,
      };
}

class CpuFrequencySnapshot {
  const CpuFrequencySnapshot({
    required this.minHzPerCpu,
    required this.maxHzPerCpu,
    required this.currentHzPerCpu,
  });

  final List<int?> minHzPerCpu;
  final List<int?> maxHzPerCpu;
  final List<int?> currentHzPerCpu;

  factory CpuFrequencySnapshot.fromMap(Map<Object?, Object?> map) {
    return CpuFrequencySnapshot(
      minHzPerCpu: _asIntList(map['minHzPerCpu']),
      maxHzPerCpu: _asIntList(map['maxHzPerCpu']),
      currentHzPerCpu: _asIntList(map['currentHzPerCpu']),
    );
  }

  Map<String, dynamic> toJson() => {
        'minHzPerCpu': minHzPerCpu,
        'maxHzPerCpu': maxHzPerCpu,
        'currentHzPerCpu': currentHzPerCpu,
      };
}

class CpuHardwareSummary {
  /// 使用 const 构造函数以便 Web 占位实现等处使用常量实例。
  const CpuHardwareSummary({
    this.manufacturer,
    this.brand,
    this.device,
    this.model,
    this.board,
    this.hardware,
    this.product,
    this.machine,
  });

  final String? manufacturer;
  final String? brand;
  final String? device;
  final String? model;
  final String? board;
  final String? hardware;
  final String? product;

  /// iOS/macOS sysctl `hw.machine` style identifier when applicable.
  final String? machine;

  factory CpuHardwareSummary.fromMap(Map<Object?, Object?> map) {
    String? s(String k) => map[k]?.toString();
    return CpuHardwareSummary(
      manufacturer: s('manufacturer'),
      brand: s('brand'),
      device: s('device'),
      model: s('model'),
      board: s('board'),
      hardware: s('hardware'),
      product: s('product'),
      machine: s('machine'),
    );
  }

  Map<String, String> toJson() {
    final m = <String, String>{};
    void put(String k, String? v) {
      if (v != null && v.isNotEmpty) m[k] = v;
    }

    put('manufacturer', manufacturer);
    put('brand', brand);
    put('device', device);
    put('model', model);
    put('board', board);
    put('hardware', hardware);
    put('product', product);
    put('machine', machine);
    return m;
  }
}

int? _asInt(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.round();
  return int.tryParse(v.toString());
}

List<int?> _asIntList(Object? v) {
  if (v is! List) return const [];
  return v.map(_asInt).toList();
}

/// GPU 信息（Android：OpenGL ES 字符串；Apple：Metal 设备名）。
class GpuInfo {
  const GpuInfo({
    required this.api,
    this.vendor,
    this.renderer,
    this.version,
    this.shadingLanguageVersion,
    this.note,
    this.error,
  });

  /// 例如：`OpenGL ES`、`Metal`、`unavailable`。
  final String api;
  final String? vendor;
  final String? renderer;
  final String? version;
  final String? shadingLanguageVersion;
  final String? note;
  final String? error;

  factory GpuInfo.fromMap(Map<Object?, Object?>? m) {
    if (m == null) {
      return const GpuInfo(api: 'unavailable', note: '无原生返回');
    }
    String? s(String k) {
      final v = m[k];
      if (v == null) return null;
      final t = v.toString();
      return t.isEmpty ? null : t;
    }

    return GpuInfo(
      api: s('api') ?? 'unknown',
      vendor: s('vendor'),
      renderer: s('renderer'),
      version: s('version'),
      shadingLanguageVersion: s('glsl_version') ?? s('shadingLanguageVersion'),
      note: s('note'),
      error: s('error'),
    );
  }

  Map<String, dynamic> toJson() => {
        'api': api,
        if (vendor != null) 'vendor': vendor,
        if (renderer != null) 'renderer': renderer,
        if (version != null) 'version': version,
        if (shadingLanguageVersion != null) 'shadingLanguageVersion': shadingLanguageVersion,
        if (note != null) 'note': note,
        if (error != null) 'error': error,
      };

  /// 单行展示用（Metal / Adreno 等）。
  String get displayLine {
    final parts = <String>[
      if (vendor != null && vendor!.isNotEmpty) vendor!,
      if (renderer != null && renderer!.isNotEmpty) renderer!,
    ];
    if (parts.isEmpty) return api;
    return '${parts.join(' · ')}（$api）';
  }
}

/// 将系统里常见的缩写 SoC 厂商串转为更易读的展示名（不改变芯片型号）。
///
/// 高通设备上 [Build.SOC_MANUFACTURER] / `ro.soc.manufacturer` 常为 **`QTI`**（Qualcomm Technologies,
/// Inc.），与对外品牌名 「Qualcomm」一致，仅为 OEM 缩写写法。
String? _friendlySocManufacturer(String? raw) {
  if (raw == null) return null;
  final t = raw.trim();
  if (t.isEmpty) return null;
  switch (t.toLowerCase()) {
    case 'qti':
    case 'qcom':
      return 'Qualcomm';
    case 'mtk':
      return 'MediaTek';
    default:
      return t;
  }
}

/// SoC + GPU 面向 UI 的摘要（从 [GpuInfo] 与 [Map] SOC 字段推导，避免业务自行拼键名）。
///
/// - [socModel]：如 Qualcomm 平台的 `SM8550`
/// - [socManufacturer]：面向展示时已做缩写友好化（如 QTI→Qualcomm）
class SiliconOverview {
  const SiliconOverview({
    this.socModel,
    this.socManufacturer,
    required this.gpu,
    this.candidateChain,
  });

  /// 芯片型号 / 对外代号（优先官方 [Build.SOC_MODEL] 对应原生键 `build_soc_model`）。
  final String? socModel;

  /// SoC / 硅片平台制造商（展示友好名；源码可为 QTI 等缩写）。
  final String? socManufacturer;

  final GpuInfo gpu;

  /// 原生汇总的候选串联，便于核对数据来源。
  final String? candidateChain;

  factory SiliconOverview.compose({
    required Map<String, String> socIdentity,
    required GpuInfo gpu,
  }) {
    String? pick(List<String> keys) {
      for (final k in keys) {
        final v = socIdentity[k]?.trim();
        if (v != null && v.isNotEmpty) return v;
      }
      return null;
    }

    final model = pick([
      'build_soc_model',
      'prop_ro.soc.model',
    ]);

    final manufacturerRaw = pick([
      'build_soc_manufacturer',
      'prop_ro.soc.manufacturer',
    ]);

    final chain = socIdentity['soc_chip_candidates_ordered']?.trim();

    return SiliconOverview(
      socModel: model,
      socManufacturer: _friendlySocManufacturer(manufacturerRaw),
      gpu: gpu,
      candidateChain:
          chain != null && chain.isNotEmpty ? chain : null,
    );
  }

  factory SiliconOverview.fromJson(Map<Object?, Object?>? m) {
    if (m == null) {
      return SiliconOverview(gpu: const GpuInfo(api: 'unavailable'));
    }
    return SiliconOverview(
      socModel: m['socModel']?.toString(),
      socManufacturer: _friendlySocManufacturer(m['socManufacturer']?.toString()),
      gpu: GpuInfo.fromMap(m['gpu'] as Map<Object?, Object?>?),
      candidateChain: m['candidateChain']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (socModel != null) 'socModel': socModel,
        if (socManufacturer != null) 'socManufacturer': socManufacturer,
        'gpu': gpu.toJson(),
        if (candidateChain != null) 'candidateChain': candidateChain,
      };
}

/// [CpuInfoPlus.getCpuInfoReport] 的强类型视图（面向展示的摘要，无原始调试 Map）。
///
/// 底层仍以原生聚合结果注入 [siliconOverview]。
class FullCpuInfo {
  const FullCpuInfo({
    required this.platform,
    this.apiLevel,
    required this.abis,
    required this.logicalProcessorCount,
    required this.physicalProcessorCount,
    required this.hardwareSummary,
    required this.frequencySnapshot,
    required this.gpuInfo,
    required this.siliconOverview,
  });

  /// 如 `android` / `ios`。
  final String platform;

  /// Android [Build.VERSION.SDK_INT]；其他平台可能为 null。
  final int? apiLevel;

  final List<String> abis;
  final int logicalProcessorCount;
  final int physicalProcessorCount;

  final CpuHardwareSummary hardwareSummary;
  final CpuFrequencySnapshot frequencySnapshot;

  final GpuInfo gpuInfo;

  /// 芯片代号 / SoC 制造商 / GPU 摘要（插件侧合并）。
  final SiliconOverview siliconOverview;

  /// 解析插件内部合并后的完整 map（含 `siliconOverview`）。
  factory FullCpuInfo.fromMergedMap(Map<String, dynamic> m) {
    final gpu = GpuInfo.fromMap(m['gpuInfo'] as Map<Object?, Object?>?);
    final soc = _stringMapFromNested(m['socIdentity']);
    final silicon =
        m['siliconOverview'] != null
            ? SiliconOverview.fromJson(m['siliconOverview'] as Map<Object?, Object?>?)
            : SiliconOverview.compose(socIdentity: soc, gpu: gpu);

    return FullCpuInfo(
      platform: m['platform']?.toString() ?? 'unknown',
      apiLevel: _asInt(m['apiLevel']),
      abis: _stringList(m['abis']),
      logicalProcessorCount: _asInt(m['logicalProcessorCount']) ?? 0,
      physicalProcessorCount: _asInt(m['physicalProcessorCount']) ?? 0,
      hardwareSummary: CpuHardwareSummary.fromMap(_nestedAsMap(m['hardwareSummary'])),
      frequencySnapshot: CpuFrequencySnapshot.fromMap(_nestedAsMap(m['frequencySnapshot'])),
      gpuInfo: gpu,
      siliconOverview: silicon,
    );
  }
}

Map<Object?, Object?> _nestedAsMap(Object? v) {
  if (v is! Map) return const {};
  return v.map((k, val) => MapEntry(k, val));
}

List<String> _stringList(Object? v) {
  if (v is! List) return const [];
  return v.map((e) => e.toString()).toList();
}

Map<String, String> _stringMapFromNested(Object? v) {
  if (v is! Map) return const {};
  return {
    for (final e in v.entries)
      e.key.toString(): e.value?.toString() ?? '',
  };
}

/// 一次 CPU/GPU 频率采样（与原生 sysfs / sysctl 一致：CPU 列表单位为 **kHz**）。
class FrequencyTelemetry {
  const FrequencyTelemetry({
    required this.cpu,
    this.gpuCurrentKhz,
    this.gpuFreqSource,
    required this.epochMillis,
    this.platform,
    this.error,
  });

  final CpuFrequencySnapshot cpu;
  final int? gpuCurrentKhz;

  /// Android：成功读取 GPU 频率时的 sysfs 路径，便于确认机型节点；为 null 多为 SELinux 禁止或无对应节点。
  final String? gpuFreqSource;
  final int epochMillis;
  final String? platform;
  final String? error;

  factory FrequencyTelemetry.fromMap(Map<String, dynamic> m) {
    final cpuOnly = <String, dynamic>{
      'minHzPerCpu': m['minHzPerCpu'],
      'maxHzPerCpu': m['maxHzPerCpu'],
      'currentHzPerCpu': m['currentHzPerCpu'],
    };
    return FrequencyTelemetry(
      cpu: CpuFrequencySnapshot.fromMap(cpuOnly),
      gpuCurrentKhz: _asInt(m['gpuCurrentKhz']),
      gpuFreqSource: m['gpuFreqSource']?.toString(),
      epochMillis: _asInt(m['epochMillis']) ?? DateTime.now().millisecondsSinceEpoch,
      platform: m['platform']?.toString(),
      error: m['error']?.toString(),
    );
  }
}
