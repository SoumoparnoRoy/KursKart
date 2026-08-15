import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kurskart/models/order.dart';
import 'package:kurskart/providers/order_provider.dart';
import 'package:kurskart/providers/review_provider.dart';
import 'package:kurskart/services/api_client.dart';
import 'package:kurskart/views/screens/review_form_screen.dart';
import 'package:kurskart/views/widgets/order_status_chip.dart';

class OrdersTab extends ConsumerWidget {
  const OrdersTab({super.key});

  static const _accent = Color.fromARGB(255, 0, 47, 255);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider);

    return orders.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _Message(
        title: 'Could not load your orders',
        detail: '$e',
        onRetry: () => ref.read(ordersProvider.notifier).refresh(),
      ),
      data: (list) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Your Orders',
                style: GoogleFonts.lato(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: ref.read(ordersProvider.notifier).refresh,
              // Centred against the space actually available rather than
              // nudged down by a fixed spacer, which sat too low on a short
              // screen and too high on a tall one. Still a ListView so
              // pull-to-refresh works with nothing to scroll.
              child: list.isEmpty
                  ? LayoutBuilder(
                      builder: (context, constraints) => ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: const Center(
                              child: _Message(
                                title: 'No orders yet',
                                detail:
                                    'Anything you check out will show up here.',
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => _OrderCard(order: list[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends ConsumerStatefulWidget {
  const _OrderCard({required this.order});

  final Order order;

  @override
  ConsumerState<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends ConsumerState<_OrderCard> {
  bool _busy = false;

  Order get order => widget.order;

  String get _placedLabel {
    final at = order.placedAt?.toLocal();
    if (at == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hh = at.hour.toString().padLeft(2, '0');
    final mm = at.minute.toString().padLeft(2, '0');
    return '${at.day} ${months[at.month - 1]} ${at.year}, $hh:$mm';
  }

  Future<void> _confirmCancel() async {
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
      // Covers the race where a vendor ships between the list loading and the
      // button being pressed — the server refuses and says why.
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                order.reference,
                style: GoogleFonts.nunitoSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(width: 8),
              OrderStatusChip(status: order.status),
              const Spacer(),
              Text(
                order.formattedTotal,
                style: GoogleFonts.lato(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: OrdersTab._accent,
                ),
              ),
            ],
          ),
          if (_placedLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                _placedLabel,
                style: GoogleFonts.nunitoSans(
                  fontSize: 12,
                  color: Colors.black45,
                ),
              ),
            ),
          const Divider(height: 18),
          for (final item in order.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 44,
                      height: 44,
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
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.nunitoSans(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                '${item.storeName} · qty ${item.quantity}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.nunitoSans(
                                  fontSize: 12,
                                  color: Colors.black45,
                                ),
                              ),
                            ),
                            // Only worth showing when this store is ahead of
                            // the rest of the order; otherwise the chip at the
                            // top already says it.
                            if (item.status != order.status) ...[
                              const SizedBox(width: 6),
                              OrderStatusChip(status: item.status),
                            ],
                          ],
                        ),
                        // Reviewing is only possible once a line is delivered,
                        // which is exactly what this row knows.
                        if (item.status == 'delivered')
                          _RateLine(
                            productId: item.productId,
                            productName: item.name,
                          ),
                      ],
                    ),
                  ),
                  Text(
                    item.formattedLineTotal,
                    style: GoogleFonts.nunitoSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          // Absent on orders placed before addresses existed.
          if (order.shippingAddress.isNotEmpty) ...[
            const Divider(height: 8),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 15,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      order.shippingAddress,
                      style: GoogleFonts.nunitoSans(
                        fontSize: 12,
                        color: Colors.black54,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (order.canCancel) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                ),
                onPressed: _busy ? null : _confirmCancel,
                child: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Cancel order'),
              ),
            ),
          ],
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
              Icons.receipt_long_outlined,
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
