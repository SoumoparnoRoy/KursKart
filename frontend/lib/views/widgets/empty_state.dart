import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A centred panel for the two cases a list-like screen has to handle when it
/// has nothing to show: genuinely empty, or a failed load. Shared so the two do
/// not drift apart visually — an error that looks unlike the empty state reads
/// as a different kind of problem than it is.
///
/// [onRetry] is what separates them: an empty screen has nothing to retry.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 44, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.lato(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunitoSans(color: Colors.black54),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
