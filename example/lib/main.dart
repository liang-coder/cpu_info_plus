import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:cpu_info_plus/cpu_info_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _plugin = CpuInfoPlus();

  bool _loading = true;
  String? _error;
  FullCpuInfo? _report;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final report = await _plugin.getCpuInfoReport();
      if (!mounted) return;
      setState(() {
        _report = report;
        _loading = false;
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message ?? e.code;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cpu Info Plus',
      home: Builder(
        builder: (ctx) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('处理器与图形'),
              actions: [
                IconButton(
                  onPressed: _loading ? null : _load,
                  tooltip: '刷新',
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            body: SafeArea(child: _buildBody(ctx)),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext ctx) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('读取失败：$_error', textAlign: TextAlign.center),
        ),
      );
    }
    final r = _report;
    if (r == null) {
      return const Center(child: Text('无数据'));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _siliconHeroCard(ctx, r.siliconOverview),
          const SizedBox(height: 16),
          RepaintBoundary(child: _LiveFrequencyCard(plugin: _plugin)),
          const SizedBox(height: 16),
          _section(
            ctx,
            title: '运行概览',
            children: [
              _kvLine(ctx, '运行平台', r.platform.isEmpty ? '—' : r.platform),
              if (r.apiLevel != null) _kvLine(ctx, 'API 级别', '${r.apiLevel}'),
              _kvLine(ctx, '逻辑处理器', '${r.logicalProcessorCount} 个'),
              _kvLine(ctx, '物理核心（估算）', '${r.physicalProcessorCount} 个'),
              _kvLine(ctx, 'ABI', r.abis.isEmpty ? '—' : r.abis.join('、')),
            ],
          ),
          const SizedBox(height: 8),
          ExpansionTile(
            initiallyExpanded: false,
            title: const Text(
              'GPU',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              'Vendor / Renderer / Version',
              style: TextStyle(color: Theme.of(ctx).colorScheme.outline),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _gpuRowsFromGpuInfo(ctx, r.gpuInfo),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ExpansionTile(
            initiallyExpanded: false,
            title: const Text(
              '整机 Build',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _hardwareSummaryRows(ctx, r.hardwareSummary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _siliconHeroCard(
    BuildContext ctx,
    SiliconOverview overview,
  ) {
    final codename = overview.socModel;
    final socMfg = overview.socManufacturer;
    final chain = overview.candidateChain;
    final gpu = overview.gpu;

    return Card(
      elevation: 0,
      color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.memory, color: Theme.of(ctx).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'SoC 与 GPU（摘要）',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _heroLine(ctx, '芯片代号', codename?.isNotEmpty == true ? codename! : '—'),
            const SizedBox(height: 12),
            _heroLine(ctx, 'SoC 制造商', socMfg?.isNotEmpty == true ? socMfg! : '—'),
            const SizedBox(height: 12),
            _heroLine(ctx, 'GPU', gpu.displayLine),
            if (chain != null && chain.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                '候选串联（供核对）：',
                style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                      color: Theme.of(ctx).colorScheme.outline,
                    ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                chain,
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _heroLine(BuildContext ctx, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                color: Theme.of(ctx).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 4),
        SelectableText(
          value,
          style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }

  List<Widget> _gpuRowsFromGpuInfo(BuildContext ctx, GpuInfo g) {
    final ordered = <(String label, String?)>[
      ('API', g.api),
      ('Vendor', g.vendor),
      ('Renderer', g.renderer),
      ('Version', g.version),
      ('GLSL', g.shadingLanguageVersion),
      ('说明', g.note),
      ('错误', g.error),
    ];
    final rows = <Widget>[];
    for (final (lb, val) in ordered) {
      if (val == null || val.isEmpty) continue;
      rows.add(_kvLine(ctx, lb, val));
    }
    return rows.isEmpty ? [const Text('无可用字段')] : rows;
  }

  List<Widget> _hardwareSummaryRows(BuildContext ctx, CpuHardwareSummary h) {
    final ordered = <(String label, String?)>[
      ('制造商', h.manufacturer),
      ('品牌', h.brand),
      ('设备代号', h.device),
      ('型号', h.model),
      ('主板', h.board),
      ('Build.HARDWARE', h.hardware),
      ('产品', h.product),
      ('机器标识', h.machine),
    ];
    final rows = <Widget>[];
    for (final (lb, val) in ordered) {
      if (val == null || val.isEmpty) continue;
      rows.add(_kvLine(ctx, lb, val));
    }
    return rows.isEmpty ? [const Text('暂无')] : rows;
  }

  Widget _section(
    BuildContext context, {
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _kvLine(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              '$label：',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value.isEmpty ? '—' : value,
              style: const TextStyle(fontSize: 14, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

/// kHz（与插件约定一致）。
String formatKhzLabel(int? kHz) {
  if (kHz == null || kHz <= 0) return '—';
  if (kHz >= 1000000) {
    return '${(kHz / 1000000).toStringAsFixed(2)} GHz';
  }
  if (kHz >= 1000) {
    return '${(kHz / 1000).toStringAsFixed(0)} MHz';
  }
  return '$kHz kHz';
}

/// 仅订阅 [CpuInfoPlus.watchFrequencyTelemetry]，局部重建，不占主列表 setState。
class _LiveFrequencyCard extends StatelessWidget {
  const _LiveFrequencyCard({required this.plugin});

  final CpuInfoPlus plugin;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<FrequencyTelemetry>(
      stream: plugin.watchFrequencyTelemetry(
        interval: const Duration(milliseconds: 1500),
      ),
      builder: (context, snapshot) {
        final telemetry = snapshot.data;
        final theme = Theme.of(context);

        return Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.speed_outlined, color: theme.colorScheme.secondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '实时频率',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      '间隔 1s · 单次采样含 CPU+GPU',
                      style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                    ),
                  ],
                ),
                if (snapshot.connectionState == ConnectionState.waiting && telemetry == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 14),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                if (telemetry != null) ...[
                  const SizedBox(height: 14),
                  SelectableText.rich(
                    TextSpan(
                      style: theme.textTheme.titleMedium,
                      children: [
                        TextSpan(
                          text: 'GPU：',
                          style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                        ),
                        TextSpan(text: formatKhzLabel(telemetry.gpuCurrentKhz)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...List<Widget>.generate(
                    telemetry.cpu.currentHzPerCpu.length,
                    (i) {
                      final cur = i < telemetry.cpu.currentHzPerCpu.length
                          ? telemetry.cpu.currentHzPerCpu[i]
                          : null;
                      final minV = i < telemetry.cpu.minHzPerCpu.length
                          ? telemetry.cpu.minHzPerCpu[i]
                          : null;
                      final maxV = i < telemetry.cpu.maxHzPerCpu.length
                          ? telemetry.cpu.maxHzPerCpu[i]
                          : null;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SelectableText(
                          'CPU $i · 当前 ${formatKhzLabel(cur)} '
                          '· 低 ${formatKhzLabel(minV)} · 高 ${formatKhzLabel(maxV)}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      );
                    },
                  ),
                  if (telemetry.error != null && telemetry.error!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        telemetry.error!,
                        style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
