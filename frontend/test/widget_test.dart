import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kurskart/models/cart.dart';
import 'package:kurskart/models/order.dart';
import 'package:kurskart/models/product.dart';
import 'package:kurskart/models/review.dart';
import 'package:kurskart/models/user.dart';
import 'package:kurskart/providers/auth_provider.dart';
import 'package:kurskart/providers/product_provider.dart';
import 'package:kurskart/services/auth_service.dart';
import 'package:kurskart/services/product_service.dart';
import 'package:kurskart/views/screens/authetication_screens/login_screen.dart';
import 'package:kurskart/views/screens/authetication_screens/register_screen.dart';
import 'package:kurskart/views/screens/main_screen.dart';
import 'package:kurskart/views/widgets/auth_gate.dart';

User _user() => User(
  id: '1',
  fullName: 'Ada Lovelace',
  email: 'ada@example.com',
  state: '',
  city: '',
  locality: '',
  password: '',
);

/// Secure storage cannot run in a widget test, so the gate is driven through a
/// stubbed notifier instead.
class _StubAuth extends AuthNotifier {
  _StubAuth(this._initial);

  final User? _initial;

  @override
  Future<User?> build() async => _initial;
}

/// The nav shell renders the Home feed, which would otherwise make real HTTP
/// calls from a widget test.
class _FakeProductService implements ProductService {
  const _FakeProductService();

  List<Product> get products => const [];

  @override
  Future<ProductPage> fetchProducts({
    int page = 1,
    int limit = 20,
    String? category,
    String? search,
  }) async => ProductPage(
    products: products,
    page: 1,
    totalPages: 1,
    total: products.length,
  );

  @override
  Future<List<String>> fetchCategories() async => const ['Electronics'];

  @override
  Future<Product> fetchProduct(String id) async => products.first;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _wrap(Widget child, {List<Override> overrides = const []}) =>
    ProviderScope(
      overrides: [
        productServiceProvider.overrideWithValue(const _FakeProductService()),
        ...overrides,
      ],
      child: MaterialApp(home: child),
    );

void main() {
  group('RegisterScreen', () {
    testWidgets('rejects a short password', (tester) async {
      await tester.pumpWidget(_wrap(const RegisterScreen()));

      await tester.enterText(find.byType(TextFormField).at(0), 'Ada Lovelace');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'ada@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(2), 'short');

      await tester.tap(find.text('Sign Up'));
      await tester.pump();

      expect(
        find.text('Password must be at least 8 characters'),
        findsOneWidget,
      );
    });

    testWidgets('toggles password visibility', (tester) async {
      await tester.pumpWidget(_wrap(const RegisterScreen()));

      expect(find.byIcon(Icons.visibility), findsOneWidget);
      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pump();
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    });
  });

  group('LoginScreen', () {
    testWidgets('requires email and password', (tester) async {
      await tester.pumpWidget(_wrap(const LoginScreen()));

      await tester.tap(find.text('Sign In'));
      await tester.pump();

      expect(find.text('Enter your email'), findsWidgets);
      expect(find.text('Enter your password'), findsWidgets);
    });

    testWidgets('obscures the password field by default', (tester) async {
      await tester.pumpWidget(_wrap(const LoginScreen()));

      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byType(TextFormField).at(1),
          matching: find.byType(TextField),
        ),
      );
      expect(field.obscureText, isTrue);
    });
  });

  group('AuthGate', () {
    testWidgets('shows the login screen when signed out', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AuthGate(),
          overrides: [authProvider.overrideWith(() => _StubAuth(null))],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(MainScreen), findsNothing);
    });

    testWidgets('shows the nav shell when a session is restored', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AuthGate(),
          overrides: [authProvider.overrideWith(() => _StubAuth(_user()))],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MainScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });
  });

  group('Product', () {
    Product priced(int price) => Product(
      id: '1',
      name: 'Thing',
      description: '',
      price: price,
      category: 'Home',
      images: const [],
      stock: 1,
      rating: 0,
      ratingCount: 0,
      store: null,
    );

    test('formats prices with Indian digit grouping', () {
      expect(priced(0).formattedPrice, '₹0');
      expect(priced(649).formattedPrice, '₹649');
      expect(priced(1299).formattedPrice, '₹1,299');
      expect(priced(74999).formattedPrice, '₹74,999');
      // Indian grouping pairs digits above the first thousand.
      expect(priced(123456).formattedPrice, '₹1,23,456');
      expect(priced(12345678).formattedPrice, '₹1,23,45,678');
    });

    test('reads a populated store and tolerates a bare id', () {
      final populated = Product.fromMap({
        '_id': 'p1',
        'name': 'Mug',
        'price': 649,
        'category': 'Home',
        'store': {'_id': 's1', 'name': 'Vellum'},
      });
      expect(populated.store?.name, 'Vellum');

      final unpopulated = Product.fromMap({
        '_id': 'p2',
        'name': 'Mug',
        'price': 649,
        'category': 'Home',
        'store': 's1',
      });
      expect(unpopulated.store, isNull);
      expect(unpopulated.price, 649);
    });

    test('treats zero stock as out of stock', () {
      expect(priced(100).isInStock, isTrue);
      expect(
        Product.fromMap({'_id': 'x', 'name': 'n', 'price': 1, 'stock': 0}).isInStock,
        isFalse,
      );
    });

    test('an unreviewed product is unrated, not zero-rated', () {
      final unrated = Product.fromMap({'_id': 'x', 'name': 'n', 'price': 1});
      expect(unrated.rating, 0);
      expect(unrated.ratingCount, 0);
      expect(unrated.hasRating, isFalse);

      final rated = Product.fromMap({
        '_id': 'x', 'name': 'n', 'price': 1,
        'rating': 4.3, 'ratingCount': 3,
      });
      expect(rated.hasRating, isTrue);
      expect(rated.rating, 4.3);
    });
  });

  group('Review', () {
    Map<String, dynamic> pageMap() => {
      'reviews': [
        {
          '_id': 'r1',
          'product': 'p1',
          'user': 'u1',
          'userName': 'Karthik Iyer',
          'rating': 4,
          'comment': 'Solid quality.',
          'createdAt': '2026-08-15T09:00:00.000Z',
        },
        {'_id': 'r2', 'product': 'p1', 'user': 'u2', 'rating': 5},
      ],
      'distribution': {'1': 0, '2': 0, '3': 1, '4': 2, '5': 6},
      'total': 9,
    };

    test('reads a review and falls back for a missing name', () {
      final page = ReviewPage.fromMap(pageMap());

      expect(page.reviews.first.displayName, 'Karthik Iyer');
      expect(page.reviews.first.rating, 4);
      expect(page.reviews.first.writtenAt, isNotNull);
      // No userName on the second one, as an older account might have.
      expect(page.reviews.last.displayName, 'A customer');
      expect(page.reviews.last.comment, '');
    });

    test('reads the distribution keyed by int, filling gaps', () {
      final page = ReviewPage.fromMap(pageMap());

      expect(page.distribution[5], 6);
      expect(page.distribution[1], 0);
      expect(page.total, 9);
      // Scales the bars against the busiest band.
      expect(page.busiestBand, 6);
    });

    test('busiest band is never zero, so bars can divide by it', () {
      expect(ReviewPage.empty.busiestBand, 1);
      expect(ReviewPage.fromMap({'reviews': [], 'total': 0}).busiestBand, 1);
    });

    test('eligibility separates may-review from already-reviewed', () {
      final fresh = ReviewEligibility.fromMap({
        'canReview': true,
        'review': null,
      });
      expect(fresh.canReview, isTrue);
      expect(fresh.mine, isNull);

      final written = ReviewEligibility.fromMap({
        'canReview': true,
        'review': {'_id': 'r1', 'rating': 3},
      });
      expect(written.mine?.rating, 3);

      expect(ReviewEligibility.none.canReview, isFalse);
    });
  });

  group('Cart', () {
    Map<String, dynamic> line(String id, int price, int qty) => {
      'product': {'_id': id, 'name': 'Item $id', 'price': price, 'stock': 5},
      'quantity': qty,
    };

    test('reads totals from the server response', () {
      final cart = Cart.fromMap({
        'items': [line('a', 649, 2), line('b', 1299, 1)],
        'itemCount': 3,
        'subtotal': 2597,
      });

      expect(cart.items.length, 2);
      expect(cart.itemCount, 3);
      expect(cart.subtotal, 2597);
      expect(cart.formattedSubtotal, '₹2,597');
      expect(cart.items.first.lineTotal, 1298);
    });

    test('falls back to computing totals when they are absent', () {
      final cart = Cart.fromMap({
        'items': [line('a', 100, 2), line('b', 50, 3)],
      });

      expect(cart.itemCount, 5);
      expect(cart.subtotal, 350);
    });

    test('skips lines whose product is missing', () {
      // The server strips these, but a stale or malformed line must not throw.
      final cart = Cart.fromMap({
        'items': [
          line('a', 100, 1),
          {'product': null, 'quantity': 2},
          {'quantity': 3},
        ],
      });

      expect(cart.items.length, 1);
      expect(cart.subtotal, 100);
    });

    test('empty cart reports itself as empty', () {
      expect(Cart.empty.isEmpty, isTrue);
      expect(Cart.fromMap({'items': []}).isEmpty, isTrue);
      expect(Cart.empty.formattedSubtotal, '₹0');
    });
  });

  group('Order', () {
    Map<String, dynamic> orderMap() => {
      '_id': '6a7df758b97a5f186459c0ca',
      'items': [
        {
          'product': 'p1',
          'name': 'Stonewashed Linen Shirt',
          'price': 2499,
          'image': 'https://example.com/a.jpg',
          'quantity': 3,
          'storeName': 'Vellum & Thread',
        },
      ],
      'total': 7497,
      'status': 'placed',
      'createdAt': '2026-08-13T16:45:00.000Z',
    };

    test('reads the snapshot rather than live product data', () {
      final order = Order.fromMap(orderMap());

      expect(order.items.single.name, 'Stonewashed Linen Shirt');
      expect(order.items.single.price, 2499);
      expect(order.items.single.lineTotal, 7497);
      expect(order.items.single.storeName, 'Vellum & Thread');
      expect(order.total, 7497);
      expect(order.formattedTotal, '₹7,497');
      expect(order.itemCount, 3);
    });

    test('shortens the id for display', () {
      expect(Order.fromMap(orderMap()).reference, '#59C0CA');
      expect(Order.fromMap({'_id': ''}).reference, '');
    });

    test('defaults status and tolerates a missing date', () {
      final order = Order.fromMap({'_id': 'x', 'items': [], 'total': 0});
      expect(order.status, 'placed');
      expect(order.placedAt, isNull);
      expect(order.itemCount, 0);
      expect(order.formattedPlacedAt, '');
    });

    test('formats the placed date in the reader\'s own timezone', () {
      // Derived rather than hardcoded, so the test does not assume the machine
      // running it sits in any particular timezone.
      final local = DateTime.parse('2026-08-13T16:45:00.000Z').toLocal();
      final hh = local.hour.toString().padLeft(2, '0');
      final mm = local.minute.toString().padLeft(2, '0');

      expect(
        Order.fromMap(orderMap()).formattedPlacedAt,
        '${local.day} Aug ${local.year}, $hh:$mm',
      );
    });

    test('reads a per-line status, defaulting for older orders', () {
      // The seeded line carries no status, as orders placed before per-line
      // status existed do not.
      final map = orderMap();
      (map['items'] as List).add({
        'product': 'p2',
        'name': 'Cotton Tote',
        'price': 400,
        'quantity': 1,
        'storeName': 'Paper Lane',
        'status': 'shipped',
      });

      final order = Order.fromMap(map);
      expect(order.items.first.status, 'placed');
      expect(order.items.last.status, 'shipped');
    });

    test('offers cancelling only while nothing has shipped', () {
      bool cancellable(String status) =>
          Order.fromMap({...orderMap(), 'status': status}).canCancel;

      expect(cancellable('placed'), isTrue);
      expect(cancellable('shipped'), isFalse);
      expect(cancellable('delivered'), isFalse);
      expect(cancellable('cancelled'), isFalse);
    });

    test('advances the vendor status one step, then stops', () {
      String? next(String status) =>
          Order.fromMap({...orderMap(), 'status': status}).nextVendorStatus;

      expect(next('placed'), 'shipped');
      expect(next('shipped'), 'delivered');
      expect(next('delivered'), isNull);
      expect(next('cancelled'), isNull);
    });

    test('customer name is empty unless the vendor endpoint sent one', () {
      expect(Order.fromMap(orderMap()).customerName, '');
      expect(
        Order.fromMap({...orderMap(), 'customerName': 'Ada'}).customerName,
        'Ada',
      );
    });
  });

  group('User address', () {
    User withAddress({
      String addressLine = '12 Park Street',
      String locality = 'Park Circus',
      String city = 'Kolkata',
      String state = 'West Bengal',
      String pincode = '700016',
      String phone = '9876543210',
    }) => User(
      id: '1',
      fullName: 'Ada',
      email: 'ada@example.com',
      addressLine: addressLine,
      locality: locality,
      city: city,
      state: state,
      pincode: pincode,
      phone: phone,
    );

    test('is complete only when every required field is present', () {
      expect(withAddress().hasAddress, isTrue);
      // Locality is the one optional field.
      expect(withAddress(locality: '').hasAddress, isTrue);
      expect(withAddress(addressLine: '').hasAddress, isFalse);
      expect(withAddress(city: '').hasAddress, isFalse);
      expect(withAddress(state: '').hasAddress, isFalse);
      expect(withAddress(pincode: '').hasAddress, isFalse);
      expect(withAddress(phone: '').hasAddress, isFalse);
    });

    test('a brand new user has no address', () {
      final user = User.fromMap({'_id': 'x', 'fullName': 'New', 'email': 'n@x.com'});
      expect(user.hasAddress, isFalse);
      expect(user.addressLine, '');
    });

    test('formats for display and skips the optional line', () {
      expect(
        withAddress().formattedAddress,
        '12 Park Street\nPark Circus\nKolkata, West Bengal 700016\nPhone: 9876543210',
      );
      expect(
        withAddress(locality: '').formattedAddress,
        '12 Park Street\nKolkata, West Bengal 700016\nPhone: 9876543210',
      );
    });
  });

  group('Order shipping address', () {
    test('flattens the snapshot into one line', () {
      final order = Order.fromMap({
        '_id': 'o1',
        'items': [],
        'total': 0,
        'shippingAddress': {
          'addressLine': '12 Park Street',
          'locality': 'Park Circus',
          'city': 'Kolkata',
          'state': 'West Bengal',
          'pincode': '700016',
          'phone': '9876543210',
        },
      });
      expect(
        order.shippingAddress,
        '12 Park Street, Park Circus, Kolkata, West Bengal 700016',
      );
    });

    test('is empty for orders placed before addresses existed', () {
      expect(Order.fromMap({'_id': 'o2'}).shippingAddress, '');
    });
  });

  group('User role', () {
    test('only an explicit vendor role counts', () {
      expect(User.fromMap({'_id': '1', 'role': 'vendor'}).isVendor, isTrue);
      expect(User.fromMap({'_id': '1', 'role': 'customer'}).isVendor, isFalse);
      // Accounts predating roles have no field at all.
      expect(User.fromMap({'_id': '1'}).isVendor, isFalse);
      expect(User.fromMap({'_id': '1', 'role': ''}).isVendor, isFalse);
    });
  });

  group('AuthService', () {
    test('exposes the server message on failure', () {
      const e = ApiException('User not found with this email');
      expect(e.message, 'User not found with this email');
      expect(e.toString(), 'User not found with this email');
    });
  });

}
