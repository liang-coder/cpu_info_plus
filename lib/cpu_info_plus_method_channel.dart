import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'cpu_info_plus_platform_interface.dart';
import 'src/cpu_info_models.dart';

/// An implementation of [CpuInfoPlusPlatform] that uses method channels.
class MethodChannelCpuInfoPlus extends CpuInfoPlusPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('cpu_info_plus');

  static const EventChannel _frequencyStream = EventChannel('cpu_info_plus/frequency_stream');

  @override
  Future<String?> getPlatformVersion() async {
    return methodChannel.invokeMethod<String>('getPlatformVersion');
  }

  @override
  Future<int> getLogicalProcessorCount() async {
    final v = await methodChannel.invokeMethod<int>('getLogicalProcessorCount');
    return v ?? 0;
  }

  @override
  Future<int> getPhysicalProcessorCount() async {
    final v = await methodChannel.invokeMethod<int>('getPhysicalProcessorCount');
    return v ?? 0;
  }

  @override
  Future<List<String>> getSupportedAbis() async {
    final raw = await methodChannel.invokeMethod<List<dynamic>>('getSupportedAbis');
    if (raw == null) return const [];
    return raw.map((e) => e.toString()).toList();
  }

  @override
  Future<CpuHardwareSummary> getCpuHardwareSummary() async {
    final raw = await methodChannel.invokeMethod<Map<Object?, Object?>>('getCpuHardwareSummary');
    return CpuHardwareSummary.fromMap(raw ?? const {});
  }

  @override
  Future<CpuFrequencySnapshot> getCpuFrequencySnapshot() async {
    final raw = await methodChannel.invokeMethod<Map<Object?, Object?>>('getCpuFrequencySnapshot');
    return CpuFrequencySnapshot.fromMap(raw ?? const {});
  }

  @override
  Future<Map<String, String>> getCpuDetailedProperties() async {
    final raw = await methodChannel.invokeMethod<Map<Object?, Object?>>('getCpuDetailedProperties');
    return _stringMap(raw);
  }

  @override
  Future<Map<String, dynamic>> getAllCpuInfo() async {
    final raw = await methodChannel.invokeMethod<Map<Object?, Object?>>('getAllCpuInfo');
    return Map<String, dynamic>.from(raw ?? const {});
  }

  @override
  Future<Map<String, String>> getSocIdentity() async {
    final raw = await methodChannel.invokeMethod<Map<Object?, Object?>>('getSocIdentity');
    return _stringMap(raw);
  }

  @override
  Future<GpuInfo> getGpuInfo() async {
    final raw = await methodChannel.invokeMethod<Map<Object?, Object?>>('getGpuInfo');
    return GpuInfo.fromMap(raw);
  }

  @override
  Stream<FrequencyTelemetry> watchFrequencyTelemetry({
    Duration interval = const Duration(seconds: 1),
  }) {
    // 单次 getFrequencyTelemetryOnce 含 CPU 全核 + GPU；桌面/Web 仅使用一个 Timer.periodic。
    final ms = interval.inMilliseconds.clamp(250, 10000);
    final dur = Duration(milliseconds: ms);
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.windows) {
      return _pollingTelemetryStream(dur);
    }
    return _frequencyStream.receiveBroadcastStream(<String, dynamic>{
      'intervalMs': ms,
    }).map((dynamic e) {
      final map = Map<String, dynamic>.from(e as Map);
      return FrequencyTelemetry.fromMap(map);
    });
  }

  /// Linux / Windows / Web：单个周期 Timer，每次一次 MethodChannel（CPU+GPU 同台快照）。
  Stream<FrequencyTelemetry> _pollingTelemetryStream(Duration interval) {
    late final StreamController<FrequencyTelemetry> controller;
    Timer? timer;
    controller = StreamController<FrequencyTelemetry>(
      onListen: () {
        Future<void> tick() async {
          try {
            final raw = await methodChannel.invokeMethod<Map<Object?, Object?>>('getFrequencyTelemetryOnce');
            if (controller.isClosed) return;
            controller.add(
              FrequencyTelemetry.fromMap(Map<String, dynamic>.from(raw ?? const {})),
            );
          } catch (_) {
            if (!controller.isClosed) {
              controller.add(
                FrequencyTelemetry(
                  cpu: const CpuFrequencySnapshot(
                    minHzPerCpu: [],
                    maxHzPerCpu: [],
                    currentHzPerCpu: [],
                  ),
                  epochMillis: DateTime.now().millisecondsSinceEpoch,
                  error: 'getFrequencyTelemetryOnce unavailable',
                ),
              );
            }
          }
        }

        scheduleMicrotask(tick);
        timer = Timer.periodic(interval, (_) => tick());
      },
      onCancel: () {
        timer?.cancel();
        timer = null;
      },
    );
    return controller.stream;
  }

  Map<String, String> _stringMap(Map<Object?, Object?>? raw) {
    if (raw == null) return const {};
    final out = <String, String>{};
    for (final e in raw.entries) {
      final k = e.key?.toString();
      final v = e.value?.toString();
      if (k == null || v == null) continue;
      out[k] = v;
    }
    return out;
  }
}
