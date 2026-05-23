class AppConfig {
  const AppConfig._();

  // Android emulator: 10.0.2.2, physical device: host machine LAN IP.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://serokrkrt-terapi-ai-backend.hf.space',
  );

  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );
}
