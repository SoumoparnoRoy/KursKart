import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurskart/models/order.dart';
import 'package:kurskart/providers/auth_provider.dart';
import 'package:kurskart/providers/cart_provider.dart';
import 'package:kurskart/providers/product_provider.dart';
import 'package:kurskart/services/order_service.dart';

final orderServiceProvider = Provider<OrderService>(
  (ref) => const OrderService(),
);

final ordersProvider = AsyncNotifierProvider<OrdersNotifier, List<Order>>(
  OrdersNotifier.new,
);

/// One order, read fresh from the server. The list is only as current as the
/// last pull-to-refresh, so opening an order is where a buyer finds out a
/// vendor has shipped since.
final orderDetailProvider = FutureProvider.family<Order, String>((
  ref,
  id,
) async {
  final token = await ref.read(tokenStorageProvider).read();
  if (token == null) throw StateError('Cannot read an order while signed out');

  return ref.read(orderServiceProvider).fetchOrder(token, id);
});

class OrdersNotifier extends AsyncNotifier<List<Order>> {
  Future<String?> get _token => ref.read(tokenStorageProvider).read();

  OrderService get _service => ref.read(orderServiceProvider);

  @override
  Future<List<Order>> build() async {
    final user = ref.watch(authProvider).value;
    if (user == null) return const [];

    final token = await _token;
    if (token == null) return const [];

    return _service.fetchOrders(token);
  }

  /// Places the order, then refreshes the cart — the server empties it as part
  /// of checkout, so the local copy would otherwise still show the old items.
  ///
  /// Lets [ApiException] propagate so the screen can show "Only 2 left of X".
  Future<Order> placeOrder() async {
    final token = await _token;
    if (token == null) {
      throw StateError('Cannot place an order while signed out');
    }

    final order = await _service.placeOrder(token);

    await ref.read(cartProvider.notifier).refresh();
    state = AsyncValue.data([order, ...?state.value]);

    return order;
  }

  /// Cancels an order and swaps the returned copy into the list in place, so
  /// the card updates without a round trip for the whole list.
  ///
  /// Lets [ApiException] propagate so the screen can show the server's reason
  /// for refusing, such as the order having already shipped.
  Future<void> cancel(String id) async {
    final token = await _token;
    if (token == null) {
      throw StateError('Cannot cancel an order while signed out');
    }

    final updated = await _service.cancelOrder(token, id);

    state = AsyncValue.data([
      for (final o in state.value ?? const <Order>[])
        if (o.id == updated.id) updated else o,
    ]);

    // Cancelling puts the reserved stock back, so anything showing stock is
    // now out of date.
    ref.invalidate(productFeedProvider);
    ref.invalidate(orderDetailProvider(id));
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final token = await _token;
      if (token == null) return const <Order>[];
      return _service.fetchOrders(token);
    });
  }
}
