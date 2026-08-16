import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kurskart/models/order.dart';
import 'package:kurskart/providers/order_provider.dart';
import 'package:kurskart/providers/review_provider.dart';
import 'package:kurskart/services/api_client.dart';
import 'package:kurskart/utils/currency.dart';
import 'package:kurskart/views/screens/review_form_screen.dart';
import 'package:kurskart/views/widgets/empty_state.dart';
import 'package:kurskart/views/widgets/order_status_chip.dart';

/// The full breakdown of one order: every line with its own status, where it
/// was sent, and the actions that only make sense on a whole order.
///
/// [initial] is the copy the list already had, used to paint the screen
/// immediately while the fresh read is in flight. The server's answer replaces
/// it, which is the point of opening this screen — the list is only as current
/// as its last refresh, so a vendor's shipment shows up here first.
class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId, this.initial});

  final String orderId;
  final Order? initial;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  static const _accent = Color.fromARGB(255, 0, 47, 255);

  bool _busy = false;

  Future<void> _confirmCancel(Order order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: Text(
          '${order.reference} will be cancelled and nothing will be shipped. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(ordersProvider.notifier).cancel(order.id);
      messenger.showSnackBar(
        SnackBar(content: Text('${order.reference} cancelled')),
      );
    } on ApiException catch (e) {
      // Covers the race where a vendor ships between this screen loading and
      // the button being pressed — the server refuses and says why.
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not cancel that order')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(orderDetailProvider(widget.orderId));
    // Keep showing what we have while a refresh is in flight, so cancelling —
    // which invalidates this provider — does not blank the screen.
    final order = async.value ?? widget.initial;
    final reference = order?.reference ?? '';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          reference.isEmpty ? 'Order' : reference,
          style: GoogleFonts.lato(fontWeight: FontWeight.bold),
        ),
      ),
      body: _content(order, async),
    );
  }

  Widget _content(Order? order, AsyncValue<Order> async) {
    if (order != null) {
      return RefreshIndicator(
        onRefresh: () async =>
            ref.invalidate(orderDetailProvider(widget.orderId)),
        child: _body(order),
      );
    }

    if (async.hasError) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Could not load this order',
        detail: '${async.error}',
        onRetry: () => ref.invalidate(orderDetailProvider(widget.orderId)),
      );
    }

    return const Center(child: CircularProgressIndicator());
  }

  Widget _body(Order order) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        _Card(
          child: Row(
            children: [
              OrderStatusChip(status: order.status),
              const Spacer(),
              if (order.formattedPlacedAt.isNotEmpty)
                Text(
                  'Placed ${order.formattedPlacedAt}',
                  style: GoogleFonts.nunitoSans(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Counted in units, not lines, to match the card in the list —
              // three of one product reads as "3 items" in both places.
              _SectionTitle(
                '${order.itemCount} '
                '${order.itemCount == 1 ? 'item' : 'items'}',
              ),
              for (final item in order.items)
                _ItemRow(item: item, orderStatus: order.status),
            ],
          ),
        ),
        // Absent on orders placed before addresses existed.
        if (order.shippingAddress.isNotEmpty) ...[
          const SizedBox(height: 10),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle('Delivering to'),
                Text(
                  order.shippingAddress,
                  style: GoogleFonts.nunitoSans(
                    fontSize: 13,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        _Card(
          child: Row(
            children: [
              Text(
                'Total',
                style: GoogleFonts.nunitoSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                order.formattedTotal,
                style: GoogleFonts.lato(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _accent,
                ),
              ),
            ],
          ),
        ),
        if (order.canCancel) ...[
          const SizedBox(height: 16),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Colors.redAccent),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _busy ? null : () => _confirmCancel(order),
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Cancel order'),
          ),
        ],
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.orderStatus});

  final OrderItem item;
  final String orderStatus;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 56,
              height: 56,
              child: item.image.isEmpty
                  ? Container(color: Colors.grey.shade100)
                  : Image.network(
                      item.image,
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
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunitoSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  item.storeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunitoSans(
                    fontSize: 12,
                    color: Colors.black45,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatRupees(item.price)} × ${item.quantity}',
                  style: GoogleFonts.nunitoSans(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
                // Only worth showing when this store is ahead of the rest of
                // the order; otherwise the chip at the top already says it.
                if (item.status != orderStatus)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: OrderStatusChip(status: item.status),
                  ),
                // Reviewing is only possible once a line is delivered, which is
                // exactly what this row knows.
                if (item.status == 'delivered')
                  _RateLine(productId: item.productId, productName: item.name),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            item.formattedLineTotal,
            style: GoogleFonts.nunitoSans(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// The review shortcut under a delivered line. It asks the server whether this
/// user has already reviewed the product, so the button says "Rate" or "Edit"
/// correctly rather than sending them into a form that would be rejected.
class _RateLine extends ConsumerWidget {
  const _RateLine({required this.productId, required this.productName});

  final String productId;
  final String productName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eligibility = ref.watch(reviewEligibilityProvider(productId)).value;

    // Still loading, or the product has since been deleted — either way there
    // is nothing useful to offer yet.
    if (eligibility == null || !eligibility.canReview) {
      return const SizedBox.shrink();
    }

    final existing = eligibility.mine;

    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        icon: Icon(
          existing == null ? Icons.star_border : Icons.star,
          size: 16,
          color: Colors.amber.shade700,
        ),
        label: Text(
          existing == null ? 'Rate this' : 'Edit your review',
          style: GoogleFonts.nunitoSans(fontSize: 12),
        ),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReviewFormScreen(
              productId: productId,
              productName: productName,
              existing: existing,
            ),
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.nunitoSans(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Colors.black54,
      ),
    );
  }
}
