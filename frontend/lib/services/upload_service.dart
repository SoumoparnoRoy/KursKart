import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:kurskart/services/api_client.dart';

/// Uploads product images to Cloudinary.
///
/// The file goes straight from the device to Cloudinary; our server only issues
/// a short-lived signature. That keeps the API secret server-side and keeps the
/// bytes out of the backend, which on Vercel could not accept them anyway — a
/// serverless request body is capped well below what a camera produces.
class UploadService {
  const UploadService({ApiClient client = const ApiClient(), http.Client? httpClient})
    : _client = client,
      _httpClient = httpClient;

  final ApiClient _client;
  final http.Client? _httpClient;

  http.Client get _http => _httpClient ?? http.Client();

  /// Cloudinary is a third party on a phone connection, and the image is
  /// already downscaled before it gets here, so this is longer than the
  /// backend's own timeout but still short enough to fail rather than hang.
  static const _timeout = Duration(seconds: 45);

  /// Uploads [file] and returns the delivery URL to store on the product.
  Future<String> uploadProductImage(String token, File file) async {
    final signature = await _client.post('/api/uploads/signature', token: token);

    final cloudName = signature['cloudName'] as String?;
    final apiKey = signature['apiKey'] as String?;
    final timestamp = signature['timestamp'];
    final folder = signature['folder'] as String?;
    final signed = signature['signature'] as String?;

    if (cloudName == null || apiKey == null || folder == null || signed == null) {
      throw const ApiException('Image uploads are not available right now.');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload'),
    );

    // Cloudinary checks the signature against exactly these fields, so an extra
    // or missing one fails the upload rather than being ignored.
    request.fields['api_key'] = apiKey;
    request.fields['timestamp'] = '$timestamp';
    request.fields['folder'] = folder;
    request.fields['signature'] = signed;
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    late final http.Response response;
    try {
      final streamed = await _http.send(request).timeout(_timeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw const ApiException('The upload took too long. Please try again.');
    } on SocketException {
      throw const ApiException('Could not upload the image. Check your connection.');
    }

    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw ApiException('Unexpected response from the image service (${response.statusCode}).');
    }

    if (response.statusCode != 200) {
      final error = body['error'];
      final message = error is Map<String, dynamic> ? error['message'] : null;
      throw ApiException(
        message is String ? message : 'The image could not be uploaded.',
        statusCode: response.statusCode,
      );
    }

    final url = body['secure_url'] as String?;
    if (url == null) {
      throw const ApiException('The image service did not return a URL.');
    }
    return url;
  }

  /// Deletes an image that was uploaded but never saved onto a product —
  /// the vendor picked a photo and then replaced or removed it. Without this
  /// the first upload is stranded, since nothing ever referenced it.
  ///
  /// Silent by design: it is housekeeping the vendor did not ask for, so a
  /// failure is not worth a message. `npm run cloudinary:prune` catches
  /// whatever this misses.
  Future<void> discardUpload(String token, String url) async {
    try {
      await _client.delete('/api/uploads', token: token, body: {'url': url});
    } catch (_) {
      // Ignored on purpose.
    }
  }
}
