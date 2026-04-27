# cpu_info_plus

**[English](README.md)**

Flutter 插件：面向 **Flutter** 应用的跨平台封装，通过一套 Dart API 访问原生侧聚合好的 **整机硬件摘要**、**SoC / GPU 摘要**、**瞬时或持续频率**。频率相关数值单位统一为 **kHz**（与 Linux `cpufreq` sysfs 常见写法一致）；在操作系统允许的前提下，可提供 **CPU 各核及 GPU** 的实时采样（详见平台表）。

---

### 功能概览

| 类别 | 说明 |
|------|------|
| 处理器 | 逻辑/物理核心数、支持的 ABI、`/proc/cpuinfo`（Android）或 sysctl（Apple）侧用于频率快照的档位等。 |
| SoC / GPU | `SiliconOverview`：芯片型号线索、SoC 制造商展示名、`GpuInfo`（OpenGL ES / Metal 字符串）。高通机型系统常返回 `QTI`/`qcom`，插件在展示层映射为 **Qualcomm**。 |
| 频率 | `getCpuFrequencySnapshot()` 单次快照；`watchFrequencyTelemetry` 持续推送 `FrequencyTelemetry`（含各核 current/min/max 与可选 GPU 当前频率）。 |
| 推荐入口 | **`getCpuInfoReport()` → `FullCpuInfo`**（结构化整机报告）；仅需摘要时用 **`getSiliconOverview()`**。 |

### 适用场景

- 设备信息页、关于本机、性能监视面板  
- 展示骁龙 / 天玑等平台可读型号线索（依赖系统暴露字段）  
- 周期性刷新 CPU（及 Android 上可能可用的 GPU）当前频率  

### 支持平台与能力（摘要）

具体行为受 **SELinux**、**OEM 裁剪**、**Apple 未公开 GPU 主频** 等影响；下表为经验性对照。

| 能力 | Android | iOS | macOS | Linux | Windows | Web |
|------|:-------:|:---:|:-----:|:-----:|:-------:|:---:|
| 逻辑 / 物理核心数 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅（与引擎一致） |
| ABI / 架构列表 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `CpuHardwareSummary` | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ 占位 |
| SoC + GPU 摘要 `SiliconOverview` / `FullCpuInfo` | ✅ | ✅ | ✅ | ⚠️ | ⚠️ | ⚠️ |
| `GpuInfo`（Vendor / Renderer 等） | ✅ | ✅ | ✅ | ⚠️ | ⚠️ | ⚠️（WebGL 上下文） |
| `getCpuFrequencySnapshot()` | ✅ sysfs | ✅ sysctl（整机档） | ✅ | ⚠️ | ⚠️ | ❌ |
| `watchFrequencyTelemetry` | ✅ EventChannel + 后台读 sysfs | ✅ 主线程 Timer | ✅ Timer | ⚠️ MethodChannel 轮询 | ⚠️ 同上 | ❌ 空流 |
| 实时流中的 **GPU 当前频率** | ⚠️ 视机型 sysfs/SELinux | ❌ | ❌ | ❌ | ❌ | ❌ |

**图例：** ✅ 较完整 · ⚠️ 部分或占位 · ❌ 不提供或恒为空  

### 安装

```yaml
dependencies:
  cpu_info_plus: ^0.0.3   # 请替换为 pub.dev 上实际版本
  # 本地路径集成示例：
  # cpu_info_plus:
  #   path: ../cpu_info_plus
```

```bash
flutter pub get
```


### 插件初始化与实例化

1. **插件初始化**  
   ```dart
   late final CpuInfoPlus _cpuInfo = CpuInfoPlus();
   ```

---

### API：`CpuInfoPlus`

| 方法 | 返回 | 说明 |
|------|------|------|
| `getPlatformVersion()` | `Future<String?>` | 系统版本描述。 |
| `getLogicalProcessorCount()` | `Future<int>` | 逻辑处理器数。 |
| `getPhysicalProcessorCount()` | `Future<int>` | 物理核心数（尽力值）。 |
| `getSupportedAbis()` | `Future<List<String>>` | Android：`SUPPORTED_ABIS`；Apple：如 `arm64`。 |
| `getCpuHardwareSummary()` | `Future<CpuHardwareSummary>` | 制造商、型号、board、hardware、machine 等。 |
| `getCpuFrequencySnapshot()` | `Future<CpuFrequencySnapshot>` | 各 CPU min/max/current（kHz），**单次**快照。 |
| `getGpuInfo()` | `Future<GpuInfo>` | GLES / Metal 相关字符串。 |
| `getSiliconOverview()` | `Future<SiliconOverview>` | **推荐**：芯片代号、SoC 制造商（已友好化）、GPU 摘要。 |
| `getCpuInfoReport()` | `Future<FullCpuInfo>` | **推荐**：整机报告（含 `siliconOverview`）。 |
| `watchFrequencyTelemetry({interval})` | `Stream<FrequencyTelemetry>` | 实时频率流；取消订阅即停止采样。 |

### 常用数据模型（`lib/src/cpu_info_models.dart`）

| 类型 | 主要字段 / 用途 |
|------|----------------|
| `CpuHardwareSummary` | `manufacturer`、`model`、`hardware`、`machine` … |
| `CpuFrequencySnapshot` | `minHzPerCpu`、`maxHzPerCpu`、`currentHzPerCpu`（`List<int?>`） |
| `GpuInfo` | `api`、`vendor`、`renderer`、`displayLine` |
| `SiliconOverview` | `socModel`、`socManufacturer`、`gpu`、`candidateChain` |
| `FullCpuInfo` | `platform`、`apiLevel`、`abis`、核心数、`hardwareSummary`、`frequencySnapshot`、`gpuInfo`、`siliconOverview` |
| `FrequencyTelemetry` | `cpu`（快照）、`gpuCurrentKhz`、`gpuFreqSource`（Android 成功读取时的 sysfs 路径）、`epochMillis`、`error` |

---

### 方法使用示例（每个公开方法各一段）

下列示例默认已：

```dart
import 'package:cpu_info_plus/cpu_info_plus.dart';

// 建议放在 State / 服务里复用
final CpuInfoPlus plugin = CpuInfoPlus();
```

#### 1. `getPlatformVersion()` — 系统版本描述

```dart
final String? os = await plugin.getPlatformVersion();
debugPrint(os ?? '—'); // 如 Android 13 / iOS 17.x
```

#### 2. `getLogicalProcessorCount()` — 逻辑处理器数量

```dart
final int logical = await plugin.getLogicalProcessorCount();
debugPrint('逻辑核心: $logical');
```

#### 3. `getPhysicalProcessorCount()` — 物理核心数量（估算）

```dart
final int physical = await plugin.getPhysicalProcessorCount();
debugPrint('物理核心: $physical');
```

#### 4. `getSupportedAbis()` — 支持的 ABI / 架构列表

```dart
final List<String> abis = await plugin.getSupportedAbis();
debugPrint(abis.join(', ')); // Android 多为 arm64-v8a 等；Apple 常为 arm64
```

#### 5. `getCpuHardwareSummary()` — 整机 / Build 维度摘要

```dart
final CpuHardwareSummary hw = await plugin.getCpuHardwareSummary();
debugPrint('${hw.manufacturer} · ${hw.model} · ${hw.hardware} · ${hw.machine}');
```

#### 6. `getCpuFrequencySnapshot()` — 各 CPU 档位快照（kHz，非实时流）

```dart
final CpuFrequencySnapshot freq = await plugin.getCpuFrequencySnapshot();
for (var i = 0; i < freq.currentHzPerCpu.length; i++) {
  debugPrint(
    'CPU$i 当前 ${freq.currentHzPerCpu[i]} · 最低 ${freq.minHzPerCpu[i]} · 最高 ${freq.maxHzPerCpu[i]} kHz',
  );
}
```

#### 7. `getGpuInfo()` — GPU 字符串（OpenGL ES / Metal）

```dart
final GpuInfo gpu = await plugin.getGpuInfo();
debugPrint('${gpu.api} · ${gpu.vendor} · ${gpu.renderer}');
debugPrint(gpu.displayLine); // 一行摘要
```

#### 8. `getSiliconOverview()` — SoC + GPU 摘要（推荐）

```dart
final SiliconOverview o = await plugin.getSiliconOverview();
debugPrint('芯片: ${o.socModel} · 制造商: ${o.socManufacturer}');
debugPrint(o.gpu.displayLine);
debugPrint('候选串联: ${o.candidateChain}');
```

#### 9. `getCpuInfoReport()` — 整机结构化报告（推荐）

```dart
final FullCpuInfo report = await plugin.getCpuInfoReport();
debugPrint('平台: ${report.platform} · API: ${report.apiLevel}');
debugPrint('ABI: ${report.abis.join(' / ')}');
debugPrint('核心: 逻辑 ${report.logicalProcessorCount} · 物理 ${report.physicalProcessorCount}');
debugPrint(report.siliconOverview.gpu.displayLine);
```

#### 10. `watchFrequencyTelemetry()` — 实时 CPU/GPU 频率（Stream）

**方式 A — `StreamBuilder`（界面推荐，卸载时自动取消）**

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
        Text('GPU 当前: ${t.gpuCurrentKhz ?? '—'} kHz'),
        if (t.gpuFreqSource != null) Text('节点: ${t.gpuFreqSource}'),
        ...List.generate(t.cpu.currentHzPerCpu.length, (i) {
          final c = t.cpu.currentHzPerCpu[i];
          return Text('CPU$i: ${c ?? '—'} kHz');
        }),
      ],
    );
  },
);
```

**方式 B — `listen`（需在 `dispose` 里取消）**

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

更多界面组合见仓库 **`example/`**（在 `example` 目录执行 `flutter run`）。

### 限制与平台差异（常见问题）

1. **Apple（iOS / macOS）**：系统**不提供**面向第三方 App 的稳定 GPU **主频** API，`gpuCurrentKhz` 多为 `null`。  
2. **Android GPU 频率**：依赖 `kgsl` / `devfreq` 等节点；不少机型对普通应用 **拒绝读 sysfs**（SELinux），属正常现象。  
3. **SoC 制造商显示为 QTI**：系统字段常为高通缩写 **QTI**；插件在 `SiliconOverview` 中已映射为 **Qualcomm** 便于展示。  
4. **桌面 / Web**：Linux、Windows、Web 多为占位或简化实现；Web 上频率流为空。  

