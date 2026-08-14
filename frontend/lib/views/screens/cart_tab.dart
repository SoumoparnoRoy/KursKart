import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kurskart/models/cart.dart';
import 'package:kurskart/providers/auth_provider.dart';
import 'package:kurskart/providers/cart_provider.dart';
import 'package:kurskart/providers/navigation_provider.dart';
import 'package:kurskart/providers/order_provider.dart';
import 'package:kurskart/views/screens/address_screen.dart';
import 'package:kurskart/services/api_client.dart';
import 'package:kurskart/services/manage_http_response.dart';

class CartTab extends ConsumerWidget {
  const CartTab({super.key});

  static const _accent = Color.fromARGB(255, 0, 47, 255);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);

    return cart.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _Message(
        title: 'Could not load your cart',
        detail: '$e',
        onRetry: () => ref.read(cartProvider.notifier).refresh(),
      ),
      data: (data) => data.isEmpty
          ? const _Message(
              title: 'Your cart is empty',
              detail: 'Browse the Home tab and add something you like.',
            )
          : _CartList(cart: data),
    );
  }
}

class _CartList extends ConsumerWidget {
  const _CartList({required this.cart});

  final Cart cart;

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } on ApiException catch (e) {
      if (context.mounted) showSnackBar(context, e.message);
    } catch (_) {
      if (context.mounted) {
        showSnackBar(context, 'Something went wrong. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(cartProvider.notifier);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            children: [
              Text(
                'Your Cart',
                style: GoogleFonts.lato(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _run(context, notifier.clear),
                child: const Text('Clear'),
              ),
            ],
          ),
        ),
        const _DeliverToStrip(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: notifier.refresh,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: cart.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final item = cart.items[i];
                return _CartRow(
                  item: item,
                  onDecrease: item.quantity > 1
                      ? () => _run(
                          context,
                          () => notifier.setQuantity(
                            item.product.id,
                            item.quantity - 1,
                          ),
                        )
                      : null,
                  onIncrease: () => _run(
                    context,
                    () => notifier.setQuantity(
                      item.product.id,
                      item.quantity + 1,
                    ),
                  ),
                  onRemove: () =>
                      _run(context, () => notifier.remove(item.product.id)),
                );
              },
            ),
          ),
        ),
        _SummaryBar(cart: cart),
      ],
    );
  }
}

/// One-line summary of where the order will go, with a way to change it.
class _DeliverToStrip extends ConsumerWidget {
  const _DeliverToStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    final hasAddress = user?.hasAddress ?? false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
      child: Row(
        children: [
          Icon(
            Icons.location_on_outlined,
            size: 16,
            color: hasAddress ? Colors.black54 : Colors.orange.shade800,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              hasAddress
                  ? 'Deliver to ${user!.city}, ${user.pincode}'
                  : 'No delivery address yet',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunitoSans(
                fontSize: 13,
                color: hasAddress ? Colors.black54 : Colors.orange.shade900,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddressScreen()),
            ),
            child: Text(hasAddress ? 'Change' : 'Add'),
          ),
        ],
      ),
    );
  }
}

class _CartRow extends StatelessWidget {
  const _CartRow({
    required this.item,
    required this.onDecrease,
    required this.onIncrease,
    required this.onRemove,
  });

  final CartItem item;
  final VoidCallback? onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final image = item.product.primaryImage;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 72,
              height: 72,
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
                  item.product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunitoSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                Text(
                  item.product.store?.name ?? '',
                  style: GoogleFonts.nunitoSans(
                    fontSize: 12,
                    color: Colors.black45,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _QtyButton(icon: Icons.remove, onTap: onDecrease),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '${item.quantity}',
                        style: GoogleFonts.nunitoSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    _QtyButton(icon: Icons.add, onTap: onIncrease),
                    const Spacer(),
                    Text(
                      item.formattedLineTotal,
                      style: GoogleFonts.lato(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: CartTab._accent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 18),
            color: Colors.black38,
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          border: Border.all(
            color: enabled ? Colors.grey.shade400 : Colors.grey.shade200,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 16,
          color: enabled ? Colors.black87 : Colors.black26,
        ),
      ),
    );
  }
}

class _SummaryBar extends ConsumerStatefulWidget {
  const _SummaryBar({required this.cart});

  final Cart cart;

  @override
  ConsumerState<_SummaryBar> createState() => _SummaryBarState();
}

class _SummaryBarState extends ConsumerState<_SummaryBar> {
  bool _isPlacing = false;

  Future<void> _checkout() async {
    // Captured before the await on purpose. A successful checkout empties the
    // cart, which swaps this whole subtree for the empty-state widget — so by
    // the time the request returns, this widget is already unmounted and
    // neither `context` nor a `mounted` check would survive. Both of these
    // outlive the widget.
    final messenger = ScaffoldMessenger.of(context);
    final tab = ref.read(selectedTabProvider.notifier);
    final navigator = Navigator.of(context);

    // The server refuses an order without an address, but sending the user
    // straight to the form is friendlier than showing them that error.
    final user = ref.read(authProvider).value;
    if (user != null && !user.hasAddress) {
      final saved = await navigator.push<bool>(
        MaterialPageRoute(
          builder: (_) => const AddressScreen(
            reason: 'Add a delivery address to place your order.',
          ),
        ),
      );
      // They backed out without saving — leave the cart untouched.
      if (saved != true) return;
    }

    if (!mounted) return;
    setState(() => _isPlacing = true);
    try {
      final order = await ref.read(ordersProvider.notifier).placeOrder();
      messenger.showSnackBar(
        SnackBar(content: Text('Order ${order.reference} placed')),
      );
      // The cart is now empty, so send them where the result actually is.
      tab.state = Tabs.orders;
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Something went wrong. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _isPlacing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = widget.cart;

    return Material(
      elevation: 8,
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Subtotal (${cart.itemCount} item${cart.itemCount == 1 ? '' : 's'})',
                    style: GoogleFonts.nunitoSans(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                  Text(
                    cart.formattedSubtotal,
                    style: GoogleFonts.lato(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: CartTab._accent,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: CartTab._accent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _isPlacing ? null : _checkout,
                child: _isPlacing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Text(
                        'Checkout',
                        style: GoogleFonts.lato(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 44,
              color: Colors.grey.shade400,
            ),
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
