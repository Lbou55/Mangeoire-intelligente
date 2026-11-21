/// Server address. After deploying on Render, either edit [defaultValue]
/// or build with:  flutter run --dart-define=API_BASE_URL=https://xxx.onrender.com
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://mangeoire-server.onrender.com',
  );

  static Uri uri(String path, [Map<String, dynamic>? query]) {
    final base = Uri.parse(apiBaseUrl);
    return base.replace(
      path: '${base.path.replaceAll(RegExp(r'/+$'), '')}$path',
      queryParameters: query == null
          ? null
          : {
              for (final e in query.entries)
                if (e.value != null) e.key: '${e.value}'
            },
    );
  }

  static const Duration requestTimeout = Duration(seconds: 60);
  static const Duration wakingHintAfter = Duration(seconds: 5);
}
