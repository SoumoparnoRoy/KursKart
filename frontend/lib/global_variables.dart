/// Base URL of the KursKart backend.
///
/// Defaults to the Android emulator's alias for the host machine's localhost.
/// Override it at launch to point at a backend on your LAN, e.g. when running
/// on a physical device:
///
///   flutter run --dart-define=API_URL=http://YOUR_COMPUTER_IP:3000
const String uri = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://10.0.2.2:3000',
);
