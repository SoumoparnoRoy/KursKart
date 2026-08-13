import 'package:kurskart/models/product.dart';
import 'package:kurskart/services/api_client.dart';

/// One page of the product feed.
class ProductPage {
  const ProductPage({
    required this.products,
    required this.page,
    required this.totalPages,
    required this.total,
  });

  final List<Product> products;
  final int page;
  final int totalPages;
  final int total;

  bool get hasMore => page < totalPages;
}

class ProductService {
  const ProductService({ApiClient client = const ApiClient()}) : _client = client;

  final ApiClient _client;

  Future<ProductPage> fetchProducts({
    int page = 1,
    int limit = 20,
    String? category,
    String? search,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'limit': '$limit',
      if (category != null && category.isNotEmpty) 'category': category,
      if (search != null && search.isNotEmpty) 'search': search,
    };

    final qs = query.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');

    final body = await _client.get('/api/products?$qs');

    final list = (body['products'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Product.fromMap)
        .toList();

    return ProductPage(
      products: list,
      page: (body['page'] as num?)?.toInt() ?? page,
      totalPages: (body['totalPages'] as num?)?.toInt() ?? 1,
      total: (body['total'] as num?)?.toInt() ?? list.length,
    );
  }

  Future<List<String>> fetchCategories() async {
    final body = await _client.get('/api/products/categories');
    return (body['categories'] as List? ?? const [])
        .map((e) => e.toString())
        .toList();
  }

  Future<Product> fetchProduct(String id) async {
    final body = await _client.get('/api/products/$id');
    return Product.fromMap(body);
  }
}
