import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kurskart/models/product.dart';
import 'package:kurskart/providers/cart_provider.dart';
import 'package:kurskart/providers/product_provider.dart';
import 'package:kurskart/services/api_client.dart';
import 'package:kurskart/services/manage_http_response.dart';

/// [initialProduct] is the copy the feed already has, so tapping a card renders
/// immediately instead of showing a spinner while the detail request runs.
class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({
    super.key,
    required this.productId,
    this.initialProduct,
  });

  static const _accent = Color.fromARGB(255, 0, 47, 255);

  final String productId;
  final Product? initialProduct;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(productDetailProvider(productId));

    // A 404 means the product is genuinely gone, not that the request failed.
    // Falling back to the feed's copy would show a listing that cannot be
    // bought — the user would only find out when Add to Cart failed.
    final error = async.error;
    final isGone = error is ApiException && error.statusCode == 404;

    // The feed is now known to be stale, so refresh it. Done after the frame
    // because invalidating a provider during build is not allowed.
    if (isGone) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.invalidate(productFeedProvider);
      });
    }

    final product = isGone ? null : (async.value ?? initialProduct);

    if (product == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: isGone
              ? _Notice(
                  icon: Icons.remove_shopping_cart_outlined,
                  title: 'No longer available',
                  detail: 'This product has been removed from the store.',
                  actionLabel: 'Back to products',
                  onAction: () => Navigator.of(context).pop(),
                )
              : async.hasError
              ? _Notice(
                  icon: Icons.cloud_off,
                  title: 'Could not load this product',
                  detail: '$error',
                  actionLabel: 'Retry',
                  onAction: () =>
                      ref.invalidate(productDetailProvider(productId)),
                )
              : const CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          product.store?.name ?? 'Product',
          style: GoogleFonts.nunitoSans(fontSize: 16, color: Colors.black87),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _Gallery(images: product.images),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: GoogleFonts.lato(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            product.formattedPrice,
                            style: GoogleFonts.lato(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: _accent,
                            ),
                          ),
                          const Spacer(),
                          if (product.rating > 0) ...[
                            const Icon(
                              Icons.star,
                              size: 18,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              product.rating.toStringAsFixed(1),
                              style: GoogleFonts.nunitoSans(fontSize: 15),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      _StockBadge(stock: product.stock),
                      const SizedBox(height: 20),
                      Text(
                        'About this item',
                        style: GoogleFonts.nunitoSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        product.description.isEmpty
                            ? 'No description provided.'
                            : product.description,
                        style: GoogleFonts.nunitoSans(
                          height: 1.5,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Icon(
                            Icons.storefront_outlined,
                            size: 18,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Sold by ${product.store?.name ?? 'Unknown store'}',
                              style: GoogleFonts.nunitoSans(
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _AddToCartBar(product: product),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.title,
    required this.detail,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String detail;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 44, color: Colors.grey),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunitoSans(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _Gallery extends StatefulWidget {
  const _Gallery({required this.images});

  final List<String> images;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return AspectRatio(
        aspectRatio: 1,
        child: Container(
          color: Colors.grey.shade100,
          child: const Center(
            child: Icon(Icons.image_not_supported_outlined, color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => Image.network(
              widget.images[i],
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : Container(color: Colors.grey.shade100),
              errorBuilder: (_, _, _) => Container(
                color: Colors.grey.shade100,
                child: const Center(
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.images.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < widget.images.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _index ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _index
                          ? ProductDetailScreen._accent
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.stock});

  final int stock;

  @override
  Widget build(BuildContext context) {
    final inStock = stock > 0;
    // Below this the count is worth showing as a nudge; above it the exact
    // number is noise.
    final isLow = inStock && stock <= 10;

    final label = !inStock
        ? 'Out of stock'
        : isLow
        ? 'Only $stock left'
        : 'In stock';
    final color = !inStock
        ? Colors.redAccent
        : isLow
        ? Colors.orange.shade800
        : Colors.green.shade700;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunitoSans(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _AddToCartBar extends ConsumerStatefulWidget {
  const _AddToCartBar({required this.product});

  final Product product;

  @override
  ConsumerState<_AddToCartBar> createState() => _AddToCartBarState();
}

class _AddToCartBarState extends ConsumerState<_AddToCartBar> {
  bool _isAdding = false;

  Future<void> _add() async {
    setState(() => _isAdding = true);
    try {
      await ref.read(cartProvider.notifier).add(widget.product.id);
      if (mounted) showSnackBar(context, 'Added to your cart');
    } on ApiException catch (e) {
      // The product vanished between the feed loading and this tap, so the
      // feed is stale too. Refresh it rather than leaving dead cards on screen.
      if (e.statusCode == 404) {
        ref.invalidate(productFeedProvider);
      }
      if (mounted) showSnackBar(context, e.message);
    } catch (_) {
      if (mounted) {
        showSnackBar(context, 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          height: 50,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ProductDetailScreen._accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: product.isInStock && !_isAdding ? _add : null,
            child: _isAdding
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Text(
                    product.isInStock ? 'Add to Cart' : 'Out of stock',
                    style: GoogleFonts.lato(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
