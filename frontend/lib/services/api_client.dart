import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:kurskart/global_variables.dart';

/// Raised for any request the user should be told about. [message] is already
/// human-readable, so callers can show it directly.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;

  /// The HTTP status, or null when the request never got a response at all.
  /// Callers need this to tell "the server rejected us" from "we could not
  /// reach the server", which are very different situations for a stored token.
  final int? statusCode;

  @override
  String toString() => message;
}

/// Thin wrapper over http that decodes JSON and turns every failure into an
/// [ApiException] carrying the server's own message where there is one.
class ApiClient {
  const ApiClient({http.Client? client}) : _client = client;

  final http.Client? _client;

  http.Client get _http => _client ?? http.Client();

  /// Without this a request to an unreachable host sits on the OS-level TCP
  /// timeout, which left the app on a spinner for roughly 40 seconds.
  static const _timeout = Duration(seconds: 12);

  static const _jsonHeaders = <String, String>{
    'Content-Type': 'application/json; charset=UTF-8',
  };

  Map<String, String> _headers(String? token) => {
    ..._jsonHeaders,
    'x-auth-token': ?token,
  };

  Future<Map<String, dynamic>> get(String path, {String? token}) {
    return _send(() => _http.get(Uri.parse('$uri$path'), headers: _headers(token)));
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
    String? token,
  }) {
    return _send(
      () => _http.post(
        Uri.parse('$uri$path'),
        headers: _headers(token),
        // Omit the body entirely when there is none. Encoding null sends the
        // literal "null", which Express's strict JSON parser rejects with an
        // HTML 400 rather than the JSON error shape we expect.
        body: body == null ? null : jsonEncode(body),
      ),
    );
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Object? body,
    String? token,
  }) {
    return _send(
      () => _http.patch(
        Uri.parse('$uri$path'),
        headers: _headers(token),
        body: body == null ? null : jsonEncode(body),
      ),
    );
  }

  Future<Map<String, dynamic>> delete(String path, {String? token}) {
    return _send(
      () => _http.delete(Uri.parse('$uri$path'), headers: _headers(token)),
    );
  }

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request,
  ) async {
    late final http.Response response;
    try {
      response = await request().timeout(_timeout);
    } on TimeoutException {
      throw const ApiException(
        'The server took too long to respond. Please try again.',
      );
    } on SocketException {
      throw const ApiException(
        'Could not reach the server. Check your connection and try again.',
      );
    } on HttpException {
      throw const ApiException(
        'Could not reach the server. Please try again.',
      );
    }

    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw ApiException(
        'Unexpected response from the server (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode == 200 || response.statusCode == 201) {
      return body;
    }

    final message = body['msg'] ?? body['error'];
    throw ApiException(
      message is String
          ? message
          : 'Something went wrong (${response.statusCode}).',
      statusCode: response.statusCode,
    );
  }
}
