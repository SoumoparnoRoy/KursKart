import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kurskart/models/product.dart';
import 'package:kurskart/models/review.dart';
import 'package:kurskart/providers/review_provider.dart';
import 'package:kurskart/views/screens/review_form_screen.dart';
import 'package:kurskart/views/widgets/star_rating.dart';

/// The reviews block on a product page: the average and its breakdown, the
/// caller's own review if they wrote one, and everybody else's.
class ReviewsSection extends ConsumerWidget {
  const ReviewsSection({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(reviewsProvider(product.id));
    final eligibility = ref
        .watch(reviewEligibilityProvider(product.id))
        .value ??
        ReviewEligibility.none;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Reviews',
              style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            if (eligibility.canReview)
              TextButton.icon(
                icon: Icon(
                  eligibility.mine == null ? Icons.rate_review_outlined : Icons.edit_outlined,
                  size: 18,
                ),
                label: Text(eligibility.mine == null ? 'Write' : 'Edit'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReviewFormScreen(
                      productId: product.id,
                      productName: product.name,
                      existing: eligibility.mine,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        page.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Could not load reviews.',
                    style: GoogleFonts.nunitoSans(color: Colors.black54),
                  ),
                ),
                TextButton(
                  onPressed: () => ref.invalidate(reviewsProvider(product.id)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (data) => data.total == 0
              ? _Empty(canReview: eligibility.canReview)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Summary(product: product, page: data),
                    const SizedBox(height: 16),
                    for (final review in data.reviews)
                      _ReviewTile(
                        review: review,
                        isMine: review.id == eligibility.mine?.id,
                      ),
                    // The API pages at 20; nothing in the app asks for page 2
                    // yet, so say so rather than silently truncating.
                    if (data.total > data.reviews.length)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Showing ${data.reviews.length} of ${data.total} reviews.',
                          style: GoogleFonts.nunitoSans(
                            fontSize: 12,
                            color: Colors.black45,
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.product, required this.page});

  final Product product;
  final ReviewPage page;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              product.rating.toStringAsFixed(1),
              style: GoogleFonts.lato(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            StarRating(rating: product.rating, size: 14),
            const SizedBox(height: 2),
            Text(
              '${page.total} review${page.total == 1 ? '' : 's'}',
              style: GoogleFonts.nunitoSans(
                fontSize: 11,
                color: Colors.black45,
              ),
            ),
          ],
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            children: [
              for (var star = 5; star >= 1; star -= 1)
                _Band(
                  star: star,
                  count: page.distribution[star] ?? 0,
                  busiest: page.busiestBand,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Band extends StatelessWidget {
  const _Band({
    required this.star,
    required this.count,
    required this.busiest,
  });

  final int star;
  final int count;
  final int busiest;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          SizedBox(
            width: 12,
            child: Text(
              '$star',
              style: GoogleFonts.nunitoSans(fontSize: 11, color: Colors.black54),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: count / busiest,
                minHeight: 6,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(Colors.amber.shade700),
              ),
            ),
          ),
          SizedBox(
            width: 22,
            child: Text(
              '$count',
              textAlign: TextAlign.end,
              style: GoogleFonts.nunitoSans(fontSize: 11, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review, required this.isMine});

  final Review review;
  final bool isMine;

  String get _writtenLabel {
    final at = review.writtenAt?.toLocal();
    if (at == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${at.day} ${months[at.month - 1]} ${at.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMine ? Colors.blue.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isMine ? Colors.blue.shade100 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StarRating(rating: review.rating.toDouble(), size: 14),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  isMine ? 'You' : review.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunitoSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              if (_writtenLabel.isNotEmpty)
                Text(
                  _writtenLabel,
                  style: GoogleFonts.nunitoSans(
                    fontSize: 11,
                    color: Colors.black45,
                  ),
                ),
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              review.comment,
              style: GoogleFonts.nunitoSans(
                fontSize: 13,
                height: 1.4,
                color: Colors.black87,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.canReview});

  final bool canReview;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Text(
        canReview
            ? 'No reviews yet. You have had this delivered, so yours would be the first.'
            : 'No reviews yet. Only customers who have received this can review it.',
        style: GoogleFonts.nunitoSans(color: Colors.black54, height: 1.4),
      ),
    );
  }
}
