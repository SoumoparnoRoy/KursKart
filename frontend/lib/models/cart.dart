import 'package:kurskart/models/product.dart';
import 'package:kurskart/utils/currency.dart';

class CartItem {
  const CartItem({required this.product, required this.quantity});

  final Product product;
  final int quantity;

  int get lineTotal => product.price * quantity;

  String get formattedLineTotal => formatRupees(lineTotal);

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      product: Product.fromMap(map['product'] as Map<String, dynamic>),
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
    );
  }
}

class Cart {
  const Cart({
    required this.items,
    required this.itemCount,
    required this.subtotal,
  });

  static const empty = Cart(items: [], itemCount: 0, subtotal: 0);

  final List<CartItem> items;

  /// Total units, not lines — 3 mugs and 2 candles is 5.
  final int itemCount;

  final int subtotal;

  bool get isEmpty => items.isEmpty;

  String get formattedSubtotal => formatRupees(subtotal);

  factory Cart.fromMap(Map<String, dynamic> map) {
    final items = (map['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        // The server drops lines whose product no longer exists, but guard here
        // too rather than throwing on a malformed line.
        .where((e) => e['product'] is Map<String, dynamic>)
        .map(CartItem.fromMap)
        .toList();

    return Cart(
      items: items,
      itemCount:
          (map['itemCount'] as num?)?.toInt() ??
          items.fold(0, (sum, i) => sum + i.quantity),
      subtotal:
          (map['subtotal'] as num?)?.toInt() ??
          items.fold(0, (sum, i) => sum + i.lineTotal),
    );
  }
}
