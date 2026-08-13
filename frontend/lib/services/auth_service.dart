import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:kurskart/global_variables.dart';
import 'package:kurskart/models/user.dart';

/// Raised for any auth failure the user should be told about. [message] is
/// already human-readable, so callers can show it directly.
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A successful sign-in: the issued token plus the user it belongs to.
class AuthResult {
  const AuthResult({required this.token, required this.user});

  final String token;
  final User user;
}

class AuthService {
  const AuthService({http.Client? client}) : _client = client;

  final http.Client? _client;

  http.Client get _http => _client ?? http.Client();

  static const _jsonHeaders = <String, String>{
    'Content-Type': 'application/json; charset=UTF-8',
  };

  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    await _send(
      () => _http.post(
        Uri.parse('$uri/api/signup'),
        headers: _jsonHeaders,
        body: jsonEncode({
          'fullName': fullName,
          'email': email,
          'password': password,
        }),
      ),
    );
  }

  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    final body = await _send(
      () => _http.post(
        Uri.parse('$uri/api/signin'),
        headers: _jsonHeaders,
        body: jsonEncode({'email': email, 'password': password}),
      ),
    );

    final token = body['token'] as String?;
    if (token == null) {
      throw const AuthException('Server did not return a session token.');
    }
    return AuthResult(token: token, user: User.fromMap(body));
  }

  /// Confirms a stored token still corresponds to a live session.
  Future<User> fetchUser(String token) async {
    final body = await _send(
      () => _http.get(
        Uri.parse('$uri/api/user'),
        headers: {..._jsonHeaders, 'x-auth-token': token},
      ),
    );
    return User.fromMap(body);
  }

  /// Runs [request] and turns anything that is not a success into an
  /// [AuthException] carrying a message worth showing to the user.
  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request,
  ) async {
    late final http.Response response;
    try {
      response = await request();
    } on SocketException {
      throw const AuthException(
        'Could not reach the server. Check your connection and try again.',
      );
    } on HttpException {
      throw const AuthException('Could not reach the server. Please try again.');
    }

    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw AuthException(
        'Unexpected response from the server (${response.statusCode}).',
      );
    }

    if (response.statusCode == 200 || response.statusCode == 201) {
      return body;
    }

    final message = body['msg'] ?? body['error'];
    throw AuthException(
      message is String
          ? message
          : 'Something went wrong (${response.statusCode}).',
    );
  }
}
