import 'package:kurskart/models/review.dart';
import 'package:kurskart/services/api_client.dart';

class ReviewService {
  const ReviewService({ApiClient client = const ApiClient()})
    : _client = client;

  final ApiClient _client;

  /// Public — reading reviews needs no account.
  Future<ReviewPage> fetchReviews(String productId) async {
    return ReviewPage.fromMap(
      await _client.get('/api/products/$productId/reviews'),
    );
  }

  /// Whether this user may review the product, and what they already wrote.
  /// Signed-out callers get [ReviewEligibility.none] rather than an error —
  /// having no account is a normal state, not a failure.
  Future<ReviewEligibility> fetchEligibility(
    String token,
    String productId,
  ) async {
    try {
      return ReviewEligibility.fromMap(
        await _client.get('/api/products/$productId/reviews/mine', token: token),
      );
    } on ApiException catch (e) {
      if (e.statusCode == 401) return ReviewEligibility.none;
      rethrow;
    }
  }

  Future<void> create(
    String token,
    String productId, {
    required int rating,
    required String comment,
  }) async {
    await _client.post(
      '/api/products/$productId/reviews',
      token: token,
      body: {'rating': rating, 'comment': comment},
    );
  }

  Future<void> update(
    String token,
    String reviewId, {
    required int rating,
    required String comment,
  }) async {
    await _client.patch(
      '/api/reviews/$reviewId',
      token: token,
      body: {'rating': rating, 'comment': comment},
    );
  }

  Future<void> remove(String token, String reviewId) async {
    await _client.delete('/api/reviews/$reviewId', token: token);
  }
}
