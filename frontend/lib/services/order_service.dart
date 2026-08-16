import 'package:kurskart/models/order.dart';
import 'package:kurskart/services/api_client.dart';

class OrderService {
  const OrderService({ApiClient client = const ApiClient()}) : _client = client;

  final ApiClient _client;

  /// Converts the signed-in user's cart into an order. The server reserves
  /// stock and empties the cart, so callers should refresh both afterwards.
  Future<Order> placeOrder(String token) async {
    return Order.fromMap(await _client.post('/api/orders', token: token));
  }

  Future<List<Order>> fetchOrders(String token) async {
    final body = await _client.get('/api/orders', token: token);
    return (body['orders'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Order.fromMap)
        .toList();
  }

  /// One order the caller owns. The server scopes the lookup to the token, so
  /// another user's id comes back as a 404 rather than their order.
  Future<Order> fetchOrder(String token, String id) async {
    return Order.fromMap(await _client.get('/api/orders/$id', token: token));
  }

  /// Cancels the whole order and returns it in its new state. The server puts
  /// the stock back, and refuses once anything has shipped.
  Future<Order> cancelOrder(String token, String id) async {
    return Order.fromMap(
      await _client.patch('/api/orders/$id/cancel', token: token),
    );
  }
}
