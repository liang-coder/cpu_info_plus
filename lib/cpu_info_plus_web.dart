// In order to *not* need this ignore, consider extracting the "web" version
// of your plugin as a separate package, instead of inlining it in the same
// package as the core of the plugin.
// ignore: avoid_web_libraries_in_flutter

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import 'cpu_info_plus_platform_interface.dart';
import 'src/cpu_info_models.dart';

/// Web 实现：浏览器不暴露底层 CPU sysfs / SoC 属性；GPU 需 WebGL 上下文方可读取渲染器字符串。
class CpuInfoPlusWeb extends CpuInfoPlusPlatform {
  CpuInfoPlusWeb();

  static void registerWith(Registrar registrar) {
    CpuInfoPlusPlatform.instance = CpuInfoPlusWeb();
  }

  @override
  Future<String?> getPlatformVersion() async {
    return web.window.navigator.userAgent;
  }

  @override
  Future<int> getLogicalProcessorCount() async {
    return web.window.navigator.hardwareConcurrency;
  }

  @override
  Future<int> getPhysicalProcessorCount() async {
    return getLogicalProcessorCount();
  }

  @override
  Future<List<String>> getSupportedAbis() async {
    return const ['web'];
  }

  @override
  Future<CpuHardwareSummary> getCpuHardwareSummary() async {
    return const CpuHardwareSummary(
      manufacturer: null,
      brand: null,
      device: null,
      model: null,
      board: null,
      hardware: null,
      product: null,
      machine: null,
    );
  }

  @override
  Future<CpuFrequencySnapshot> getCpuFrequencySnapshot() async {
    return const CpuFrequencySnapshot(
      minHzPerCpu: [],
      maxHzPerCpu: [],
      currentHzPerCpu: [],
    );
  }

  @override
  Future<Map<String, String>> getCpuDetailedProperties() async {
    return const {};
  }

  @override
  Future<Map<String, String>> getSocIdentity() async {
    return {
      'note_cpu_implementer': '浏览器无法读取 Android ro.soc.* 或 cpuinfo；CPU 实现者信息不可用。',
      'note_chip_hint': '仅作占位；真实环境请使用 Android / iOS 原生端。',
    };
  }

  @override
  Future<GpuInfo> getGpuInfo() async {
    return const GpuInfo(
      api: 'Web',
      note: '未创建 WebGL 上下文；无法解析 RENDERER/VENDOR（可在应用内用 dart:js_interop 自行扩展）。',
    );
  }

  @override
  Stream<FrequencyTelemetry> watchFrequencyTelemetry({
    Duration interval = const Duration(seconds: 1),
  }) {
    return Stream<FrequencyTelemetry>.empty();
  }

  @override
  Future<Map<String, dynamic>> getAllCpuInfo() async {
    final logical = await getLogicalProcessorCount();
    return {
      'platform': 'web',
      'abis': await getSupportedAbis(),
      'logicalProcessorCount': logical,
      'physicalProcessorCount': logical,
      'hardwareSummary': (await getCpuHardwareSummary()).toJson(),
      'frequencySnapshot': (await getCpuFrequencySnapshot()).toJson(),
      'detailedProperties': await getCpuDetailedProperties(),
      'socIdentity': await getSocIdentity(),
      'gpuInfo': (await getGpuInfo()).toJson(),
    };
  }
}
