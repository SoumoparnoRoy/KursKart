import 'package:kurskart/models/order.dart';
import 'package:kurskart/models/product.dart';
import 'package:kurskart/models/store.dart';
import 'package:kurskart/services/api_client.dart';

/// Everything a vendor does to their own store. The server scopes every call to
/// the caller's store, so no id has to be passed for ownership.
class VendorService {
  const VendorService({ApiClient client = const ApiClient()}) : _client = client;

  final ApiClient _client;

  /// Returns null when the user has no store yet, rather than treating the
  /// server's 404 as an error — not having a store is a normal state.
  Future<Store?> fetchMyStore(String token) async {
    try {
      return Store.fromMap(await _client.get('/api/stores/mine', token: token));
    } on ApiException catch (e) {
      if (e.statusCode == 404 || e.statusCode == 403) return null;
      rethrow;
    }
  }

  Future<Store> createStore(
    String token, {
    required String name,
    required String description,
    required String logoUrl,
  }) async {
    final body = await _client.post(
      '/api/stores',
      token: token,
      body: {'name': name, 'description': description, 'logoUrl': logoUrl},
    );
    return Store.fromMap(body);
  }

  Future<Store> updateStore(
    String token, {
    required String name,
    required String description,
    required String logoUrl,
  }) async {
    final body = await _client.patch(
      '/api/stores/mine',
      token: token,
      body: {'name': name, 'description': description, 'logoUrl': logoUrl},
    );
    return Store.fromMap(body);
  }

  Future<List<Product>> fetchMyProducts(String token) async {
    try {
      final body = await _client.get('/api/products/mine', token: token);
      return (body['products'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Product.fromMap)
          .toList();
    } on ApiException catch (e) {
      // Not a vendor yet, so there is nothing to list.
      if (e.statusCode == 403 || e.statusCode == 404) return const [];
      rethrow;
    }
  }

  Future<Product> createProduct(
    String token, {
    required String name,
    required String description,
    required int price,
    required String category,
    required int stock,
    required List<String> images,
  }) async {
    final body = await _client.post(
      '/api/products',
      token: token,
      body: {
        'name': name,
        'description': description,
        'price': price,
        'category': category,
        'stock': stock,
        'images': images,
      },
    );
    return Product.fromMap(body);
  }

  Future<Product> updateProduct(
    String token,
    String id, {
    required String name,
    required String description,
    required int price,
    required String category,
    required int stock,
    required List<String> images,
  }) async {
    final body = await _client.patch(
      '/api/products/$id',
      token: token,
      body: {
        'name': name,
        'description': description,
        'price': price,
        'category': category,
        'stock': stock,
        'images': images,
      },
    );
    return Product.fromMap(body);
  }

  Future<void> deleteProduct(String token, String id) async {
    await _client.delete('/api/products/$id', token: token);
  }

  /// Orders containing at least one of this store's products. The server trims
  /// each one to the caller's own lines, so totals here are their share only.
  Future<List<Order>> fetchVendorOrders(String token) async {
    try {
      final body = await _client.get('/api/orders/vendor', token: token);
      return (body['orders'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Order.fromMap)
          .toList();
    } on ApiException catch (e) {
      // Not a vendor yet, so there is nothing to list.
      if (e.statusCode == 403 || e.statusCode == 404) return const [];
      rethrow;
    }
  }

  Future<Order> updateOrderStatus(
    String token,
    String id, {
    required String status,
  }) async {
    final body = await _client.patch(
      '/api/orders/$id/status',
      token: token,
      body: {'status': status},
    );
    return Order.fromMap(body);
  }
}
