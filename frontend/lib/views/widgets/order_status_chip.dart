import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared by the buyer's order list and the vendor's, so the same status never
/// reads as two different colours on the two sides of the same order.
class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip({super.key, required this.status});

  final String status;

  static Color colorFor(String status) => switch (status) {
    'delivered' => Colors.green.shade700,
    'shipped' => Colors.blue.shade700,
    'cancelled' => Colors.redAccent,
    _ => Colors.orange.shade800,
  };

  @override
  Widget build(BuildContext context) {
    if (status.isEmpty) return const SizedBox.shrink();
    final color = colorFor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: GoogleFonts.nunitoSans(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
