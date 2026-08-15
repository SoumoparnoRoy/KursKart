/// One person's review of one product. [userName] is a copy taken when the
/// review was written, so it keeps reading correctly if the author later
/// changes their name.
class Review {
  const Review({
    required this.id,
    required this.productId,
    required this.userId,
    required this.userName,
    required this.rating,
    required this.comment,
    required this.writtenAt,
  });

  final String id;
  final String productId;
  final String userId;
  final String userName;
  final int rating;
  final String comment;
  final DateTime? writtenAt;

  /// Falls back to something displayable: an account created before names were
  /// required, or a review written by a since-deleted user.
  String get displayName => userName.trim().isEmpty ? 'A customer' : userName;

  factory Review.fromMap(Map<String, dynamic> map) {
    return Review(
      id: map['_id'] as String? ?? '',
      productId: map['product'] as String? ?? '',
      userId: map['user'] as String? ?? '',
      userName: map['userName'] as String? ?? '',
      rating: (map['rating'] as num?)?.toInt() ?? 0,
      comment: map['comment'] as String? ?? '',
      writtenAt: DateTime.tryParse(map['createdAt'] as String? ?? ''),
    );
  }
}

/// A page of reviews plus the counts behind the average, which the server sends
/// alongside so the bars can be drawn without a second request.
class ReviewPage {
  const ReviewPage({
    required this.reviews,
    required this.distribution,
    required this.total,
  });

  final List<Review> reviews;

  /// Stars (1-5) to how many reviews gave that many.
  final Map<int, int> distribution;

  final int total;

  static const empty = ReviewPage(
    reviews: [],
    distribution: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
    total: 0,
  );

  /// The largest bar, used to scale the others. Never zero, so callers can
  /// divide by it without guarding.
  int get busiestBand =>
      distribution.values.fold(1, (a, b) => b > a ? b : a);

  factory ReviewPage.fromMap(Map<String, dynamic> map) {
    final raw = map['distribution'] as Map<String, dynamic>? ?? const {};

    return ReviewPage(
      reviews: (map['reviews'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Review.fromMap)
          .toList(),
      distribution: {
        for (var star = 1; star <= 5; star += 1)
          star: (raw['$star'] as num?)?.toInt() ?? 0,
      },
      total: (map['total'] as num?)?.toInt() ?? 0,
    );
  }
}

/// What the signed-in user may do with a product's reviews: whether they have
/// bought and received it, and what they already wrote.
class ReviewEligibility {
  const ReviewEligibility({required this.canReview, required this.mine});

  final bool canReview;
  final Review? mine;

  static const none = ReviewEligibility(canReview: false, mine: null);

  factory ReviewEligibility.fromMap(Map<String, dynamic> map) {
    final mine = map['review'];

    return ReviewEligibility(
      canReview: map['canReview'] as bool? ?? false,
      mine: mine is Map<String, dynamic> ? Review.fromMap(mine) : null,
    );
  }
}
