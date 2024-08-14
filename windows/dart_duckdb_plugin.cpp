#include "dart_duckdb_plugin.h"

#include <memory>

namespace dart_duckdb {

// static
void DartDuckdbPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto plugin = std::make_unique<DartDuckdbPlugin>();
  registrar->AddPlugin(std::move(plugin));
}

DartDuckdbPlugin::DartDuckdbPlugin() {}

DartDuckdbPlugin::~DartDuckdbPlugin() {}

}  // namespace dart_duckdb