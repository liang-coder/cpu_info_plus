#include "include/cpu_info_plus/cpu_info_plus_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "cpu_info_plus_plugin.h"

void CpuInfoPlusPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  cpu_info_plus::CpuInfoPlusPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
