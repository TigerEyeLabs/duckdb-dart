#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint duckdb.podspec' to validate before publishing.
#
Pod::Spec.new do |s|
    s.name             = 'dart_duckdb'
    s.version          = '1.0.0'
    s.summary          = 'A new flutter plugin project.'
    s.description      = <<-DESC
  A new flutter plugin project.
                         DESC
    s.homepage         = 'https://tigereye.com'
    s.license          = { :file => '../LICENSE' }
    s.author           = { 'Tigereye' => 'email@example.com' }
    s.source           = { :path => '.' }
    s.source_files     = 'Classes/**/*'
    s.dependency 'FlutterMacOS'

    s.platform = :osx, '10.13'
    s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
    s.swift_version = '5.0'

    s.vendored_libraries = 'Libraries/release/libduckdb.dylib'
end
