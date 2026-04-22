#include "cpu_info_plus_plugin.h"

#include <windows.h>

#include <VersionHelpers.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <chrono>
#include <cstdint>
#include <memory>
#include <sstream>

namespace cpu_info_plus {

namespace {

flutter::EncodableMap SocIdentityStub() {
  flutter::EncodableMap m;
  m[flutter::EncodableValue("note_cpu_implementer")] = flutter::EncodableValue(
      "Windows 上请使用 DXGI / WMI 获取 GPU；CPU 型号可通过注册表或 WMI。");
  m[flutter::EncodableValue("note_chip_hint")] =
      flutter::EncodableValue("当前插件未读取 OEM SoC 专有属性。");
  return m;
}

flutter::EncodableMap GpuInfoStub() {
  flutter::EncodableMap m;
  m[flutter::EncodableValue("api")] = flutter::EncodableValue("unavailable");
  m[flutter::EncodableValue("note")] =
      flutter::EncodableValue("Windows 插件未实现 DXGI GPU 枚举。");
  return m;
}

flutter::EncodableList SupportedAbis() {
  flutter::EncodableList list;
#if defined(_M_ARM64) || defined(__aarch64__)
  list.push_back(flutter::EncodableValue("arm64"));
#elif defined(_M_IX86)
  list.push_back(flutter::EncodableValue("x86"));
#elif defined(_M_X64) || defined(__x86_64__)
  list.push_back(flutter::EncodableValue("x86_64"));
#else
  list.push_back(flutter::EncodableValue("unknown"));
#endif
  return list;
}

int LogicalProcessorCount() {
  SYSTEM_INFO si{};
  GetSystemInfo(&si);
  int n = static_cast<int>(si.dwNumberOfProcessors);
  return n > 0 ? n : 1;
}

flutter::EncodableMap EmptyFrequencySnapshot() {
  flutter::EncodableMap m;
  m[flutter::EncodableValue("minHzPerCpu")] = flutter::EncodableValue(flutter::EncodableList());
  m[flutter::EncodableValue("maxHzPerCpu")] = flutter::EncodableValue(flutter::EncodableList());
  m[flutter::EncodableValue("currentHzPerCpu")] =
      flutter::EncodableValue(flutter::EncodableList());
  return m;
}

flutter::EncodableMap FrequencyTelemetryOnceStub() {
  flutter::EncodableMap m = EmptyFrequencySnapshot();
  m[flutter::EncodableValue("gpuCurrentKhz")] = flutter::EncodableValue();
  const auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(
                      std::chrono::system_clock::now().time_since_epoch())
                      .count();
  m[flutter::EncodableValue("epochMillis")] =
      flutter::EncodableValue(static_cast<int64_t>(ms));
  m[flutter::EncodableValue("platform")] =
      flutter::EncodableValue("windows");
  return m;
}

flutter::EncodableMap HardwareSummaryStub() {
  flutter::EncodableMap m;
  m[flutter::EncodableValue("manufacturer")] = flutter::EncodableValue("");
  m[flutter::EncodableValue("brand")] = flutter::EncodableValue("");
  m[flutter::EncodableValue("device")] = flutter::EncodableValue("");
  m[flutter::EncodableValue("model")] = flutter::EncodableValue("");
  m[flutter::EncodableValue("board")] = flutter::EncodableValue("");
  m[flutter::EncodableValue("hardware")] = flutter::EncodableValue("");
  m[flutter::EncodableValue("product")] = flutter::EncodableValue("");
  m[flutter::EncodableValue("machine")] = flutter::EncodableValue("");
  return m;
}

}  // namespace

void CpuInfoPlusPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "cpu_info_plus",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<CpuInfoPlusPlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

CpuInfoPlusPlugin::CpuInfoPlusPlugin() {}

CpuInfoPlusPlugin::~CpuInfoPlusPlugin() {}

void CpuInfoPlusPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string &method = method_call.method_name();
  if (method == "getPlatformVersion") {
    std::ostringstream version_stream;
    version_stream << "Windows ";
    if (IsWindows10OrGreater()) {
      version_stream << "10+";
    } else if (IsWindows8OrGreater()) {
      version_stream << "8";
    } else if (IsWindows7OrGreater()) {
      version_stream << "7";
    }
    result->Success(flutter::EncodableValue(version_stream.str()));
    return;
  }
  if (method == "getLogicalProcessorCount" || method == "getPhysicalProcessorCount") {
    result->Success(flutter::EncodableValue(LogicalProcessorCount()));
    return;
  }
  if (method == "getSupportedAbis") {
    result->Success(flutter::EncodableValue(SupportedAbis()));
    return;
  }
  if (method == "getCpuHardwareSummary") {
    result->Success(flutter::EncodableValue(HardwareSummaryStub()));
    return;
  }
  if (method == "getCpuFrequencySnapshot") {
    result->Success(flutter::EncodableValue(EmptyFrequencySnapshot()));
    return;
  }
  if (method == "getCpuDetailedProperties") {
    result->Success(flutter::EncodableValue(flutter::EncodableMap()));
    return;
  }
  if (method == "getSocIdentity") {
    result->Success(flutter::EncodableValue(SocIdentityStub()));
    return;
  }
  if (method == "getGpuInfo") {
    result->Success(flutter::EncodableValue(GpuInfoStub()));
    return;
  }
  if (method == "getFrequencyTelemetryOnce") {
    result->Success(flutter::EncodableValue(FrequencyTelemetryOnceStub()));
    return;
  }
  if (method == "getAllCpuInfo") {
    flutter::EncodableMap root;
    root[flutter::EncodableValue("platform")] = flutter::EncodableValue("windows");
    root[flutter::EncodableValue("abis")] = flutter::EncodableValue(SupportedAbis());
    root[flutter::EncodableValue("logicalProcessorCount")] =
        flutter::EncodableValue(LogicalProcessorCount());
    root[flutter::EncodableValue("physicalProcessorCount")] =
        flutter::EncodableValue(LogicalProcessorCount());
    root[flutter::EncodableValue("hardwareSummary")] =
        flutter::EncodableValue(HardwareSummaryStub());
    root[flutter::EncodableValue("frequencySnapshot")] =
        flutter::EncodableValue(EmptyFrequencySnapshot());
    root[flutter::EncodableValue("detailedProperties")] =
        flutter::EncodableValue(flutter::EncodableMap());
    root[flutter::EncodableValue("socIdentity")] =
        flutter::EncodableValue(SocIdentityStub());
    root[flutter::EncodableValue("gpuInfo")] = flutter::EncodableValue(GpuInfoStub());
    result->Success(flutter::EncodableValue(root));
    return;
  }
  result->NotImplemented();
}

}  // namespace cpu_info_plus
