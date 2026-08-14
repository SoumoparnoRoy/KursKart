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
    required this.shippingAddress,
  });

  final String id;
  final List<OrderItem> items;
  final int total;
  final String status;
  final DateTime? placedAt;

  /// Where this order was sent, as it read at purchase time. Orders placed
  /// before addresses existed have none.
  final String shippingAddress;

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
      shippingAddress: _formatAddress(map['shippingAddress']),
    );
  }

  static String _formatAddress(Object? raw) {
    if (raw is! Map<String, dynamic>) return '';
    String at(String k) => (raw[k] as String? ?? '').trim();

    final cityLine = [
      at('city'),
      at('state'),
    ].where((s) => s.isNotEmpty).join(', ');

    return [
      at('addressLine'),
      at('locality'),
      [cityLine, at('pincode')].where((s) => s.isNotEmpty).join(' '),
    ].where((s) => s.isNotEmpty).join(', ');
  }
}
