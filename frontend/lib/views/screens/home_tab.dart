import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kurskart/models/product.dart';
import 'package:kurskart/providers/product_provider.dart';
import 'package:kurskart/views/screens/product_detail_screen.dart';

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  static const _accent = Color.fromARGB(255, 0, 47, 255);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(productFeedProvider);
    final query = ref.watch(searchQueryProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(productFeedProvider.notifier).refresh(),
      child: CustomScrollView(
        // Always scrollable so pull-to-refresh works even when the list is
        // empty or errored.
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _Header()),
          const SliverToBoxAdapter(child: _SearchField()),
          const SliverToBoxAdapter(child: _CategoryStrip()),
          feed.when(
            loading: () => const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: _Message(
                title: 'Could not load products',
                detail: '$e',
                onRetry: () => ref.read(productFeedProvider.notifier).refresh(),
              ),
            ),
            data: (products) => products.isEmpty
                ? SliverFillRemaining(
                    hasScrollBody: false,
                    child: _Message(
                      title: query.isEmpty
                          ? 'Nothing here yet'
                          : 'No matches for "$query"',
                      detail: query.isEmpty
                          ? 'No products in this category.'
                          : 'Try a different word, or clear the search.',
                    ),
                  )
                : _ProductGrid(products: products),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Explore',
            style: GoogleFonts.lato(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
          Text(
            'Exclusives from every store',
            style: GoogleFonts.nunitoSans(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends ConsumerStatefulWidget {
  const _SearchField();

  @override
  ConsumerState<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<_SearchField> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Restore the term if the tab is rebuilt, so the field and the feed agree.
    _controller.text = ref.read(searchQueryProvider);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Waits for a pause in typing so a five-letter word is one request, not five.
  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final trimmed = value.trim();
      if (ref.read(searchQueryProvider) != trimmed) {
        ref.read(searchQueryProvider.notifier).state = trimmed;
      }
    });
    setState(() {});
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    ref.read(searchQueryProvider.notifier).state = '';
    FocusScope.of(context).unfocus();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: TextField(
        controller: _controller,
        onChanged: _onChanged,
        textInputAction: TextInputAction.search,
        onSubmitted: (v) {
          _debounce?.cancel();
          ref.read(searchQueryProvider.notifier).state = v.trim();
        },
        decoration: InputDecoration(
          hintText: 'Search products',
          hintStyle: GoogleFonts.nunitoSans(color: Colors.black38),
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: _clear,
                  tooltip: 'Clear search',
                ),
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: HomeTab._accent),
          ),
        ),
      ),
    );
  }
}

class _CategoryStrip extends ConsumerWidget {
  const _CategoryStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final selected = ref.watch(selectedCategoryProvider);

    return categories.when(
      loading: () => const SizedBox(height: 56),
      error: (_, _) => const SizedBox(height: 0),
      data: (list) => SizedBox(
        height: 56,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            _CategoryChip(
              label: 'All',
              isSelected: selected == null,
              onTap: () =>
                  ref.read(selectedCategoryProvider.notifier).state = null,
            ),
            for (final category in list)
              _CategoryChip(
                label: category,
                isSelected: selected == category,
                onTap: () => ref
                    .read(selectedCategoryProvider.notifier)
                    .state = category,
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        // Weight stays constant across states: making the selected label bolder
        // widened the text past the width the chip had measured, clipping the
        // last letter, and made the whole strip jitter on every tap. Only the
        // colour changes now.
        labelStyle: GoogleFonts.nunitoSans(
          fontWeight: FontWeight.w600,
          color: isSelected ? Colors.white : Colors.black87,
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: 6),
        selectedColor: HomeTab._accent,
        backgroundColor: Colors.grey.shade200,
        showCheckmark: false,
      ),
    );
  }
}

class _ProductGrid extends StatelessWidget {
  const _ProductGrid({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      sliver: SliverGrid(
        // Sized by width rather than a fixed column count so phones get two
        // columns and tablets get four without a breakpoint table.
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 260,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.68,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _ProductCard(product: products[index]),
          childCount: products.length,
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final image = product.primaryImage;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(
            productId: product.id,
            initialProduct: product,
          ),
        ),
      ),
      child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SizedBox(
              width: double.infinity,
              child: image == null
                  ? _ImageFallback()
                  : Image.network(
                      image,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                          ? child
                          : Container(color: Colors.grey.shade100),
                      errorBuilder: (_, _, _) => _ImageFallback(),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunitoSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  product.store?.name ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunitoSans(
                    fontSize: 12,
                    color: Colors.black45,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      product.formattedPrice,
                      style: GoogleFonts.lato(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: HomeTab._accent,
                      ),
                    ),
                    const Spacer(),
                    if (!product.isInStock)
                      Text(
                        'Out of stock',
                        style: GoogleFonts.nunitoSans(
                          fontSize: 11,
                          color: Colors.redAccent,
                        ),
                      )
                    else if (product.rating > 0) ...[
                      const Icon(Icons.star, size: 13, color: Colors.amber),
                      const SizedBox(width: 2),
                      Text(
                        product.rating.toStringAsFixed(1),
                        style: GoogleFonts.nunitoSans(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade100,
      child: const Center(
        child: Icon(Icons.image_not_supported_outlined, color: Colors.grey),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.title, required this.detail, this.onRetry});

  final String title;
  final String detail;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ],
      ),
    );
  }
}
