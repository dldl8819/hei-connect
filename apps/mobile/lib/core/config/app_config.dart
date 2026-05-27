class AppConfig {
  const AppConfig._();

  static const apiBaseUrl = String.fromEnvironment(
    'CONNECT_PUBLIC_API_URL',
    defaultValue: 'http://localhost:8080',
  );
}
