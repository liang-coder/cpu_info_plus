#ifndef FLUTTER_PLUGIN_CPU_INFO_PLUS_PLUGIN_H_
#define FLUTTER_PLUGIN_CPU_INFO_PLUS_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace cpu_info_plus {

class CpuInfoPlusPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  CpuInfoPlusPlugin();

  virtual ~CpuInfoPlusPlugin();

  // Disallow copy and assign.
  CpuInfoPlusPlugin(const CpuInfoPlusPlugin&) = delete;
  CpuInfoPlusPlugin& operator=(const CpuInfoPlusPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace cpu_info_plus

#endif  // FLUTTER_PLUGIN_CPU_INFO_PLUS_PLUGIN_H_
