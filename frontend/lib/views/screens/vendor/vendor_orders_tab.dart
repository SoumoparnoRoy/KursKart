import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kurskart/models/order.dart';
import 'package:kurskart/providers/vendor_provider.dart';
import 'package:kurskart/services/api_client.dart';
import 'package:kurskart/views/widgets/order_status_chip.dart';

/// Incoming orders for the vendor's own store. Every order here has been
/// trimmed by the server to this store's lines, so the totals and the status
/// are the vendor's share of a possibly larger order.
class VendorOrdersTab extends ConsumerWidget {
  const VendorOrdersTab({super.key});

  static const _accent = Color.fromARGB(255, 0, 47, 255);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(vendorOrdersProvider);

    return RefreshIndicator(
      onRefresh: ref.read(vendorOrdersProvider.notifier).refresh,
      child: orders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Scrollable(
          child: _Empty(
            title: 'Could not load your orders',
            detail: '$e',
            onRetry: () => ref.read(vendorOrdersProvider.notifier).refresh(),
          ),
        ),
        data: (list) => list.isEmpty
            ? const _Scrollable(
                child: _Empty(
                  title: 'No orders yet',
                  detail: 'Orders containing your products will show up here.',
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _VendorOrderCard(order: list[i]),
              ),
      ),
    );
  }
}

/// Keeps pull-to-refresh working when there is nothing tall enough to scroll.
class _Scrollable extends StatelessWidget {
  const _Scrollable({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: child),
          ),
        ],
      ),
    );
  }
}

class _VendorOrderCard extends ConsumerStatefulWidget {
  const _VendorOrderCard({required this.order});

  final Order order;

  @override
  ConsumerState<_VendorOrderCard> createState() => _VendorOrderCardState();
}

class _VendorOrderCardState extends ConsumerState<_VendorOrderCard> {
  bool _busy = false;

  Order get _order => widget.order;

  String get _placedLabel {
    final at = _order.placedAt?.toLocal();
    if (at == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hh = at.hour.toString().padLeft(2, '0');
    final mm = at.minute.toString().padLeft(2, '0');
    return '${at.day} ${months[at.month - 1]} ${at.year}, $hh:$mm';
  }

  Future<void> _setStatus(String status) async {
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _busy = true);
    try {
      await ref.read(vendorOrdersProvider.notifier).setStatus(
        _order.id,
        status,
      );
      messenger.showSnackBar(
        SnackBar(content: Text('${_order.reference} marked $status')),
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not update that order')),
      );
    } finally {
      // The card survives the update — only its contents are swapped — so the
      // spinner has to be cleared even after a failure.
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: Text(
          'Your part of ${_order.reference} will be cancelled and the stock '
          'put back. This cannot be undone.',
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

    if (confirmed == true) await _setStatus('cancelled');
  }

  @override
  Widget build(BuildContext context) {
    final next = _order.nextVendorStatus;

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
                _order.reference,
                style: GoogleFonts.nunitoSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(width: 8),
              OrderStatusChip(status: _order.status),
              const Spacer(),
              Text(
                _order.formattedTotal,
                style: GoogleFonts.lato(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: VendorOrdersTab._accent,
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
          for (final item in _order.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunitoSans(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '× ${item.quantity}',
                    style: GoogleFonts.nunitoSans(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(width: 12),
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
          const Divider(height: 14),
          _ShipTo(name: _order.customerName, address: _order.shippingAddress),
          if (next != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: VendorOrdersTab._accent,
                    ),
                    onPressed: _busy ? null : () => _setStatus(next),
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text('Mark $next'),
                  ),
                ),
                // Cancelling is only offered while nothing has shipped, which
                // is exactly when the server still allows it.
                if (_order.status == 'placed') ...[
                  const SizedBox(width: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                    ),
                    onPressed: _busy ? null : _confirmCancel,
                    child: const Text('Cancel'),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ShipTo extends StatelessWidget {
  const _ShipTo({required this.name, required this.address});

  final String name;
  final String address;

  @override
  Widget build(BuildContext context) {
    // Orders placed before addresses existed have neither line to show.
    if (name.isEmpty && address.isEmpty) return const SizedBox.shrink();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.local_shipping_outlined, size: 15, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (name.isNotEmpty)
                Text(
                  name,
                  style: GoogleFonts.nunitoSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (address.isNotEmpty)
                Text(
                  address,
                  style: GoogleFonts.nunitoSans(
                    fontSize: 12,
                    color: Colors.black54,
                    height: 1.3,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.title, required this.detail, this.onRetry});

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
          Icon(Icons.inbox_outlined, size: 44, color: Colors.grey.shade400),
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
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ],
      ),
    );
  }
}
