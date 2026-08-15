import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kurskart/models/review.dart';
import 'package:kurskart/providers/review_provider.dart';
import 'package:kurskart/services/api_client.dart';
import 'package:kurskart/views/widgets/star_rating.dart';

/// Writes or edits the caller's review of one product. Passing [existing] turns
/// it into an edit, which also offers deletion.
class ReviewFormScreen extends ConsumerStatefulWidget {
  const ReviewFormScreen({
    super.key,
    required this.productId,
    required this.productName,
    this.existing,
  });

  static const _accent = Color.fromARGB(255, 0, 47, 255);

  final String productId;
  final String productName;
  final Review? existing;

  @override
  ConsumerState<ReviewFormScreen> createState() => _ReviewFormScreenState();
}

class _ReviewFormScreenState extends ConsumerState<ReviewFormScreen> {
  late int _rating = widget.existing?.rating ?? 0;
  late final _comment = TextEditingController(
    text: widget.existing?.comment ?? '',
  );

  bool _busy = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  bool get _isEdit => widget.existing != null;

  Future<void> _save() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a star rating first')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _busy = true);
    try {
      await ref.read(reviewWriterProvider).submit(
        widget.productId,
        rating: _rating,
        comment: _comment.text.trim(),
        editing: widget.existing?.id,
      );
      messenger.showSnackBar(
        SnackBar(content: Text(_isEdit ? 'Review updated' : 'Thanks for your review')),
      );
      navigator.pop(true);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not save your review')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete your review?'),
        content: const Text(
          'It will be removed from the product page and the rating will be '
          'recalculated without it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _busy = true);
    try {
      await ref
          .read(reviewWriterProvider)
          .remove(widget.productId, widget.existing!.id);
      messenger.showSnackBar(const SnackBar(content: Text('Review deleted')));
      navigator.pop(true);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not delete your review')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _isEdit ? 'Edit your review' : 'Write a review',
          style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              color: Colors.redAccent,
              onPressed: _busy ? null : _confirmDelete,
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Text(
                  widget.productName,
                  style: GoogleFonts.nunitoSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Your rating',
                  style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Center(
                  child: StarPicker(
                    rating: _rating,
                    onChanged: (v) => setState(() => _rating = v),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Your review',
                  style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _comment,
                  maxLines: 6,
                  maxLength: 1000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'What did you think of it? (optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: ReviewFormScreen._accent,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: _busy ? null : _save,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(_isEdit ? 'Save changes' : 'Post review'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
