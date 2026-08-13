import 'package:kurskart/utils/currency.dart';

/// A line as it was at purchase time. Name, price and image are copies taken
/// when the order was placed, not live product data — the product may since
/// have been renamed, repriced or deleted.
class OrderItem {
  const OrderItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.image,
    required this.quantity,
    required this.storeName,
  });

  final String productId;
  final String name;
  final int price;
  final String image;
  final int quantity;
  final String storeName;

  int get lineTotal => price * quantity;

  String get formattedLineTotal => formatRupees(lineTotal);

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      productId: map['product'] as String? ?? '',
      name: map['name'] as String? ?? '',
      price: (map['price'] as num?)?.toInt() ?? 0,
      image: map['image'] as String? ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      storeName: map['storeName'] as String? ?? '',
    );
  }
}

class Order {
  const Order({
    required this.id,
    required this.items,
    required this.total,
    required this.status,
    required this.placedAt,
  });

  final String id;
  final List<OrderItem> items;
  final int total;
  final String status;
  final DateTime? placedAt;

  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);

  String get formattedTotal => formatRupees(total);

  /// Short id for display, e.g. "#59C0CA" — the full ObjectId is noise.
  String get reference => id.isEmpty
      ? ''
      : '#${id.substring(id.length - 6).toUpperCase()}';

  factory Order.fromMap(Map<String, dynamic> map) {
    return Order(
      id: map['_id'] as String? ?? '',
      items: (map['items'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(OrderItem.fromMap)
          .toList(),
      total: (map['total'] as num?)?.toInt() ?? 0,
      status: map['status'] as String? ?? 'placed',
      placedAt: DateTime.tryParse(map['createdAt'] as String? ?? ''),
    );
  }
}
