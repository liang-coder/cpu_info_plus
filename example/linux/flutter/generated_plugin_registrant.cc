//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <cpu_info_plus/cpu_info_plus_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) cpu_info_plus_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "CpuInfoPlusPlugin");
  cpu_info_plus_plugin_register_with_registrar(cpu_info_plus_registrar);
}
