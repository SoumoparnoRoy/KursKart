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
    required this.status,
  });

  final String productId;
  final String name;
  final int price;
  final String image;
  final int quantity;
  final String storeName;

  /// Each line carries its own status, because an order can span several
  /// stores and each vendor only moves their own items.
  final String status;

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
      // Lines placed before per-line status existed have none.
      status: map['status'] as String? ?? 'placed',
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
    this.customerName = '',
  });

  final String id;
  final List<OrderItem> items;
  final int total;

  /// Rolled up by the server from the item statuses: the order is only as far
  /// along as its least advanced live line.
  final String status;
  final DateTime? placedAt;

  /// Who placed the order. Only sent on the vendor endpoint — a vendor needs a
  /// name to ship to, and the address does not carry one.
  final String customerName;

  /// A buyer may pull out only while nothing has shipped yet.
  bool get canCancel => status == 'placed';

  /// What this vendor is allowed to do next with their part of the order.
  /// Mirrors the transitions the server enforces.
  String? get nextVendorStatus => switch (status) {
    'placed' => 'shipped',
    'shipped' => 'delivered',
    _ => null,
  };

  /// Where this order was sent, as it read at purchase time. Orders placed
  /// before addresses existed have none.
  final String shippingAddress;

  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);

  String get formattedTotal => formatRupees(total);

  /// Empty on orders that predate `createdAt` being sent. Local time, since
  /// "when did I order this" is a question about the buyer's own day.
  String get formattedPlacedAt {
    final at = placedAt?.toLocal();
    if (at == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hh = at.hour.toString().padLeft(2, '0');
    final mm = at.minute.toString().padLeft(2, '0');
    return '${at.day} ${months[at.month - 1]} ${at.year}, $hh:$mm';
  }

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
      customerName: map['customerName'] as String? ?? '',
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
