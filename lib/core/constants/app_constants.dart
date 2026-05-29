enum ProviderProtocol {
  openai,
  claude,
}

class AppConstants {
  const AppConstants._();

  static const appName = 'NewChat';
  static const schemaVersion = 1;
  static const streamFlushIntervalMs = 500;
}
