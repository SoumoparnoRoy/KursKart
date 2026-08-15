import 'package:flutter/material.dart';

/// Read-only stars. Halves are shown for averages, so 4.3 does not round up to
/// a confident four and a half.
class StarRating extends StatelessWidget {
  const StarRating({super.key, required this.rating, this.size = 16});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var star = 1; star <= 5; star += 1)
          Icon(
            rating >= star
                ? Icons.star
                : rating >= star - 0.5
                ? Icons.star_half
                : Icons.star_border,
            size: size,
            color: Colors.amber.shade700,
          ),
      ],
    );
  }
}

/// The tappable version used in the review form. Whole stars only, matching
/// what the server accepts.
class StarPicker extends StatelessWidget {
  const StarPicker({
    super.key,
    required this.rating,
    required this.onChanged,
    this.size = 40,
  });

  final int rating;
  final ValueChanged<int> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var star = 1; star <= 5; star += 1)
          IconButton(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            constraints: const BoxConstraints(),
            iconSize: size,
            tooltip: '$star star${star == 1 ? '' : 's'}',
            icon: Icon(
              star <= rating ? Icons.star : Icons.star_border,
              color: Colors.amber.shade700,
            ),
            onPressed: () => onChanged(star),
          ),
      ],
    );
  }
}
