#ifndef FLUTTER_PLUGIN_DUCKDB_LIBS_PLUGIN_H_
#define FLUTTER_PLUGIN_DUCKDB_LIBS_PLUGIN_H_

#include <flutter/plugin_registrar_windows.h>

namespace dart_duckdb {

class DartDuckdbPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  DartDuckdbPlugin();

  virtual ~DartDuckdbPlugin();

  // Disallow copy and assign.
  DartDuckdbPlugin(const DartDuckdbPlugin&) = delete;
  DartDuckdbPlugin& operator=(const DartDuckdbPlugin&) = delete;
};

}  // namespace dart_duckdb

#endif  // FLUTTER_PLUGIN_DUCKDB_LIBS_PLUGIN_H_