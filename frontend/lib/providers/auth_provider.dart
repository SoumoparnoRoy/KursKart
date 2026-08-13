import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kurskart/models/user.dart';
import 'package:kurskart/services/auth_service.dart';
import 'package:kurskart/services/token_storage.dart';

final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => const TokenStorage(FlutterSecureStorage()),
);

final authServiceProvider = Provider<AuthService>((ref) => const AuthService());

/// The signed-in user, or null when signed out.
///
/// The initial [build] is what gates the app on launch: it restores a stored
/// token and asks the server whether it is still good, so a returning user
/// skips the login screen.
final authProvider = AsyncNotifierProvider<AuthNotifier, User?>(
  AuthNotifier.new,
);

class AuthNotifier extends AsyncNotifier<User?> {
  TokenStorage get _storage => ref.read(tokenStorageProvider);
  AuthService get _service => ref.read(authServiceProvider);

  @override
  Future<User?> build() async {
    final token = await _storage.read();
    if (token == null) return null;

    try {
      return await _service.fetchUser(token);
    } on AuthException {
      // Expired or revoked — drop it so we don't retry with it every launch.
      await _storage.clear();
      return null;
    }
  }

  /// Throws [AuthException] on failure so the screen can surface the message.
  /// Deliberately does not move state to loading: that would swap the login
  /// screen out mid-request and take its ScaffoldMessenger with it.
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final result = await _service.signIn(email: email, password: password);
    await _storage.write(result.token);
    state = AsyncValue.data(result.user);
  }

  /// Creates the account but does not sign in — the backend issues no token on
  /// signup, so the user lands on the login screen afterwards.
  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
  }) {
    return _service.signUp(
      fullName: fullName,
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _storage.clear();
    state = const AsyncValue.data(null);
  }
}
