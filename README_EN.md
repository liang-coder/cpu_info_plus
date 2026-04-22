# cpu_info_plus

**[简体中文](README.md)**

A **Flutter plugin** that exposes **CPU/GPU-related device information** and, where the operating system allows it, **live CPU (per-core) and GPU current frequencies** on **Android, iOS, macOS, Linux, Windows, and Web**. All frequency values use **kHz**, consistent with common Linux `cpufreq` sysfs conventions.

---

### Features at a glance

| Area | What you get |
|------|----------------|
| CPU | Logical / physical core counts, supported ABIs, min/max/current **snapshots** per policy (Android sysfs / Apple sysctl where available). |
| SoC / GPU | **`SiliconOverview`**: model hints, SoC vendor display name, and **`GpuInfo`** (OpenGL ES on Android, Metal on Apple). On Qualcomm devices the OS often reports **`QTI` / `qcom`**; the plugin maps these to **`Qualcomm`** for display. |
| Live telemetry | **`watchFrequencyTelemetry`** emits **`FrequencyTelemetry`** on a timer / EventChannel: per-CPU lists + optional GPU current frequency on Android when sysfs is readable. |
| Recommended APIs | **`getCpuInfoReport()` → `FullCpuInfo`** for a structured report; **`getSiliconOverview()`** when you only need the chip + GPU summary. |

### When to use it

- “About this device”, hardware info screens, performance dashboards  
- Showing best-effort SoC model strings **as exposed by the OEM / OS**  
- Monitoring CPU (and sometimes GPU on Android) frequencies over time  

### Platform capability matrix (high level)

Behaviour depends on **SELinux**, **vendor sysfs paths**, and **Apple not exposing GPU clock** to apps. Treat the table as indicative.

| Capability | Android | iOS | macOS | Linux | Windows | Web |
|------------|:-------:|:---:|:-----:|:-----:|:-------:|:---:|
| Logical / physical cores | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| ABI / architecture list | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `CpuHardwareSummary` | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ stub |
| `SiliconOverview` / `FullCpuInfo` | ✅ | ✅ | ✅ | ⚠️ | ⚠️ | ⚠️ |
| `GpuInfo` strings | ✅ | ✅ | ✅ | ⚠️ | ⚠️ | ⚠️ (WebGL context) |
| `getCpuFrequencySnapshot()` | ✅ sysfs | ✅ sysctl (whole-package style) | ✅ | ⚠️ | ⚠️ | ❌ |
| `watchFrequencyTelemetry` | ✅ EventChannel | ✅ Timer | ✅ Timer | ⚠️ polling | ⚠️ polling | ❌ empty stream |
| **GPU current frequency** in stream | ⚠️ sysfs / SELinux | ❌ | ❌ | ❌ | ❌ | ❌ |

**Legend:** ✅ broadly usable · ⚠️ partial / stub · ❌ not available or always empty  

### Architecture notes

- **Android / iOS / macOS**: live samples use an **`EventChannel`** (`cpu_info_plus/frequency_stream`). Native code reads sysfs (Android) or sysctl (Apple) off the UI thread where applicable, then delivers maps on the main isolate.  
- **Linux / Windows / Web**: when EventChannel is not used, Dart runs a **single** `Timer.periodic` and calls **`getFrequencyTelemetryOnce`** each tick—one snapshot containing **both** CPU clusters and GPU (if readable).  
- **Interval**: default **`Duration(seconds: 1)`**; the native side clamps **`intervalMs`** to **250–10000** ms.  

### Installation

```yaml
dependencies:
  cpu_info_plus: ^0.0.1   # replace with the published version on pub.dev
  # path dependency example:
  # cpu_info_plus:
  #   path: ../cpu_info_plus
```

```bash
flutter pub get
```

Most APIs do **not** require dangerous permissions. Empty GPU frequency or sysfs reads usually reflect **OS policy** (e.g. SELinux), not missing storage/phone permissions.

### Plugin setup & lifecycle

1. **No manual native registration**  
   A standard Flutter app registers plugins via **`GeneratedPluginRegistrant.registerWith`** at startup. You normally **do not** add extra init code in `MainActivity` / `AppDelegate` for `CpuInfoPlus`.

2. **No separate `init()` API**  
   Communication uses **MethodChannel / EventChannel**. After **`import`** and **`CpuInfoPlus()`**, you can call async methods immediately.

3. **Reuse one instance**  
   Keep a single **`CpuInfoPlus`** in `StatefulWidget` state, a service locator (`GetIt`), or `Riverpod`, for example:
   ```dart
   late final CpuInfoPlus _cpuInfo = CpuInfoPlus();
   ```

4. **`WidgetsFlutterBinding.ensureInitialized()`**  
   Only needed when you invoke plugins **before** `runApp()` (e.g. synchronous `main()` probes). Ordinary async calls from widgets **do not** require it.

5. **Tests**  
   Call **`TestWidgetsFlutterBinding.ensureInitialized()`** in widget/unit tests before hitting platform channels (`flutter_test` docs).

6. **Live frequency stream**  
   **`watchFrequencyTelemetry`** returns a **`Stream`**. **`cancel()`** the **`StreamSubscription`** in **`dispose`**, or use **`StreamBuilder`** so the subscription ends when the widget is disposed.

---

### API: `CpuInfoPlus`

| Method | Returns | Notes |
|--------|---------|-------|
| `getPlatformVersion()` | `Future<String?>` | Human-readable OS version string. |
| `getLogicalProcessorCount()` | `Future<int>` | Logical CPUs visible to the Dart VM. |
| `getPhysicalProcessorCount()` | `Future<int>` | Best-effort physical cores. |
| `getSupportedAbis()` | `Future<List<String>>` | Android: `Build.SUPPORTED_ABIS`; Apple: typically one arch label (e.g. `arm64`). |
| `getCpuHardwareSummary()` | `Future<CpuHardwareSummary>` | Manufacturer, model, board, hardware, machine, … |
| `getCpuFrequencySnapshot()` | `Future<CpuFrequencySnapshot>` | Per-CPU min/max/current **in kHz** (one-shot). |
| `getGpuInfo()` | `Future<GpuInfo>` | GLES / Metal vendor & renderer strings. |
| `getSiliconOverview()` | `Future<SiliconOverview>` | **Recommended** chip summary + GPU line. |
| `getCpuInfoReport()` | `Future<FullCpuInfo>` | **Recommended** structured full report. |
| `watchFrequencyTelemetry({interval})` | `Stream<FrequencyTelemetry>` | Live telemetry; cancel the subscription to stop sampling. |

### Main data models (`lib/src/cpu_info_models.dart`)

| Type | Role |
|------|------|
| `CpuHardwareSummary` | Device / Build identifiers. |
| `CpuFrequencySnapshot` | `minHzPerCpu`, `maxHzPerCpu`, `currentHzPerCpu`. |
| `GpuInfo` | `api`, `vendor`, `renderer`, `displayLine`. |
| `SiliconOverview` | `socModel`, `socManufacturer` (display-friendly), `gpu`, `candidateChain`. |
| `FullCpuInfo` | Bundles platform, ABI, counts, summaries, `siliconOverview`. |
| `FrequencyTelemetry` | `cpu` snapshot, `gpuCurrentKhz`, optional `gpuFreqSource` (Android sysfs path when successful), `epochMillis`, `error`. |

---

### Complete API samples (every public method)

Assume:

```dart
import 'package:cpu_info_plus/cpu_info_plus.dart';

final CpuInfoPlus plugin = CpuInfoPlus(); // reuse in State/service
```

#### 1. `getPlatformVersion()`

```dart
final String? os = await plugin.getPlatformVersion();
print(os);
```

#### 2. `getLogicalProcessorCount()`

```dart
final int logical = await plugin.getLogicalProcessorCount();
print('logical CPUs: $logical');
```

#### 3. `getPhysicalProcessorCount()`

```dart
final int physical = await plugin.getPhysicalProcessorCount();
print('physical CPUs: $physical');
```

#### 4. `getSupportedAbis()`

```dart
final List<String> abis = await plugin.getSupportedAbis();
print(abis.join(', '));
```

#### 5. `getCpuHardwareSummary()`

```dart
final CpuHardwareSummary hw = await plugin.getCpuHardwareSummary();
print('${hw.manufacturer} · ${hw.model} · ${hw.hardware} · ${hw.machine}');
```

#### 6. `getCpuFrequencySnapshot()` (kHz; one-shot, not live)

```dart
final CpuFrequencySnapshot freq = await plugin.getCpuFrequencySnapshot();
for (var i = 0; i < freq.currentHzPerCpu.length; i++) {
  print(
    'CPU$i cur=${freq.currentHzPerCpu[i]} min=${freq.minHzPerCpu[i]} max=${freq.maxHzPerCpu[i]} kHz',
  );
}
```

#### 7. `getGpuInfo()`

```dart
final GpuInfo gpu = await plugin.getGpuInfo();
print('${gpu.api} · ${gpu.vendor} · ${gpu.renderer}');
print(gpu.displayLine);
```

#### 8. `getSiliconOverview()` (recommended summary)

```dart
final SiliconOverview o = await plugin.getSiliconOverview();
print('${o.socModel} · ${o.socManufacturer}');
print(o.gpu.displayLine);
print(o.candidateChain);
```

#### 9. `getCpuInfoReport()` (recommended full report)

```dart
final FullCpuInfo report = await plugin.getCpuInfoReport();
print(report.platform);
print(report.abis);
print(report.siliconOverview.gpu.displayLine);
```

#### 10. `watchFrequencyTelemetry()` (live stream)

**Option A — `StreamBuilder`**

```dart
StreamBuilder<FrequencyTelemetry>(
  stream: plugin.watchFrequencyTelemetry(
    interval: const Duration(seconds: 1),
  ),
  builder: (context, snapshot) {
    final t = snapshot.data;
    if (t == null) return const CircularProgressIndicator();
    return Column(
      children: [
        Text('GPU ${t.gpuCurrentKhz ?? '—'} kHz'),
        ...List.generate(t.cpu.currentHzPerCpu.length, (i) {
          return Text('CPU$i ${t.cpu.currentHzPerCpu[i]} kHz');
        }),
      ],
    );
  },
);
```

**Option B — `listen` + cancel in `dispose`**

```dart
import 'dart:async'; // StreamSubscription

class _DemoState extends State<DemoPage> {
  late final CpuInfoPlus _plugin = CpuInfoPlus();
  StreamSubscription<FrequencyTelemetry>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = _plugin.watchFrequencyTelemetry().listen((t) {
      debugPrint('GPU ${t.gpuCurrentKhz} kHz');
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

#### Run all **`Future`** APIs once (excluding `Stream`)

```dart
Future<void> runAllCpuInfoFutures(CpuInfoPlus p) async {
  await p.getPlatformVersion();
  await p.getLogicalProcessorCount();
  await p.getPhysicalProcessorCount();
  await p.getSupportedAbis();
  await p.getCpuHardwareSummary();
  await p.getCpuFrequencySnapshot();
  await p.getGpuInfo();
  await p.getSiliconOverview();
  await p.getCpuInfoReport();
}
```

See **`example/`** for a runnable app (`cd example && flutter run`).

### Limitations & troubleshooting

1. **Apple platforms**: there is **no stable public GPU clock** for third-party apps; **`gpuCurrentKhz`** is usually **`null`**.  
2. **Android GPU frequency**: requires readable sysfs (`kgsl`, `devfreq`, …); many production builds **block** untrusted apps—expected behaviour.  
3. **Vendor strings**: Qualcomm devices often report **`QTI`** in `Build.SOC_MANUFACTURER`; the plugin normalises to **Qualcomm** in **`SiliconOverview`**.  
4. **Desktop / Web**: Linux, Windows, and Web implementations may return stubs; the Web frequency stream is empty.  

### License

See **`LICENSE`** in the repository root.
