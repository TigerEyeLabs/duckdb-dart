#include "include/dart_duckdb/dart_duckdb_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "dart_duckdb_plugin.h"

void DartDuckdbPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  dart_duckdb::DartDuckdbPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
