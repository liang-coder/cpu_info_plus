package com.xlxu.cpuInfoPlus.cpu_info_plus

import android.os.Build
import java.io.File

/**
 * 单次采集 CPU/GPU 频率（ sysfs ）；供 MethodChannel 与 EventChannel 共用，避免重复逻辑。
 */
internal object FrequencyTelemetryCollector {
    fun logicalProcessorCount(): Int = Runtime.getRuntime().availableProcessors()

    fun listCpuIndices(): List<Int> {
        val root = File("/sys/devices/system/cpu")
        if (!root.isDirectory) return emptyList()
        val re = Regex("^cpu(\\d+)$")
        return root
            .listFiles()
            .orEmpty()
            .mapNotNull { f ->
                re.matchEntire(f.name)?.groupValues?.get(1)?.toIntOrNull()
            }.sorted()
    }

    private fun readSysFile(path: String): Long? =
        try {
            File(path).bufferedReader().use { br ->
                val line = br.readLine()?.trim().orEmpty()
                if (line.isEmpty()) return@use null
                line.split(Regex("\\s+")).firstOrNull()?.toLongOrNull()
            }
        } catch (_: Exception) {
            null
        }

    fun readCpuFreqKhz(
        cpuIndex: Int,
        basename: String,
    ): Long? {
        val paths =
            listOf(
                "/sys/devices/system/cpu/cpu$cpuIndex/cpufreq/$basename",
                "/sys/devices/system/cpu/cpufreq/policy$cpuIndex/$basename",
            )
        for (path in paths) {
            readSysFile(path)?.let {
                return it
            }
        }
        return null
    }

    /**
     * 静态路径 + 动态扫描 [kgsl] / [devfreq]（MTK Mali、三星、部分机型实例名不是 kgsl-3d0）。
     * 若始终为 null，多为 **SELinux** 禁止普通应用读该 sysfs（与路径无关）。
     */
    fun readGpuCurrentKhz(): Pair<Long?, String?> {
        val staticPaths =
            listOf(
                "/sys/class/kgsl/kgsl-3d0/devfreq/cur_freq",
                "/sys/class/kgsl/kgsl-3d0/gpuclk",
                "/sys/kernel/gpu/gpu_gpu_freq",
                "/sys/kernel/gpu/gpu_clock",
                "/sys/devices/platform/soc/soc:qcom,kgsl-hyp/subsystem/devfreq/devfreq0/cur_freq",
                "/sys/devices/platform/gpusys/devices/gpu0/devfreq_gpu0/cur_freq",
                "/sys/class/devfreq/gpufreq/cur_freq",
                "/sys/class/devfreq/soc:qcom,kgsl-gpu/devfreq:qcom,kgsl-gpu/cur_freq",
            )
        for (path in staticPaths) {
            readSysFile(path)?.let { raw ->
                return normalizeGpuToKhz(raw) to path
            }
        }

        File("/sys/class/kgsl").takeIf { it.isDirectory }?.listFiles()?.forEach { child ->
            if (!child.isDirectory) return@forEach
            val base = child.absolutePath
            listOf(
                "$base/devfreq/cur_freq",
                "$base/gpuclk",
                "$base/clock_mhz",
                "$base/devfreq/${child.name}/cur_freq",
            ).forEach { p ->
                readSysFile(p)?.let { raw ->
                    return normalizeGpuToKhz(raw) to p
                }
            }
        }

        File("/sys/class/devfreq").takeIf { it.isDirectory }?.listFiles()?.sortedBy { it.name }?.forEach { child ->
            if (!child.isDirectory) return@forEach
            val n = child.name.lowercase()
            if (
                n.contains("gpu") ||
                    n.contains("kgsl") ||
                    n.contains("mali") ||
                    n.contains("rgx") ||
                    (n.contains("qcom") && n.contains("gpu"))
            ) {
                val p = "${child.absolutePath}/cur_freq"
                readSysFile(p)?.let { raw ->
                    return normalizeGpuToKhz(raw) to p
                }
            }
        }

        return null to null
    }

    /**
     * sysfs：常见为 Hz（Adreno / kgsl 多为大于 5e6 的整数）；部分节点已是 kHz；少数节点为 MHz 整数。
     */
    private fun normalizeGpuToKhz(raw: Long): Long =
        when {
            raw <= 0L -> raw
            raw > 5_000_000L -> raw / 1000
            raw in 100L..9_999L -> raw * 1000
            else -> raw
        }

    fun cpuFrequencySnapshot(): Map<String, Any?> {
        val indices = listCpuIndices().ifEmpty { (0 until logicalProcessorCount()).toList() }
        val minHz = mutableListOf<Long?>()
        val maxHz = mutableListOf<Long?>()
        val curHz = mutableListOf<Long?>()
        for (i in indices) {
            minHz.add(readCpuFreqKhz(i, "cpuinfo_min_freq"))
            maxHz.add(readCpuFreqKhz(i, "cpuinfo_max_freq"))
            val cur =
                readCpuFreqKhz(i, "scaling_cur_freq")
                    ?: readCpuFreqKhz(i, "cpuinfo_cur_freq")
            curHz.add(cur)
        }
        return mapOf(
            "minHzPerCpu" to minHz,
            "maxHzPerCpu" to maxHz,
            "currentHzPerCpu" to curHz,
        )
    }

    /** 一行 Map：CPU 三块列表 + gpuCurrentKhz + 毫秒时间戳 + 可选 gpuFreqSource（成功时的 sysfs 路径）。 */
    fun telemetryPayload(): Map<String, Any?> {
        val cpu = cpuFrequencySnapshot()
        val (gpuKhz, gpuPath) = readGpuCurrentKhz()
        val out = LinkedHashMap<String, Any?>()
        out.putAll(cpu)
        out["gpuCurrentKhz"] = gpuKhz
        if (gpuPath != null) {
            out["gpuFreqSource"] = gpuPath
        }
        out["epochMillis"] = System.currentTimeMillis()
        out["platform"] = "android"
        out["sdkInt"] = Build.VERSION.SDK_INT
        return out
    }
}
