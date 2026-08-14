import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The blue gradient action button used by the auth screens, with its
/// decorative bubbles. Shows a spinner and ignores taps while [isLoading].
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: Container(
        // Fills whatever the parent allows rather than a fixed 319px, which
        // left the button narrower than the fields above it and would overflow
        // a screen narrower than that. The auth forms already cap their width.
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          gradient: const LinearGradient(
            colors: [
              Color.fromARGB(255, 0, 47, 255),
              Color.fromARGB(255, 41, 141, 255),
            ],
          ),
        ),
        // The bubbles are anchored to the right edge so the button can be
        // resized without them drifting into the middle of the label.
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              right: -19,
              top: 19,
              child: Opacity(
                opacity: 0.5,
                child: Container(
                  width: 60,
                  height: 60,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    border: Border.all(
                      width: 12,
                      color: const Color.fromARGB(255, 0, 47, 255),
                    ),
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 49,
              top: 29,
              child: Opacity(
                opacity: 0.5,
                child: Container(
                  width: 10,
                  height: 10,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    border: Border.all(width: 3),
                    color: const Color.fromARGB(255, 0, 47, 255),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 3,
              top: 36,
              child: Opacity(
                opacity: 0.3,
                child: Container(
                  width: 5,
                  height: 5,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 18,
              top: -10,
              child: Opacity(
                opacity: 0.3,
                child: Container(
                  width: 20,
                  height: 20,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            Center(
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Text(
                      label,
                      style: GoogleFonts.lato(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
