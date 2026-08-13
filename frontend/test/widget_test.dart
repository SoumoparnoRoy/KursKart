import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kurskart/models/cart.dart';
import 'package:kurskart/models/product.dart';
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

  group('AuthService', () {
    test('exposes the server message on failure', () {
      const e = ApiException('User not found with this email');
      expect(e.message, 'User not found with this email');
      expect(e.toString(), 'User not found with this email');
    });
  });

}
