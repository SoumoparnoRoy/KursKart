import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kurskart/models/product.dart';
import 'package:kurskart/models/store.dart';
import 'package:kurskart/providers/vendor_provider.dart';
import 'package:kurskart/services/api_client.dart';
import 'package:kurskart/views/screens/vendor/product_form_screen.dart';
import 'package:kurskart/views/screens/vendor/store_form_screen.dart';
import 'package:kurskart/views/screens/vendor/vendor_orders_tab.dart';

class VendorDashboardScreen extends ConsumerStatefulWidget {
  const VendorDashboardScreen({super.key});

  static const accent = Color.fromARGB(255, 0, 47, 255);

  @override
  ConsumerState<VendorDashboardScreen> createState() =>
      _VendorDashboardScreenState();
}

class _VendorDashboardScreenState extends ConsumerState<VendorDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(myStoreProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Your Store',
          style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: VendorDashboardScreen.accent,
          indicatorColor: VendorDashboardScreen.accent,
          unselectedLabelColor: Colors.black54,
          labelStyle: GoogleFonts.nunitoSans(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Products'),
            Tab(text: 'Orders'),
          ],
        ),
      ),
      // Adding a product from the Orders tab would make no sense, so the
      // button follows the tab rather than the screen.
      floatingActionButton: AnimatedBuilder(
        animation: _tabs.animation ?? _tabs,
        builder: (context, _) {
          if (store.value == null || _tabs.index != 0) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton.extended(
            backgroundColor: VendorDashboardScreen.accent,
            foregroundColor: Colors.white,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProductFormScreen()),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Add product'),
          );
        },
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: store.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _Retry(
                message: '$e',
                onRetry: () => ref.invalidate(myStoreProvider),
              ),
              data: (s) => s == null
                  ? const Center(child: Text('No store'))
                  : TabBarView(
                      controller: _tabs,
                      children: [
                        _ProductsTab(store: s),
                        const VendorOrdersTab(),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductsTab extends ConsumerWidget {
  const _ProductsTab({required this.store});

  final Store store;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(myProductsProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(myProductsProvider.notifier).refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
        children: [
          _StoreHeader(store: store),
          const SizedBox(height: 20),
          Text(
            'Products',
            style: GoogleFonts.lato(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          products.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => _Retry(
              message: '$e',
              onRetry: () => ref.read(myProductsProvider.notifier).refresh(),
            ),
            data: (list) => list.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      'No products yet. Add your first one.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunitoSans(color: Colors.black54),
                    ),
                  )
                : Column(
                    children: [
                      for (final p in list) _VendorProductRow(product: p),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _StoreHeader extends StatelessWidget {
  const _StoreHeader({required this.store});

  final Store store;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 56,
              height: 56,
              child: store.logoUrl.isEmpty
                  ? Container(
                      color: Colors.grey.shade100,
                      child: const Icon(
                        Icons.storefront_outlined,
                        color: Colors.grey,
                      ),
                    )
                  : Image.network(
                      store.logoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: Colors.grey.shade100,
                        child: const Icon(
                          Icons.storefront_outlined,
                          color: Colors.grey,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  store.name,
                  style: GoogleFonts.lato(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (store.description.isNotEmpty)
                  Text(
                    store.description,
                    style: GoogleFonts.nunitoSans(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StoreFormScreen(existing: store),
              ),
            ),
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }
}

class _VendorProductRow extends ConsumerWidget {
  const _VendorProductRow({required this.product});

  final Product product;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text(
          '"${product.name}" will be removed from your store and from the '
          'shop. Past orders keep their record of it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(myProductsProvider.notifier).remove(product.id);
      messenger.showSnackBar(
        SnackBar(content: Text('${product.name} deleted')),
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not delete that product')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = product.primaryImage;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 56,
              height: 56,
              child: image == null
                  ? Container(color: Colors.grey.shade100)
                  : Image.network(
                      image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          Container(color: Colors.grey.shade100),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunitoSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                Text(
                  '${product.formattedPrice} · ${product.category}',
                  style: GoogleFonts.nunitoSans(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
                Text(
                  product.isInStock
                      ? '${product.stock} in stock'
                      : 'Out of stock',
                  style: GoogleFonts.nunitoSans(
                    fontSize: 12,
                    color: product.isInStock
                        ? Colors.green.shade700
                        : Colors.redAccent,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductFormScreen(existing: product),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline, size: 20),
            color: Colors.redAccent,
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
    );
  }
}

class _Retry extends StatelessWidget {
  const _Retry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
