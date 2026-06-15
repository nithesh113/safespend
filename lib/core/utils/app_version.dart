/// App version information, kept in sync with pubspec.yaml.
class AppVersion {
  /// Version string shown in the UI and README.
  /// Bump this alongside the version: field in pubspec.yaml.
  static const String current = 'v1.0.0';

  /// Build number from pubspec.yaml (after the + sign).
  static const int buildNumber = 1;

  /// Human-readable full version string.
  static const String full = 'v1.0.0 (build 1)';
}