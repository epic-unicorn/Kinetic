import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

class MockHttpClient extends Mock implements http.Client {}

/// Call this in [setUpAll] to register the URI fallback required by mocktail.
void registerFallbackValues() {
  registerFallbackValue(Uri.parse('http://localhost:5984'));
  registerFallbackValue(<String, String>{});
  registerFallbackValue(<int>[]);
}
