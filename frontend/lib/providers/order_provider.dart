import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurskart/models/order.dart';
import 'package:kurskart/providers/auth_provider.dart';
import 'package:kurskart/providers/cart_provider.dart';
import 'package:kurskart/services/order_service.dart';

final orderServiceProvider = Provider<OrderService>(
  (ref) => const OrderService(),
);

final ordersProvider = AsyncNotifierProvider<OrdersNotifier, List<Order>>(
  OrdersNotifier.new,
);

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

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final token = await _token;
      if (token == null) return const <Order>[];
      return _service.fetchOrders(token);
    });
  }
}
