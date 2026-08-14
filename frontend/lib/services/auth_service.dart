import 'package:kurskart/models/user.dart';
import 'package:kurskart/services/api_client.dart';

export 'package:kurskart/services/api_client.dart' show ApiException;

/// A successful sign-in: the issued token plus the user it belongs to.
class AuthResult {
  const AuthResult({required this.token, required this.user});

  final String token;
  final User user;
}

class AuthService {
  const AuthService({ApiClient client = const ApiClient()}) : _client = client;

  final ApiClient _client;

  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    await _client.post(
      '/api/signup',
      body: {'fullName': fullName, 'email': email, 'password': password},
    );
  }

  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    final body = await _client.post(
      '/api/signin',
      body: {'email': email, 'password': password},
    );

    final token = body['token'] as String?;
    if (token == null) {
      throw const ApiException('Server did not return a session token.');
    }
    return AuthResult(token: token, user: User.fromMap(body));
  }

  /// Confirms a stored token still corresponds to a live session.
  Future<User> fetchUser(String token) async {
    final body = await _client.get('/api/user', token: token);
    return User.fromMap(body);
  }

  Future<User> saveAddress({
    required String token,
    required String addressLine,
    required String locality,
    required String city,
    required String state,
    required String pincode,
    required String phone,
  }) async {
    final body = await _client.patch(
      '/api/user/address',
      token: token,
      body: {
        'addressLine': addressLine,
        'locality': locality,
        'city': city,
        'state': state,
        'pincode': pincode,
        'phone': phone,
      },
    );
    return User.fromMap(body);
  }
}
