import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kurskart/models/order.dart';
import 'package:kurskart/providers/order_provider.dart';
import 'package:kurskart/views/screens/order_detail_screen.dart';
import 'package:kurskart/views/widgets/empty_state.dart';
import 'package:kurskart/views/widgets/order_status_chip.dart';

class OrdersTab extends ConsumerWidget {
  const OrdersTab({super.key});

  static const _accent = Color.fromARGB(255, 0, 47, 255);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider);

    return orders.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.receipt_long_outlined,
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
                              child: EmptyState(
                                icon: Icons.receipt_long_outlined,
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

/// A summary only. The full breakdown, the address and every action live in
/// [OrderDetailScreen] — a list someone scrolls to find one order should stay
/// scannable, and the card grew past that once lines carried their own status.
class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final Order order;

  /// Enough to recognise the order at a glance without turning the card back
  /// into the item list.
  static const _thumbnailLimit = 3;

  @override
  Widget build(BuildContext context) {
    final extra = order.items.length - _thumbnailLimit;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              OrderDetailScreen(orderId: order.id, initial: order),
        ),
      ),
      child: Container(
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
            if (order.formattedPlacedAt.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  order.formattedPlacedAt,
                  style: GoogleFonts.nunitoSans(
                    fontSize: 12,
                    color: Colors.black45,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final item in order.items.take(_thumbnailLimit))
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _Thumbnail(url: item.image),
                  ),
                if (extra > 0)
                  Text(
                    '+$extra',
                    style: GoogleFonts.nunitoSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black45,
                    ),
                  ),
                const Spacer(),
                Text(
                  '${order.itemCount} '
                  '${order.itemCount == 1 ? 'item' : 'items'}',
                  style: GoogleFonts.nunitoSans(
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: Colors.black38,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 38,
        height: 38,
        child: url.isEmpty
            ? Container(color: Colors.grey.shade100)
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(color: Colors.grey.shade100),
              ),
      ),
    );
  }
}
