class AppConfig {
  const AppConfig._();

  // Android emulator: 10.0.2.2, physical device: host machine LAN IP.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://serokrkrt-terapi-ai-backend.hf.space',
  );

  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '100911529506-28l0b87mb5csq79bu2o8g7kam98uu8lg.apps.googleusercontent.com',
  );

  static const String elevenLabsApiKey = String.fromEnvironment(
    'ELEVENLABS_API_KEY',
    defaultValue: 'sk_28960a27dcfbffe0e1e66c9124e316008fa75c6c9d57dfcb',
  );

  static const String elevenLabsVoiceId = String.fromEnvironment(
    'ELEVENLABS_VOICE_ID',
    defaultValue: 'EXAVITQu4vr4xnSDxMaL',
  );
}
