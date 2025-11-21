#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint duckdb.podspec' to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'dart_duckdb'
  s.version          = File.read(File.join('..', 'pubspec.yaml')).match(/version:\s+(\d+\.\d+\.\d+)/)[1]
  s.summary          = 'A new flutter plugin project.'
  s.description      = <<-DESC
A new flutter plugin project.
                        DESC
  s.homepage         = 'https://tigereye.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Tigereye' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'

  s.platform = :ios, '11.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'

  s.ios.vendored_framework = 'Libraries/release/duckdb.framework'

  # Use a pre-install hook to check if the library exists
  s.prepare_command = <<-CMD
    mkdir -p Libraries/release  # Ensure the directory exists
    if [ ! -d "Libraries/release/duckdb.framework" ]; then
      echo "Downloading DuckDB library..."
      curl -L -o duckdb-framework-ios.zip "https://github.com/TigerEyeLabs/duckdb-dart/releases/download/v1.4.4/duckdb-framework-ios.zip"
      unzip -o duckdb-framework-ios.zip -d Libraries/release/
      rm duckdb-framework-ios.zip
    else
      echo "DuckDB library already exists."
    fi
  CMD
end
