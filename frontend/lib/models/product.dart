import 'package:kurskart/models/store.dart';
import 'package:kurskart/utils/currency.dart';

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.images,
    required this.stock,
    required this.rating,
    required this.ratingCount,
    required this.store,
  });

  final String id;
  final String name;
  final String description;

  /// Whole rupees. Stored as an integer so money never goes through a double.
  final int price;

  final String category;
  final List<String> images;
  final int stock;

  /// Both are derived by the server from the product's reviews. A product with
  /// no reviews has a rating of 0, which means "unrated" rather than "terrible"
  /// — check [ratingCount] before showing stars.
  final double rating;
  final int ratingCount;

  bool get hasRating => ratingCount > 0;

  /// Null when the API returned an unpopulated store reference.
  final Store? store;

  bool get isInStock => stock > 0;

  String? get primaryImage => images.isEmpty ? null : images.first;

  String get formattedPrice => formatRupees(price);

  factory Product.fromMap(Map<String, dynamic> map) {
    final rawStore = map['store'];

    return Product(
      id: map['_id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      price: (map['price'] as num?)?.toInt() ?? 0,
      category: map['category'] as String? ?? '',
      images:
          (map['images'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      stock: (map['stock'] as num?)?.toInt() ?? 0,
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      ratingCount: (map['ratingCount'] as num?)?.toInt() ?? 0,
      // The API populates `store` on feed and detail reads, but a bare id is
      // still valid JSON for this field.
      store: rawStore is Map<String, dynamic>
          ? Store.fromMap(rawStore)
          : null,
    );
  }
}
