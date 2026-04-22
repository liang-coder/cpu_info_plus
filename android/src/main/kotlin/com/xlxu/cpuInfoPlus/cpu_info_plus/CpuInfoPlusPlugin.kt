package com.xlxu.cpuInfoPlus.cpu_info_plus

import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File

class CpuInfoPlusPlugin :
    FlutterPlugin,
    MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var freqEvents: EventChannel
    private var freqStreamHandler: FreqStreamHandler? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "cpu_info_plus")
        channel.setMethodCallHandler(this)

        freqEvents = EventChannel(flutterPluginBinding.binaryMessenger, "cpu_info_plus/frequency_stream")
        freqStreamHandler = FreqStreamHandler()
        freqEvents.setStreamHandler(freqStreamHandler)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result,
    ) {
        when (call.method) {
            "getPlatformVersion" -> result.success("Android ${Build.VERSION.RELEASE}")
            "getLogicalProcessorCount" -> result.success(logicalProcessorCount())
            "getPhysicalProcessorCount" -> result.success(physicalProcessorCount())
            "getSupportedAbis" -> result.success(supportedAbis())
            "getCpuHardwareSummary" -> result.success(cpuHardwareSummary())
            "getCpuFrequencySnapshot" -> result.success(cpuFrequencySnapshot())
            "getCpuDetailedProperties" -> result.success(cpuDetailedProperties())
            "getSocIdentity" -> result.success(SocGpuCollectors.collectSocIdentity())
            "getGpuInfo" -> result.success(SocGpuCollectors.collectGpuInfo())
            "getFrequencyTelemetryOnce" -> result.success(FrequencyTelemetryCollector.telemetryPayload())
            "getAllCpuInfo" -> result.success(allCpuInfo())
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        freqStreamHandler?.dispose()
        freqStreamHandler = null
        freqEvents.setStreamHandler(null)
    }

    private fun logicalProcessorCount(): Int = FrequencyTelemetryCollector.logicalProcessorCount()

    private fun listCpuIndices(): List<Int> = FrequencyTelemetryCollector.listCpuIndices()

    private fun physicalProcessorCount(): Int {
        val logical = logicalProcessorCount()
        val indices = listCpuIndices().ifEmpty { (0 until logical).toList() }
        val pkgCorePairs = mutableSetOf<String>()
        val coreOnly = mutableSetOf<String>()
        for (i in indices) {
            val base = File("/sys/devices/system/cpu/cpu$i/topology")
            val coreId = File(base, "core_id")
            val pkgId = File(base, "physical_package_id")
            try {
                if (coreId.exists() && pkgId.exists()) {
                    pkgCorePairs.add("${pkgId.readText().trim()}:${coreId.readText().trim()}")
                } else if (coreId.exists()) {
                    coreOnly.add(coreId.readText().trim())
                }
            } catch (_: Exception) {
            }
        }
        return when {
            pkgCorePairs.isNotEmpty() -> pkgCorePairs.size
            coreOnly.isNotEmpty() -> coreOnly.size
            else -> logical
        }
    }

    private fun supportedAbis(): List<String> = Build.SUPPORTED_ABIS.toList()

    private fun cpuHardwareSummary(): Map<String, String?> =
        mapOf(
            "manufacturer" to Build.MANUFACTURER,
            "brand" to Build.BRAND,
            "device" to Build.DEVICE,
            "model" to Build.MODEL,
            "board" to Build.BOARD,
            "hardware" to Build.HARDWARE,
            "product" to Build.PRODUCT,
            "machine" to null,
        )

    private fun cpuFrequencySnapshot(): Map<String, Any?> = FrequencyTelemetryCollector.cpuFrequencySnapshot()

    private fun readProcCpuinfo(): String? =
        try {
            File("/proc/cpuinfo").bufferedReader().use { it.readText() }
        } catch (_: Exception) {
            null
        }

    private fun parseCpuinfo(text: String): Map<String, String> {
        val map = linkedMapOf<String, String>()
        var processorBlocks = 0
        for (raw in text.lines()) {
            val line = raw.trim()
            if (line.isEmpty()) continue
            val idx = line.indexOf(':')
            if (idx <= 0) continue
            val key = line.substring(0, idx).trim()
            val value = line.substring(idx + 1).trim()
            val storageKey = uniqueCpuinfoKey(map, key)
            map[storageKey] = value
            if (key == "processor") {
                processorBlocks++
            }
        }
        map["processor_blocks_in_cpuinfo"] = processorBlocks.toString()
        return map
    }

    private fun uniqueCpuinfoKey(
        existing: MutableMap<String, String>,
        key: String,
    ): String {
        if (!existing.containsKey(key)) return key
        var n = 2
        while (existing.containsKey("$key#$n")) {
            n++
        }
        return "$key#$n"
    }

    private fun cpuDetailedProperties(): Map<String, String> {
        val out = LinkedHashMap<String, String>()
        readProcCpuinfo()?.let { text ->
            out.putAll(parseCpuinfo(text))
        }
        out["abis"] = Build.SUPPORTED_ABIS.joinToString(",")
        out["sdk_int"] = Build.VERSION.SDK_INT.toString()
        return out
    }

    private fun allCpuInfo(): Map<String, Any?> {
        val freq = cpuFrequencySnapshot()
        val detail = cpuDetailedProperties()
        val hw = cpuHardwareSummary()
        return mapOf(
            "platform" to "android",
            "apiLevel" to Build.VERSION.SDK_INT,
            "abis" to supportedAbis(),
            "logicalProcessorCount" to logicalProcessorCount(),
            "physicalProcessorCount" to physicalProcessorCount(),
            "hardwareSummary" to hw,
            "frequencySnapshot" to freq,
            "detailedProperties" to detail,
            "socIdentity" to SocGpuCollectors.collectSocIdentity(),
            "gpuInfo" to SocGpuCollectors.collectGpuInfo(),
        )
    }
}

/**
 * 后台线程读 sysfs，主线程 [EventSink]；可配置间隔，取消时移除回调。
 */
private class FreqStreamHandler : EventChannel.StreamHandler {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var bgThread: HandlerThread? = null
    private var bgHandler: Handler? = null
    private var sink: EventChannel.EventSink? = null
    /** CPU 全核 + GPU 同一 [telemetryPayload]，单一线程 postDelayed 循环。 */
    private var intervalMs = 1000L

    private val tickRunnable: Runnable =
        object : Runnable {
            override fun run() {
                val h = bgHandler ?: return
                val payload: Map<String, Any?> =
                    try {
                        FrequencyTelemetryCollector.telemetryPayload()
                    } catch (e: Exception) {
                        mapOf("error" to (e.message ?: "telemetry"))
                    }
                mainHandler.post {
                    sink?.success(payload)
                }
                h.postDelayed(this, intervalMs)
            }
        }

    override fun onListen(
        arguments: Any?,
        events: EventChannel.EventSink?,
    ) {
        dispose()
        sink = events
        val args = arguments as? Map<*, *>
        intervalMs =
            (args?.get("intervalMs") as? Number)?.toLong()?.coerceIn(250L, 10000L) ?: 1000L

        val t = HandlerThread("cpu_info_plus_freq").apply { start() }
        bgThread = t
        bgHandler = Handler(t.looper)
        bgHandler?.post(tickRunnable)
    }

    override fun onCancel(arguments: Any?) {
        dispose()
    }

    fun dispose() {
        bgHandler?.removeCallbacks(tickRunnable)
        bgHandler?.removeCallbacksAndMessages(null)
        bgThread?.quitSafely()
        bgThread = null
        bgHandler = null
        sink = null
    }
}
