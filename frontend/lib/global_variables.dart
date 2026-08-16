/// Base URL of the KursKart backend.
///
/// Defaults to the Android emulator's alias for the host machine's localhost.
/// Override it at launch to point at a backend on your LAN, e.g. when running
/// on a physical device:
///
///   flutter run --dart-define=API_URL=http://YOUR_COMPUTER_IP:3000
const String _apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://10.0.2.2:3000',
);

/// Trailing slashes are stripped because every path passed to ApiClient
/// already begins with one. `API_URL=https://host/` otherwise produced
/// `https://host//api/signin`, which Vercel answers with a 308 to the
/// single-slash path — and Dart does not follow redirects on a POST, so the
/// redirect itself came back as the login response.
final String uri = _apiUrl.replaceFirst(RegExp(r'/+$'), '');
