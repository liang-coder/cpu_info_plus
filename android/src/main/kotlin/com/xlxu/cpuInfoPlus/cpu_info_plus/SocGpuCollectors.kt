package com.xlxu.cpuInfoPlus.cpu_info_plus

import android.os.Build
import android.os.Build.VERSION_CODES
import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.EGLContext
import android.opengl.EGLSurface
import android.opengl.GLES20
import java.io.File
import java.lang.ProcessBuilder

/**
 * SOC / 芯片识别：区分「CPU 实现者寄存器代号」与「平台/整机暴露的芯片线索」；
 * GPU：EGL + OpenGL ES 字符串。
 *
 * **权限与访问说明（普通应用，非 root）：**
 * - [Build.SOC_MODEL] / [Build.SOC_MANUFACTURER]（API 31+）为官方公开字段，**不需要**危险权限。
 * - 反射 [SystemProperties] 读 `ro.*` 与执行 `getprop` 通常也**不需要**电话/定位等权限（与读 [Build] 同属系统信息；
 *   若目标 SDK 触发隐藏 API 限制，已用 shell 回退）。
 * - `/proc/cpuinfo` 一般仍可读；**无**可靠「另一系统目录」统一替代——各 OEM 另有 `ro.*` 私有多样。
 * - sysfs 下 cpufreq 目录中的频率节点：常因 **SELinux / 厂商策略** 对 untrusted_app 不可读而得到空值，
 *   **不是**缺 `READ_*` 权限那么简单（系统应用才能用的 [HardwarePropertiesManager] 等另当别论）。
 */
internal object SocGpuCollectors {
    private val SOC_PROP_KEYS =
        arrayOf(
            "ro.soc.manufacturer",
            "ro.soc.model",
            "ro.board.platform",
            "ro.hardware",
            "ro.product.board",
            "ro.boot.hardware",
            "ro.mediatek.platform",
            "ro.vendor.mediatek.platform",
            "ro.chipname",
            "ro.hardware.chipname",
            "ro.vendor.oplus.market.name",
        )

    fun collectSocIdentity(): Map<String, String> {
        val out = LinkedHashMap<String, String>()
        out["note_cpu_implementer"] =
            "cpuinfo 中的 CPU implementer / part 为 ARM 架构寄存器编号及厂商注册 ID，不是营销芯片型号（如天玑/骁龙编号）。"
        out["note_chip_hint"] =
            "Android 12+ 请优先看下方「Build.SOC_*」官方字段；旧机再对照 ro.soc.* / OEM 专有属性。"
        out["note_access"] =
            "SOC/Build 信息：普通应用通常无需危险权限。cpufreq 读不到多为 SELinux 限制 sysfs，而非缺存储/电话权限。"

        appendApi31SocBuildFields(out)

        for (key in SOC_PROP_KEYS) {
            val v = propPreferReflectionThenShell(key)
            if (v.isNotEmpty()) {
                out["prop_$key"] = v
            }
        }

        out["build_hardware"] = Build.HARDWARE
        out["build_board"] = Build.BOARD
        out["build_brand"] = Build.BRAND
        out["build_device"] = Build.DEVICE
        out["build_manufacturer"] = Build.MANUFACTURER
        out["build_model"] = Build.MODEL
        out["build_product"] = Build.PRODUCT

        val cpuinfo = readProcCpuinfo().orEmpty()
        val extracted = extractCpuinfoSocFields(cpuinfo)
        extracted.implementerRaw?.let {
            out["cpuinfo_cpu_implementer_raw"] = it
            out["cpuinfo_cpu_implementer_decoded"] = decodeArmImplementer(it)
        }
        extracted.partRaw?.let { out["cpuinfo_cpu_part_raw"] = it }
        extracted.hardwareLine?.let { out["cpuinfo_hardware_line"] = it }

        val candidates =
            buildList {
                if (Build.VERSION.SDK_INT >= VERSION_CODES.S) {
                    Build.SOC_MODEL?.trim()?.takeIf { it.isNotEmpty() }?.let { add(it) }
                }
                propPreferReflectionThenShell("ro.soc.model").takeIf { it.isNotEmpty() }?.let { add(it) }
                propPreferReflectionThenShell("ro.mediatek.platform").takeIf { it.isNotEmpty() }?.let { add(it) }
                propPreferReflectionThenShell("ro.vendor.mediatek.platform").takeIf { it.isNotEmpty() }?.let { add(it) }
                propPreferReflectionThenShell("ro.board.platform").takeIf { it.isNotEmpty() }?.let { add(it) }
                Build.HARDWARE.takeIf { it.isNotEmpty() }?.let { add(it) }
                extracted.hardwareLine?.takeIf { it.isNotEmpty() }?.let { add(it) }
            }.distinct()
        if (candidates.isNotEmpty()) {
            out["soc_chip_candidates_ordered"] = candidates.joinToString(" → ")
        }

        return out
    }

    /** API 31+ 官方 SoC 字符串（与「市面上跑分/信息类 App」同源的一类数据来源）。 */
    private fun appendApi31SocBuildFields(out: MutableMap<String, String>) {
        if (Build.VERSION.SDK_INT < VERSION_CODES.S) {
            out["note_build_soc_api"] = "当前系统 < API 31，无 Build.SOC_* 官方字段，请依赖 ro.soc.* / OEM 属性。"
            return
        }
        Build.SOC_MODEL?.trim()?.takeIf { it.isNotEmpty() }?.let { out["build_soc_model"] = it }
        Build.SOC_MANUFACTURER?.trim()?.takeIf { it.isNotEmpty() }?.let { out["build_soc_manufacturer"] = it }
    }

    /** 反射 [SystemProperties]；若为空再试 `/system/bin/getprop`（部分机型/隐藏 API 策略下反射可能失败）。 */
    private fun propPreferReflectionThenShell(key: String): String {
        val a = getSystemProperty(key)?.trim().orEmpty()
        if (a.isNotEmpty()) return a
        return getPropViaShell(key)?.trim().orEmpty()
    }

    private fun getPropViaShell(key: String): String? {
        val tryPaths =
            listOf(
                arrayOf("/system/bin/getprop", key),
                arrayOf("/system/bin/sh", "-c", "getprop $key"),
            )
        for (cmd in tryPaths) {
            try {
                val p = ProcessBuilder(*cmd).redirectErrorStream(true).start()
                p.inputStream.bufferedReader().use { reader ->
                    val line = reader.readLine()?.trim()
                    if (!line.isNullOrEmpty()) return line
                }
            } catch (_: Exception) {
                continue
            }
        }
        return null
    }

    fun collectGpuInfo(): Map<String, String> {
        val gl = queryGpuViaEglGlEs()
        val out = LinkedHashMap<String, String>()
        out["api"] = "OpenGL ES"
        gl.forEach { (k, v) -> out[k] = v }
        if (out.none { it.key == "vendor" || it.key == "renderer" }) {
            out["note"] =
                gl["error"]
                    ?: "未能通过 EGL 创建上下文（部分模拟器/无 GPU 环境会出现）。"
        }
        return out
    }

    private data class CpuinfoSocFields(
        val implementerRaw: String?,
        val partRaw: String?,
        val hardwareLine: String?,
    )

    private fun extractCpuinfoSocFields(text: String): CpuinfoSocFields {
        var impl: String? = null
        var part: String? = null
        var hw: String? = null
        for (raw in text.lineSequence()) {
            val line = raw.trim()
            if (line.isEmpty()) continue
            val idx = line.indexOf(':')
            if (idx <= 0) continue
            val key = line.substring(0, idx).trim()
            val value = line.substring(idx + 1).trim()
            when {
                key.equals("CPU implementer", ignoreCase = true) && impl == null -> impl = value
                key.equals("CPU part", ignoreCase = true) && part == null -> part = value
                key.equals("Hardware", ignoreCase = true) && hw == null -> hw = value
            }
        }
        return CpuinfoSocFields(impl, part, hw)
    }

    /**
     * ARM 文档中的 CPU implementer 寄存器含义：0x41=ARM, 0x51=Qualcomm 等（并非 SoC 商品名）。
     */
    private fun decodeArmImplementer(raw: String): String {
        val hex =
            raw.trim().removePrefix("0x").removePrefix("0X")
        val v =
            hex.toIntOrNull(16)
                ?: raw.filter { it.isDigit() || it in 'a'..'f' || it in 'A'..'F' }.toIntOrNull(16)
                ?: return raw
        return when (v) {
            0x41 -> "ARM Limited（CPU 核心 IP 供应方，不是整机芯片型号）"
            0x42 -> "Broadcom"
            0x43 -> "Cavium"
            0x44 -> "Digital Equipment Corporation"
            0x48 -> "HiSilicon"
            0x4e -> "Nvidia"
            0x51 -> "Qualcomm（SoC 平台方，具体型号请看 ro.soc.model / Build）"
            0x53 -> "Samsung"
            0x56 -> "Marvell"
            0x58 -> "Ampere"
            0x66 -> "Faraday"
            0x69 -> "Intel / Motorola (legacy)"
            0xc0 -> "Ampere Computing"
            else -> "寄存器值 0x${v.toString(16)}（请参考 ARM / 厂商文档）"
        }
    }

    private fun getSystemProperty(key: String): String? =
        try {
            val c = Class.forName("android.os.SystemProperties")
            val get = c.getMethod("get", String::class.java)
            get.invoke(null, key) as? String
        } catch (_: Exception) {
            null
        }

    private fun readProcCpuinfo(): String? =
        try {
            File("/proc/cpuinfo").bufferedReader().use { it.readText() }
        } catch (_: Exception) {
            null
        }

    private fun queryGpuViaEglGlEs(): Map<String, String> {
        val err = LinkedHashMap<String, String>()
        val display = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        if (display == EGL14.EGL_NO_DISPLAY) {
            err["error"] = "EGL_NO_DISPLAY"
            return err
        }
        val vers = IntArray(2)
        if (!EGL14.eglInitialize(display, vers, 0, vers, 1)) {
            EGL14.eglTerminate(display)
            err["error"] = "eglInitialize failed"
            return err
        }

        val configAttribs =
            intArrayOf(
                EGL14.EGL_RENDERABLE_TYPE,
                EGL14.EGL_OPENGL_ES2_BIT,
                EGL14.EGL_SURFACE_TYPE,
                EGL14.EGL_PBUFFER_BIT,
                EGL14.EGL_BLUE_SIZE,
                8,
                EGL14.EGL_GREEN_SIZE,
                8,
                EGL14.EGL_RED_SIZE,
                8,
                EGL14.EGL_NONE,
            )
        val configs = arrayOfNulls<EGLConfig>(1)
        val num = IntArray(1)
        if (
            !EGL14.eglChooseConfig(
                display,
                configAttribs,
                0,
                configs,
                0,
                1,
                num,
                0,
            )
        ) {
            EGL14.eglTerminate(display)
            err["error"] = "eglChooseConfig failed"
            return err
        }
        val config = configs[0] ?: run {
            EGL14.eglTerminate(display)
            err["error"] = "no EGLConfig"
            return err
        }

        val surfAttr = intArrayOf(EGL14.EGL_WIDTH, 1, EGL14.EGL_HEIGHT, 1, EGL14.EGL_NONE)
        val surface =
            EGL14.eglCreatePbufferSurface(display, config, surfAttr, 0)
                ?: run {
                    EGL14.eglTerminate(display)
                    err["error"] = "eglCreatePbufferSurface failed"
                    return err
                }

        val tryCreateContext: (Int) -> EGLContext? = { ver ->
            val ctxAttr = intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, ver, EGL14.EGL_NONE)
            EGL14.eglCreateContext(display, config, EGL14.EGL_NO_CONTEXT, ctxAttr, 0)
        }

        val context =
            tryCreateContext(3) ?: tryCreateContext(2) ?: run {
                EGL14.eglDestroySurface(display, surface)
                EGL14.eglTerminate(display)
                err["error"] = "eglCreateContext failed"
                return err
            }

        if (!EGL14.eglMakeCurrent(display, surface, surface, context)) {
            EGL14.eglDestroyContext(display, context)
            EGL14.eglDestroySurface(display, surface)
            EGL14.eglTerminate(display)
            err["error"] = "eglMakeCurrent failed"
            return err
        }

        val ok = LinkedHashMap<String, String>()
        try {
            GLES20.glGetString(GLES20.GL_VENDOR)?.let { ok["vendor"] = it }
            GLES20.glGetString(GLES20.GL_RENDERER)?.let { ok["renderer"] = it }
            GLES20.glGetString(GLES20.GL_VERSION)?.let { ok["version"] = it }
            GLES20.glGetString(GLES20.GL_SHADING_LANGUAGE_VERSION)?.let {
                ok["glsl_version"] = it
            }
        } finally {
            EGL14.eglMakeCurrent(display, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT)
            EGL14.eglDestroyContext(display, context)
            EGL14.eglDestroySurface(display, surface)
            EGL14.eglTerminate(display)
        }
        return ok
    }
}
