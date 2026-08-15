import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurskart/models/review.dart';
import 'package:kurskart/providers/auth_provider.dart';
import 'package:kurskart/providers/product_provider.dart';
import 'package:kurskart/services/review_service.dart';

final reviewServiceProvider = Provider<ReviewService>(
  (ref) => const ReviewService(),
);

/// The public review list for one product.
final reviewsProvider = FutureProvider.family<ReviewPage, String>(
  (ref, productId) => ref.read(reviewServiceProvider).fetchReviews(productId),
);

/// Whether the signed-in user may review this product, and what they wrote.
/// Watches [authProvider] so signing in or out re-asks rather than leaving a
/// stale answer behind.
final reviewEligibilityProvider =
    FutureProvider.family<ReviewEligibility, String>((ref, productId) async {
      final user = ref.watch(authProvider).value;
      if (user == null) return ReviewEligibility.none;

      final token = await ref.read(tokenStorageProvider).read();
      if (token == null) return ReviewEligibility.none;

      return ref
          .read(reviewServiceProvider)
          .fetchEligibility(token, productId);
    });

/// Writes go through here so every one of them refreshes the same three things:
/// the list, the caller's own eligibility, and the product whose average the
/// server just recomputed.
final reviewWriterProvider = Provider<ReviewWriter>(ReviewWriter.new);

class ReviewWriter {
  ReviewWriter(this._ref);

  final Ref _ref;

  Future<String> get _token async {
    final token = await _ref.read(tokenStorageProvider).read();
    if (token == null) throw StateError('Signed out');
    return token;
  }

  ReviewService get _service => _ref.read(reviewServiceProvider);

  Future<void> submit(
    String productId, {
    required int rating,
    required String comment,
    String? editing,
  }) async {
    final token = await _token;

    if (editing == null) {
      await _service.create(token, productId, rating: rating, comment: comment);
    } else {
      await _service.update(token, editing, rating: rating, comment: comment);
    }

    _refresh(productId);
  }

  Future<void> remove(String productId, String reviewId) async {
    await _service.remove(await _token, reviewId);
    _refresh(productId);
  }

  /// The product's `rating` and `ratingCount` are denormalised on the server,
  /// so the feed and the detail page are both stale after any write.
  void _refresh(String productId) {
    _ref.invalidate(reviewsProvider(productId));
    _ref.invalidate(reviewEligibilityProvider(productId));
    _ref.invalidate(productDetailProvider(productId));
    _ref.invalidate(productFeedProvider);
  }
}
