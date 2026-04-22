import Darwin
import Flutter
import Metal
import UIKit

public class CpuInfoPlusPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "cpu_info_plus", binaryMessenger: registrar.messenger())
    let instance = CpuInfoPlusPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    let freq = FlutterEventChannel(name: "cpu_info_plus/frequency_stream", binaryMessenger: registrar.messenger())
    freq.setStreamHandler(FreqStreamHandler())
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    case "getLogicalProcessorCount":
      result(logicalProcessorCount())
    case "getPhysicalProcessorCount":
      result(physicalProcessorCount())
    case "getSupportedAbis":
      result(supportedAbis())
    case "getCpuHardwareSummary":
      result(cpuHardwareSummary())
    case "getCpuFrequencySnapshot":
      result(cpuFrequencySnapshot())
    case "getCpuDetailedProperties":
      result(cpuDetailedProperties())
    case "getAllCpuInfo":
      result(allCpuInfo())
    case "getSocIdentity":
      result(socIdentity())
    case "getGpuInfo":
      result(gpuInfo())
    case "getFrequencyTelemetryOnce":
      result(CpuInfoPlusPlugin().makeTelemetryPayload())
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// 与 [FrequencyTelemetry] 对齐；iOS 无公开 GPU 主频，[gpuCurrentKhz] 为 null。
  fileprivate func makeTelemetryPayload() -> [String: Any] {
    var m = cpuFrequencySnapshot()
    m["gpuCurrentKhz"] = NSNull()
    m["epochMillis"] = Int64(Date().timeIntervalSince1970 * 1000)
    m["platform"] = "ios"
    return m
  }

  private func logicalProcessorCount() -> Int {
    sysctlInt32("hw.logicalcpu")
      ?? sysctlInt32("hw.ncpu")
      ?? ProcessInfo.processInfo.activeProcessorCount
  }

  private func physicalProcessorCount() -> Int {
    sysctlInt32("hw.physicalcpu")
      ?? sysctlInt32("hw.ncpu")
      ?? logicalProcessorCount()
  }

  private func supportedAbis() -> [String] {
    #if arch(arm64)
      return ["arm64"]
    #elseif arch(x86_64)
      return ["x86_64"]
    #elseif arch(arm)
      return ["arm"]
    #else
      return ["unknown"]
    #endif
  }

  private func cpuHardwareSummary() -> [String: Any] {
    var m: [String: Any] = [
      "manufacturer": "Apple",
      "model": UIDevice.current.model,
    ]
    if let machine = sysctlString("hw.machine") {
      m["device"] = machine
      m["machine"] = machine
    }
    if let hw = sysctlString("machdep.cpu.brand_string") ?? sysctlString("hw.product") {
      m["hardware"] = hw
    }
    if let product = sysctlString("hw.product") {
      m["product"] = product
    }
    return m
  }

  private func cpuFrequencySnapshot() -> [String: Any] {
    let n = max(1, logicalProcessorCount())
    let minK = sysctlFreqKHz("hw.cpufrequency_min")
    let maxK = sysctlFreqKHz("hw.cpufrequency_max")
    let curK = sysctlFreqKHz("hw.cpufrequency")

    func repeatOptional(_ count: Int, _ value: Int?) -> [Any] {
      (0..<count).map { _ -> Any in
        guard let value else {
          return NSNull()
        }
        return value
      }
    }

    return [
      "minHzPerCpu": repeatOptional(n, minK),
      "maxHzPerCpu": repeatOptional(n, maxK),
      "currentHzPerCpu": repeatOptional(n, curK),
    ]
  }

  private func cpuDetailedProperties() -> [String: String] {
    var out = [String: String]()
    for key in Self.sysctlCpuKeys {
      if let v = sysctlAnyString(key) {
        out[key.replacingOccurrences(of: ".", with: "_")] = v
      }
    }
    out["uname_machine"] = unameMachine()
    out["logical_from_processInfo"] = String(ProcessInfo.processInfo.processorCount)
    out["active_from_processInfo"] = String(ProcessInfo.processInfo.activeProcessorCount)
    return out
  }

  private func allCpuInfo() -> [String: Any] {
    [
      "platform": "ios",
      "abis": supportedAbis(),
      "logicalProcessorCount": logicalProcessorCount(),
      "physicalProcessorCount": physicalProcessorCount(),
      "hardwareSummary": cpuHardwareSummary(),
      "frequencySnapshot": cpuFrequencySnapshot(),
      "detailedProperties": cpuDetailedProperties(),
      "socIdentity": socIdentity(),
      "gpuInfo": gpuInfo(),
    ]
  }

  /// Apple 不提供 Android 风格 ro.soc.*；机型与芯片代际通常通过 hw.machine 映射表对外公开。
  private func socIdentity() -> [String: String] {
    var m = [String: String]()
    m["note_cpu_implementer"] =
      "无 Android cpuinfo 的 CPU implementer 字段；CPU 品牌见 machdep.cpu.brand_string（仅代表核 IP/微架构描述，不等于整机 SoC 商品名）。"
    m["note_chip_hint"] =
      "设备内部代号：hw.machine；零售型号见设置-本机或通过 Apple 机型标识符对照表。"
    if let v = sysctlString("hw.machine") { m["hw_machine"] = v }
    if let v = sysctlString("hw.product") { m["hw_product"] = v }
    if let v = sysctlString("machdep.cpu.brand_string") { m["cpu_brand_string"] = v }
    m["model_user_visible"] = UIDevice.current.model
    m["device_name"] = UIDevice.current.name
    return m
  }

  private func gpuInfo() -> [String: Any] {
    guard let dev = MTLCreateSystemDefaultDevice() else {
      return ["api": "Metal", "error": "MTLCreateSystemDefaultDevice returned nil"]
    }
    return [
      "api": "Metal",
      "vendor": "Apple",
      "renderer": dev.name,
      "version": "registryID=\(dev.registryID)",
    ]
  }

  private static let sysctlCpuKeys: [String] = [
    "hw.ncpu",
    "hw.activecpu",
    "hw.physicalcpu",
    "hw.logicalcpu",
    "hw.byteorder",
    "hw.pagesize",
    "hw.cpufrequency",
    "hw.cpufrequency_max",
    "hw.cpufrequency_min",
    "hw.busfrequency",
    "hw.tbfrequency",
    "hw.machine",
    "hw.model",
    "hw.product",
    "machdep.cpu.brand_string",
    "machdep.cpu.family",
    "machdep.cpu.model",
    "machdep.cpu.stepping",
    "machdep.cpu.extfamily",
    "machdep.cpu.extmodel",
    "machdep.cpu.features",
    "machdep.cpu.leaf7_features",
    "machdep.cpu.vendor",
  ]

  private func sysctlFreqKHz(_ name: String) -> Int? {
    let hz = sysctlInt64(name) ?? Int64(sysctlInt32(name) ?? 0)
    guard hz > 0 else { return nil }
    return Int(hz / 1000)
  }

  private func sysctlAnyString(_ name: String) -> String? {
    if let s = sysctlString(name) {
      return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    if let i = sysctlInt64(name) {
      return String(i)
    }
    if let i = sysctlInt32(name) {
      return String(i)
    }
    return nil
  }

  private func sysctlString(_ name: String) -> String? {
    var size: size_t = 0
    let cs1 = name.withCString { sysctlbyname($0, nil, &size, nil, 0) }
    guard cs1 == 0, size > 0 else { return nil }
    var buf = [CChar](repeating: 0, count: Int(size))
    let cs2 = name.withCString { sysctlbyname($0, &buf, &size, nil, 0) }
    guard cs2 == 0 else { return nil }
    return String(cString: buf)
  }

  private func sysctlInt32(_ name: String) -> Int? {
    var value: Int32 = 0
    var size = MemoryLayout<Int32>.size
    let cs = name.withCString { sysctlbyname($0, &value, &size, nil, 0) }
    guard cs == 0 else { return nil }
    return Int(value)
  }

  private func sysctlInt64(_ name: String) -> Int64? {
    var value: Int64 = 0
    var size = MemoryLayout<Int64>.size
    let cs = name.withCString { sysctlbyname($0, &value, &size, nil, 0) }
    guard cs == 0 else { return nil }
    return value
  }

  private func unameMachine() -> String {
    var systemInfo = utsname()
    uname(&systemInfo)
    return withUnsafePointer(to: &systemInfo.machine) {
      $0.withMemoryRebound(to: CChar.self, capacity: 1) {
        String(validatingUTF8: $0) ?? ""
      }
    }
  }
}

/// 主线程定时向 Dart 推频率；与 Android 侧 [Handler] 推流类似，避免在 UI 线程读文件（此处为 sysctl，开销小）。
private class FreqStreamHandler: NSObject, FlutterStreamHandler {
  private var timer: Timer?

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    var sec = 1.0
    if let args = arguments as? [String: Any] {
      if let ms = args["intervalMs"] as? Int {
        sec = max(0.25, min(10.0, Double(ms) / 1000.0))
      } else if let ms = args["intervalMs"] as? NSNumber {
        sec = max(0.25, min(10.0, ms.doubleValue / 1000.0))
      }
    }
    let emit: () -> Void = {
      let p = CpuInfoPlusPlugin()
      events(p.makeTelemetryPayload())
    }
    emit()
    timer = Timer.scheduledTimer(withTimeInterval: sec, repeats: true) { _ in
      emit()
    }
    if let t = timer {
      RunLoop.main.add(t, forMode: .common)
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    timer?.invalidate()
    timer = nil
    return nil
  }
}
