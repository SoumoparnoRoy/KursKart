import 'package:kurskart/models/cart.dart';
import 'package:kurskart/services/api_client.dart';

/// Every mutation returns the whole cart, so the caller can replace its state
/// in one round trip instead of refetching.
class CartService {
  const CartService({ApiClient client = const ApiClient()}) : _client = client;

  final ApiClient _client;

  Future<Cart> fetch(String token) async {
    return Cart.fromMap(await _client.get('/api/cart', token: token));
  }

  Future<Cart> addItem(
    String token,
    String productId, {
    int quantity = 1,
  }) async {
    final body = await _client.post(
      '/api/cart/items',
      token: token,
      body: {'productId': productId, 'quantity': quantity},
    );
    return Cart.fromMap(body);
  }

  Future<Cart> setQuantity(
    String token,
    String productId,
    int quantity,
  ) async {
    final body = await _client.patch(
      '/api/cart/items/$productId',
      token: token,
      body: {'quantity': quantity},
    );
    return Cart.fromMap(body);
  }

  Future<Cart> removeItem(String token, String productId) async {
    final body = await _client.delete(
      '/api/cart/items/$productId',
      token: token,
    );
    return Cart.fromMap(body);
  }

  Future<Cart> clear(String token) async {
    return Cart.fromMap(await _client.delete('/api/cart', token: token));
  }
}
