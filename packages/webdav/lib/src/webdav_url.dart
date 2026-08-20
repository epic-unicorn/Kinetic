/// Validates and normalises WebDAV server URLs for Kinetic.
class WebDavUrl {
  WebDavUrl._();

  /// Returns a normalised HTTPS URL (no trailing slash), or throws
  /// [FormatException] if the URL is missing/invalid or not HTTPS.
  static String requireHttps(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('WebDAV server URL is required.');
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const FormatException('Invalid WebDAV server URL.');
    }
    if (uri.scheme.toLowerCase() != 'https') {
      throw const FormatException(
        'WebDAV URL must use HTTPS (http:// is not allowed).',
      );
    }
    var out = uri.toString();
    if (out.endsWith('/')) {
      out = out.substring(0, out.length - 1);
    }
    return out;
  }

  /// Rewrites a legacy `http://` URL to `https://` then validates.
  static String coerceHttps(String raw) {
    final trimmed = raw.trim();
    if (trimmed.toLowerCase().startsWith('http://')) {
      return requireHttps('https://${trimmed.substring(7)}');
    }
    return requireHttps(trimmed);
  }

  /// Soft check for UI validators — returns an error message or `null`.
  static String? validationError(
    String? raw, {
    String emptyMessage = 'Enter the server URL',
  }) {
    if (raw == null || raw.trim().isEmpty) return emptyMessage;
    try {
      requireHttps(raw);
      return null;
    } on FormatException catch (e) {
      return e.message;
    }
  }
}
