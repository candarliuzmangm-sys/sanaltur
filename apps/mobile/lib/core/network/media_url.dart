import '../config/env.dart';

/// API stores absolute URLs (often 10.0.2.2 for Android). Rewrite for current client.
String resolveMediaUrl(String url) {
  try {
    final uri = Uri.parse(url);
    if (!uri.path.startsWith('/uploads/')) return url;
    final base = Uri.parse(Env.apiBaseUrl);
    return Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: uri.path,
    ).toString();
  } catch (_) {
    return url;
  }
}
