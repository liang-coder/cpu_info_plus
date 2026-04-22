#include "include/cpu_info_plus/cpu_info_plus_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <glib.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>
#include <unistd.h>

#include <cctype>
#include <cstring>
#include <fstream>
#include <sstream>
#include <string>

#include "cpu_info_plus_plugin_private.h"

#define CPU_INFO_PLUS_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), cpu_info_plus_plugin_get_type(), \
                              CpuInfoPlusPlugin))

struct _CpuInfoPlusPlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(CpuInfoPlusPlugin, cpu_info_plus_plugin, g_object_get_type())

static int64_t linux_logical_processor_count() {
  long n = sysconf(_SC_NPROCESSORS_ONLN);
  if (n < 1) {
    n = 1;
  }
  return static_cast<int64_t>(n);
}

static FlValue* build_abi_list_for_machine(const gchar* machine) {
  FlValue* list = fl_value_new_list();
  std::string m(machine);
  if (m.find("aarch64") != std::string::npos || m.find("arm64") != std::string::npos) {
    fl_value_append_take(list, fl_value_new_string("arm64"));
  } else if (m.find("x86_64") != std::string::npos || m.find("amd64") != std::string::npos) {
    fl_value_append_take(list, fl_value_new_string("x86_64"));
  } else if (m.find("arm") != std::string::npos) {
    fl_value_append_take(list, fl_value_new_string("arm"));
  } else {
    fl_value_append_take(list, fl_value_new_string(machine));
  }
  return list;
}

static FlMethodResponse* get_supported_abis() {
  struct utsname un {};
  uname(&un);
  g_autoptr(FlValue) list = build_abi_list_for_machine(un.machine);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(list));
}

static FlMethodResponse* get_logical_processor_count() {
  int64_t n = linux_logical_processor_count();
  g_autoptr(FlValue) result = fl_value_new_int(n);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* get_physical_processor_count() {
  int64_t n = linux_logical_processor_count();
  g_autoptr(FlValue) result = fl_value_new_int(n);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* get_cpu_hardware_summary() {
  struct utsname un {};
  uname(&un);
  g_autoptr(FlValue) map = fl_value_new_map();
  fl_value_set_string_take(map, "manufacturer", fl_value_new_string(""));
  fl_value_set_string_take(map, "brand", fl_value_new_string(""));
  fl_value_set_string_take(map, "device", fl_value_new_string(un.machine));
  fl_value_set_string_take(map, "model", fl_value_new_string(""));
  fl_value_set_string_take(map, "board", fl_value_new_string(""));
  fl_value_set_string_take(map, "hardware", fl_value_new_string(un.machine));
  fl_value_set_string_take(map, "product", fl_value_new_string(""));
  fl_value_set_string_take(map, "machine", fl_value_new_string(un.machine));
  return FL_METHOD_RESPONSE(fl_method_success_response_new(map));
}

static FlValue* load_proc_cpuinfo_map() {
  FlValue* map = fl_value_new_map();
  std::ifstream in("/proc/cpuinfo");
  if (!in) {
    return map;
  }
  std::string line;
  while (std::getline(in, line)) {
    auto pos = line.find(':');
    if (pos == std::string::npos) {
      continue;
    }
    std::string key = line.substr(0, pos);
    std::string val = line.substr(pos + 1);
    while (!key.empty() && std::isspace(static_cast<unsigned char>(key.back()))) {
      key.pop_back();
    }
    while (!val.empty() && std::isspace(static_cast<unsigned char>(val.front()))) {
      val.erase(val.begin());
    }
    if (key.empty()) {
      continue;
    }
    FlValue* unused = nullptr;
    if (fl_value_lookup_string(map, key.c_str(), &unused)) {
      int n = 2;
      for (;;) {
        std::string nk = key + "#" + std::to_string(n);
        if (!fl_value_lookup_string(map, nk.c_str(), &unused)) {
          fl_value_set_string_take(map, g_strdup(nk.c_str()),
                                   fl_value_new_string(val.c_str()));
          break;
        }
        n++;
      }
    } else {
      fl_value_set_string_take(map, g_strdup(key.c_str()),
                               fl_value_new_string(val.c_str()));
    }
  }
  return map;
}

static FlMethodResponse* get_cpu_frequency_snapshot() {
  g_autoptr(FlValue) min_list = fl_value_new_list();
  g_autoptr(FlValue) max_list = fl_value_new_list();
  g_autoptr(FlValue) cur_list = fl_value_new_list();
  g_autoptr(FlValue) map = fl_value_new_map();
  fl_value_set_string_take(map, "minHzPerCpu", g_steal_pointer(&min_list));
  fl_value_set_string_take(map, "maxHzPerCpu", g_steal_pointer(&max_list));
  fl_value_set_string_take(map, "currentHzPerCpu", g_steal_pointer(&cur_list));
  return FL_METHOD_RESPONSE(fl_method_success_response_new(map));
}

static FlMethodResponse* get_cpu_detailed_properties() {
  g_autoptr(FlValue) map = load_proc_cpuinfo_map();
  return FL_METHOD_RESPONSE(fl_method_success_response_new(map));
}

static FlMethodResponse* get_frequency_telemetry_once() {
  g_autoptr(FlValue) min_list = fl_value_new_list();
  g_autoptr(FlValue) max_list = fl_value_new_list();
  g_autoptr(FlValue) cur_list = fl_value_new_list();
  g_autoptr(FlValue) root = fl_value_new_map();
  fl_value_set_string_take(root, "minHzPerCpu", g_object_ref(min_list));
  fl_value_set_string_take(root, "maxHzPerCpu", g_object_ref(max_list));
  fl_value_set_string_take(root, "currentHzPerCpu", g_object_ref(cur_list));
  fl_value_set_string_take(root, "gpuCurrentKhz", fl_value_new_null());
  fl_value_set_string_take(root, "epochMillis", fl_value_new_int(g_get_real_time() / 1000));
  fl_value_set_string_take(root, "platform", fl_value_new_string("linux"));
  return FL_METHOD_RESPONSE(fl_method_success_response_new(root));
}

static FlMethodResponse* get_all_cpu_info() {
  int64_t logical = linux_logical_processor_count();
  struct utsname un {};
  uname(&un);

  g_autoptr(FlValue) abis = build_abi_list_for_machine(un.machine);

  g_autoptr(FlValue) hw = fl_value_new_map();
  fl_value_set_string_take(hw, "manufacturer", fl_value_new_string(""));
  fl_value_set_string_take(hw, "brand", fl_value_new_string(""));
  fl_value_set_string_take(hw, "device", fl_value_new_string(un.machine));
  fl_value_set_string_take(hw, "model", fl_value_new_string(""));
  fl_value_set_string_take(hw, "board", fl_value_new_string(""));
  fl_value_set_string_take(hw, "hardware", fl_value_new_string(un.machine));
  fl_value_set_string_take(hw, "product", fl_value_new_string(""));
  fl_value_set_string_take(hw, "machine", fl_value_new_string(un.machine));

  g_autoptr(FlValue) min_list = fl_value_new_list();
  g_autoptr(FlValue) max_list = fl_value_new_list();
  g_autoptr(FlValue) cur_list = fl_value_new_list();
  g_autoptr(FlValue) freq = fl_value_new_map();
  fl_value_set_string_take(freq, "minHzPerCpu", g_object_ref(min_list));
  fl_value_set_string_take(freq, "maxHzPerCpu", g_object_ref(max_list));
  fl_value_set_string_take(freq, "currentHzPerCpu", g_object_ref(cur_list));

  g_autoptr(FlValue) detail = load_proc_cpuinfo_map();

  g_autoptr(FlValue) soc = fl_value_new_map();
  fl_value_set_string_take(
      soc, "note_cpu_implementer",
      fl_value_new_string(
          "桌面 Linux 上请关注 cpuinfo 中 vendor_id / CPU implementer（厂商寄存器含义），"
          "SoC 完整型号可能需结合 DMI/sysfs。"));
  fl_value_set_string_take(soc, "uname_machine", fl_value_new_string(un.machine));

  g_autoptr(FlValue) gpu = fl_value_new_map();
  fl_value_set_string_take(gpu, "api", fl_value_new_string("unavailable"));
  fl_value_set_string_take(
      gpu, "note",
      fl_value_new_string(
          "当前 Linux 实现未接入 GLX/Vulkan；请在需要时使用系统图形栈单独查询 GPU。"));

  g_autoptr(FlValue) root = fl_value_new_map();
  fl_value_set_string_take(root, "platform", fl_value_new_string("linux"));
  fl_value_set_take(root, fl_value_new_string("abis"), g_object_ref(abis));
  fl_value_set_string_take(root, "logicalProcessorCount", fl_value_new_int(logical));
  fl_value_set_string_take(root, "physicalProcessorCount", fl_value_new_int(logical));
  fl_value_set_take(root, fl_value_new_string("hardwareSummary"), g_object_ref(hw));
  fl_value_set_take(root, fl_value_new_string("frequencySnapshot"), g_object_ref(freq));
  fl_value_set_take(root, fl_value_new_string("detailedProperties"), g_object_ref(detail));
  fl_value_set_take(root, fl_value_new_string("socIdentity"), g_object_ref(soc));
  fl_value_set_take(root, fl_value_new_string("gpuInfo"), g_object_ref(gpu));

  return FL_METHOD_RESPONSE(fl_method_success_response_new(root));
}

// Called when a method call is received from Flutter.
static void cpu_info_plus_plugin_handle_method_call(
    CpuInfoPlusPlugin* self,
    FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);

  if (strcmp(method, "getPlatformVersion") == 0) {
    response = get_platform_version();
  } else if (strcmp(method, "getLogicalProcessorCount") == 0) {
    response = get_logical_processor_count();
  } else if (strcmp(method, "getPhysicalProcessorCount") == 0) {
    response = get_physical_processor_count();
  } else if (strcmp(method, "getSupportedAbis") == 0) {
    response = get_supported_abis();
  } else if (strcmp(method, "getCpuHardwareSummary") == 0) {
    response = get_cpu_hardware_summary();
  } else if (strcmp(method, "getCpuFrequencySnapshot") == 0) {
    response = get_cpu_frequency_snapshot();
  } else if (strcmp(method, "getCpuDetailedProperties") == 0) {
    response = get_cpu_detailed_properties();
  } else if (strcmp(method, "getSocIdentity") == 0) {
    struct utsname un {};
    uname(&un);
    g_autoptr(FlValue) soc = fl_value_new_map();
    fl_value_set_string_take(
        soc, "note_cpu_implementer",
        fl_value_new_string(
            "桌面 Linux：cpuinfo 中 vendor_id / CPU implementer 为架构层厂商 ID，不等于整机芯片营销名。"));
    fl_value_set_string_take(soc, "uname_machine", fl_value_new_string(un.machine));
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(soc));
  } else if (strcmp(method, "getGpuInfo") == 0) {
    g_autoptr(FlValue) gpu = fl_value_new_map();
    fl_value_set_string_take(gpu, "api", fl_value_new_string("unavailable"));
    fl_value_set_string_take(gpu, "note",
                             fl_value_new_string("Linux 插件未实现 GPU 探测。"));
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(gpu));
  } else if (strcmp(method, "getFrequencyTelemetryOnce") == 0) {
    response = get_frequency_telemetry_once();
  } else if (strcmp(method, "getAllCpuInfo") == 0) {
    response = get_all_cpu_info();
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

FlMethodResponse* get_platform_version() {
  struct utsname uname_data = {};
  uname(&uname_data);
  g_autofree gchar* version = g_strdup_printf("Linux %s", uname_data.version);
  g_autoptr(FlValue) result = fl_value_new_string(version);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static void cpu_info_plus_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(cpu_info_plus_plugin_parent_class)->dispose(object);
}

static void cpu_info_plus_plugin_class_init(CpuInfoPlusPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = cpu_info_plus_plugin_dispose;
}

static void cpu_info_plus_plugin_init(CpuInfoPlusPlugin* self) {}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  CpuInfoPlusPlugin* plugin = CPU_INFO_PLUS_PLUGIN(user_data);
  cpu_info_plus_plugin_handle_method_call(plugin, method_call);
}

void cpu_info_plus_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  CpuInfoPlusPlugin* plugin = CPU_INFO_PLUS_PLUGIN(
      g_object_new(cpu_info_plus_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "cpu_info_plus",
                            FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  g_object_unref(plugin);
}
