import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurskart/models/cart.dart';
import 'package:kurskart/providers/auth_provider.dart';
import 'package:kurskart/services/cart_service.dart';

final cartServiceProvider = Provider<CartService>((ref) => const CartService());

/// The signed-in user's cart, held on the server.
///
/// Watches [authProvider] so signing out empties the local copy immediately —
/// the next user on this device must never see the previous one's items.
final cartProvider = AsyncNotifierProvider<CartNotifier, Cart>(
  CartNotifier.new,
);

class CartNotifier extends AsyncNotifier<Cart> {
  Future<String?> get _token => ref.read(tokenStorageProvider).read();

  CartService get _service => ref.read(cartServiceProvider);

  @override
  Future<Cart> build() async {
    final user = ref.watch(authProvider).value;
    if (user == null) return Cart.empty;

    final token = await _token;
    if (token == null) return Cart.empty;

    return _service.fetch(token);
  }

  /// Mutations let [ApiException] propagate so the screen can surface the
  /// server's message ("Only 3 left in stock"), and leave state untouched on
  /// failure rather than guessing.
  Future<void> _mutate(Future<Cart> Function(String token) action) async {
    final token = await _token;
    if (token == null) return;
    state = AsyncValue.data(await action(token));
  }

  Future<void> add(String productId, {int quantity = 1}) {
    return _mutate((t) => _service.addItem(t, productId, quantity: quantity));
  }

  Future<void> setQuantity(String productId, int quantity) {
    return _mutate((t) => _service.setQuantity(t, productId, quantity));
  }

  Future<void> remove(String productId) {
    return _mutate((t) => _service.removeItem(t, productId));
  }

  Future<void> clear() {
    return _mutate((t) => _service.clear(t));
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final token = await _token;
      if (token == null) return Cart.empty;
      return _service.fetch(token);
    });
  }
}
