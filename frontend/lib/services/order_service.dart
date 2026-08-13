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
}
