import 'package:kurskart/models/store.dart';

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
  final double rating;

  /// Null when the API returned an unpopulated store reference.
  final Store? store;

  bool get isInStock => stock > 0;

  String? get primaryImage => images.isEmpty ? null : images.first;

  /// e.g. 7499 -> "₹7,499". Grouping is done by hand to avoid pulling in intl
  /// for a single format.
  String get formattedPrice {
    final digits = price.abs().toString();
    final buffer = StringBuffer();

    // Indian grouping: last three digits, then pairs (7,499 / 1,23,456).
    if (digits.length <= 3) {
      buffer.write(digits);
    } else {
      final head = digits.substring(0, digits.length - 3);
      final tail = digits.substring(digits.length - 3);
      final grouped = <String>[];
      var rest = head;
      while (rest.length > 2) {
        grouped.insert(0, rest.substring(rest.length - 2));
        rest = rest.substring(0, rest.length - 2);
      }
      if (rest.isNotEmpty) grouped.insert(0, rest);
      buffer.write('${grouped.join(',')},$tail');
    }

    return '₹${buffer.toString()}';
  }

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
      // The API populates `store` on feed and detail reads, but a bare id is
      // still valid JSON for this field.
      store: rawStore is Map<String, dynamic>
          ? Store.fromMap(rawStore)
          : null,
    );
  }
}
