# cpu_info_plus

**[简体中文](README_CN.md)**

Flutter plugin: a cross-platform wrapper for **Flutter** apps that exposes **whole-device hardware summary**, **SoC / GPU summary**, and **instantaneous or continuous frequencies** through a single Dart API. All frequency values use **kHz** (aligned with common Linux `cpufreq` sysfs usage). Where the OS allows, the plugin can provide live samples for **each CPU core and GPU** (see platform table).

---

### Features at a glance

| Area | What you get |
|------|----------------|
| CPU | Logical / physical core counts, supported ABI, min/max/current **snapshots** for frequency (Android `/proc/cpuinfo` or Apple sysctl side, as used for snapshots). |
| SoC / GPU | **`SiliconOverview`**: chip model hints, SoC vendor display name, **`GpuInfo`** (OpenGL ES / Metal strings). On Qualcomm devices the OS often reports **`QTI` / `qcom`**; the plugin maps these to **`Qualcomm`** for display. |
| Frequencies | **`getCpuFrequencySnapshot()`** one-shot; **`watchFrequencyTelemetry`** emits **`FrequencyTelemetry`** (per-core current/min/max and optional GPU current frequency). |
| Recommended entry points | **`getCpuInfoReport()` → `FullCpuInfo`** for a structured full report; **`getSiliconOverview()`** when you only need the summary. |

### When to use it

- Device info / “About this device”, performance dashboards
- Showing best-effort SoC strings (Snapdragon / Dimensity, etc.) **as exposed by the system**
- Periodically refreshing CPU (and GPU on Android when available) current frequencies

### Platform capability matrix (high level)

Behaviour depends on **SELinux**, **OEM cuts**, and **Apple not exposing stable GPU clock** to apps. Treat the table as indicative.

| Capability | Android | iOS | macOS | Linux | Windows | Web |
|------------|:-------:|:---:|:-----:|:-----:|:-------:|:---:|
| Logical / physical cores | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ (matches engine) |
| ABI / architecture list | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `CpuHardwareSummary` | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ stub |
| SoC + GPU summary `SiliconOverview` / `FullCpuInfo` | ✅ | ✅ | ✅ | ⚠️ | ⚠️ | ⚠️ |
| `GpuInfo` (vendor / renderer, …) | ✅ | ✅ | ✅ | ⚠️ | ⚠️ | ⚠️ (WebGL context) |
| `getCpuFrequencySnapshot()` | ✅ sysfs | ✅ sysctl (whole-package style) | ✅ | ⚠️ | ⚠️ | ❌ |
| `watchFrequencyTelemetry` | ✅ EventChannel + background sysfs read | ✅ main-thread Timer | ✅ Timer | ⚠️ MethodChannel polling | ⚠️ same | ❌ empty stream |
| **GPU current frequency** in stream | ⚠️ device sysfs / SELinux | ❌ | ❌ | ❌ | ❌ | ❌ |

**Legend:** ✅ broadly usable · ⚠️ partial / stub · ❌ not available or always empty

### Installation

```yaml
dependencies:
  cpu_info_plus: ^0.0.3   # replace with the published version on pub.dev
  # path dependency example:
  # cpu_info_plus:
  #   path: ../cpu_info_plus
```

```bash
flutter pub get
```

### Plugin initialization & instantiation

1. **Plugin initialization**

   ```dart
   late final CpuInfoPlus _cpuInfo = CpuInfoPlus();
   ```

---

### API: `CpuInfoPlus`

| Method | Returns | Notes |
|--------|---------|-------|
| `getPlatformVersion()` | `Future<String?>` | OS version description. |
| `getLogicalProcessorCount()` | `Future<int>` | Logical processor count. |
| `getPhysicalProcessorCount()` | `Future<int>` | Physical cores (best-effort). |
| `getSupportedAbis()` | `Future<List<String>>` | Android: `SUPPORTED_ABIS`; Apple: e.g. `arm64`. |
| `getCpuHardwareSummary()` | `Future<CpuHardwareSummary>` | Manufacturer, model, board, hardware, machine, … |
| `getCpuFrequencySnapshot()` | `Future<CpuFrequencySnapshot>` | Per-CPU min/max/current (**kHz**), **one-shot** snapshot. |
| `getGpuInfo()` | `Future<GpuInfo>` | GLES / Metal strings. |
| `getSiliconOverview()` | `Future<SiliconOverview>` | **Recommended**: chip codename, display-friendly SoC vendor, GPU summary. |
| `getCpuInfoReport()` | `Future<FullCpuInfo>` | **Recommended**: full device report (includes `siliconOverview`). |
| `watchFrequencyTelemetry({interval})` | `Stream<FrequencyTelemetry>` | Live frequency stream; cancel subscription to stop sampling. |

### Main data models (`lib/src/cpu_info_models.dart`)

| Type | Main fields / role |
|------|---------------------|
| `CpuHardwareSummary` | `manufacturer`, `model`, `hardware`, `machine`, … |
| `CpuFrequencySnapshot` | `minHzPerCpu`, `maxHzPerCpu`, `currentHzPerCpu` (`List<int?>`) |
| `GpuInfo` | `api`, `vendor`, `renderer`, `displayLine` |
| `SiliconOverview` | `socModel`, `socManufacturer`, `gpu`, `candidateChain` |
| `FullCpuInfo` | `platform`, `apiLevel`, `abis`, core counts, `hardwareSummary`, `frequencySnapshot`, `gpuInfo`, `siliconOverview` |
| `FrequencyTelemetry` | `cpu` (snapshot), `gpuCurrentKhz`, `gpuFreqSource` (Android sysfs path when read succeeds), `epochMillis`, `error` |

---

### Usage examples (one snippet per public method)

Assume:

```dart
import 'package:cpu_info_plus/cpu_info_plus.dart';

// Reuse from State / a service
final CpuInfoPlus plugin = CpuInfoPlus();
```

#### 1. `getPlatformVersion()` — OS version string

```dart
final String? os = await plugin.getPlatformVersion();
debugPrint(os ?? '—'); // e.g. Android 13 / iOS 17.x
```

#### 2. `getLogicalProcessorCount()` — logical CPU count

```dart
final int logical = await plugin.getLogicalProcessorCount();
debugPrint('logical cores: $logical');
```

#### 3. `getPhysicalProcessorCount()` — physical core count (estimate)

```dart
final int physical = await plugin.getPhysicalProcessorCount();
debugPrint('physical cores: $physical');
```

#### 4. `getSupportedAbis()` — supported ABI / architecture list

```dart
final List<String> abis = await plugin.getSupportedAbis();
debugPrint(abis.join(', ')); // Android: often arm64-v8a; Apple: often arm64
```

#### 5. `getCpuHardwareSummary()` — device / Build summary

```dart
final CpuHardwareSummary hw = await plugin.getCpuHardwareSummary();
debugPrint('${hw.manufacturer} · ${hw.model} · ${hw.hardware} · ${hw.machine}');
```

#### 6. `getCpuFrequencySnapshot()` — per-CPU frequency snapshot (kHz, not a live stream)

```dart
final CpuFrequencySnapshot freq = await plugin.getCpuFrequencySnapshot();
for (var i = 0; i < freq.currentHzPerCpu.length; i++) {
  debugPrint(
    'CPU$i cur ${freq.currentHzPerCpu[i]} · min ${freq.minHzPerCpu[i]} · max ${freq.maxHzPerCpu[i]} kHz',
  );
}
```

#### 7. `getGpuInfo()` — GPU strings (OpenGL ES / Metal)

```dart
final GpuInfo gpu = await plugin.getGpuInfo();
debugPrint('${gpu.api} · ${gpu.vendor} · ${gpu.renderer}');
debugPrint(gpu.displayLine); // one-line summary
```

#### 8. `getSiliconOverview()` — SoC + GPU summary (recommended)

```dart
final SiliconOverview o = await plugin.getSiliconOverview();
debugPrint('SoC: ${o.socModel} · vendor: ${o.socManufacturer}');
debugPrint(o.gpu.displayLine);
debugPrint('candidate chain: ${o.candidateChain}');
```

#### 9. `getCpuInfoReport()` — structured full report (recommended)

```dart
final FullCpuInfo report = await plugin.getCpuInfoReport();
debugPrint('platform: ${report.platform} · API: ${report.apiLevel}');
debugPrint('ABI: ${report.abis.join(' / ')}');
debugPrint('cores: logical ${report.logicalProcessorCount} · physical ${report.physicalProcessorCount}');
debugPrint(report.siliconOverview.gpu.displayLine);
```

#### 10. `watchFrequencyTelemetry()` — live CPU/GPU frequencies (`Stream`)

**Option A — `StreamBuilder` (recommended for UI; auto-cancel on dispose)**

```dart
StreamBuilder<FrequencyTelemetry>(
  stream: plugin.watchFrequencyTelemetry(
    interval: const Duration(seconds: 1),
  ),
  builder: (context, snapshot) {
    final t = snapshot.data;
    if (t == null) return const CircularProgressIndicator();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('GPU current: ${t.gpuCurrentKhz ?? '—'} kHz'),
        if (t.gpuFreqSource != null) Text('node: ${t.gpuFreqSource}'),
        ...List.generate(t.cpu.currentHzPerCpu.length, (i) {
          final c = t.cpu.currentHzPerCpu[i];
          return Text('CPU$i: ${c ?? '—'} kHz');
        }),
      ],
    );
  },
);
```

**Option B — `listen` (cancel in `dispose`)**

```dart
import 'dart:async'; // StreamSubscription

class _DemoState extends State<DemoPage> {
  late final CpuInfoPlus _plugin = CpuInfoPlus();
  StreamSubscription<FrequencyTelemetry>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = _plugin.watchFrequencyTelemetry().listen((t) {
      debugPrint('GPU ${t.gpuCurrentKhz} kHz · epoch ${t.epochMillis}');
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
```

For more UI combinations, see **`example/`** (`cd example && flutter run`).

### Limitations & platform differences (FAQ)

1. **Apple (iOS / macOS)**: there is **no stable public GPU clock** API for third-party apps; **`gpuCurrentKhz`** is usually **`null`**.
2. **Android GPU frequency**: depends on `kgsl` / `devfreq` nodes; many builds **deny sysfs** to normal apps (SELinux)—expected.
3. **SoC vendor shown as QTI**: system fields often use Qualcomm’s **QTI** abbreviation; **`SiliconOverview`** maps it to **Qualcomm** for display.
4. **Desktop / Web**: Linux, Windows, and Web may return stubs or simplified data; the Web frequency stream is empty.
