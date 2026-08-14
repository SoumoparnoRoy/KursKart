import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurskart/models/product.dart';
import 'package:kurskart/models/store.dart';
import 'package:kurskart/providers/auth_provider.dart';
import 'package:kurskart/providers/product_provider.dart';
import 'package:kurskart/services/vendor_service.dart';

final vendorServiceProvider = Provider<VendorService>(
  (ref) => const VendorService(),
);

/// The caller's own store, or null if they have not opened one.
final myStoreProvider = AsyncNotifierProvider<MyStoreNotifier, Store?>(
  MyStoreNotifier.new,
);

class MyStoreNotifier extends AsyncNotifier<Store?> {
  Future<String?> get _token => ref.read(tokenStorageProvider).read();
  VendorService get _service => ref.read(vendorServiceProvider);

  @override
  Future<Store?> build() async {
    final user = ref.watch(authProvider).value;
    if (user == null) return null;

    final token = await _token;
    if (token == null) return null;

    return _service.fetchMyStore(token);
  }

  Future<void> createStore({
    required String name,
    required String description,
    required String logoUrl,
  }) async {
    final token = await _token;
    if (token == null) throw StateError('Signed out');

    final store = await _service.createStore(
      token,
      name: name,
      description: description,
      logoUrl: logoUrl,
    );

    state = AsyncValue.data(store);
    // Creating a store promotes the account to vendor, so the cached user is
    // now wrong — Profile decides what to show from its role.
    ref.invalidate(authProvider);
  }

  Future<void> updateStore({
    required String name,
    required String description,
    required String logoUrl,
  }) async {
    final token = await _token;
    if (token == null) throw StateError('Signed out');

    state = AsyncValue.data(
      await _service.updateStore(
        token,
        name: name,
        description: description,
        logoUrl: logoUrl,
      ),
    );

    // The store name is shown against every product in the public feed.
    ref.invalidate(productFeedProvider);
  }
}

/// The vendor's own catalogue, including out-of-stock items.
final myProductsProvider =
    AsyncNotifierProvider<MyProductsNotifier, List<Product>>(
      MyProductsNotifier.new,
    );

class MyProductsNotifier extends AsyncNotifier<List<Product>> {
  Future<String?> get _token => ref.read(tokenStorageProvider).read();
  VendorService get _service => ref.read(vendorServiceProvider);

  @override
  Future<List<Product>> build() async {
    final user = ref.watch(authProvider).value;
    if (user == null || !user.isVendor) return const [];

    final token = await _token;
    if (token == null) return const [];

    return _service.fetchMyProducts(token);
  }

  /// Every mutation refreshes the vendor's list and the public feed, since a
  /// new or edited product should appear to shoppers straight away.
  Future<void> _afterChange() async {
    final token = await _token;
    if (token != null) {
      state = AsyncValue.data(await _service.fetchMyProducts(token));
    }
    ref.invalidate(productFeedProvider);
    ref.invalidate(categoriesProvider);
  }

  Future<void> create({
    required String name,
    required String description,
    required int price,
    required String category,
    required int stock,
    required List<String> images,
  }) async {
    final token = await _token;
    if (token == null) throw StateError('Signed out');

    await _service.createProduct(
      token,
      name: name,
      description: description,
      price: price,
      category: category,
      stock: stock,
      images: images,
    );
    await _afterChange();
  }

  /// Named updateProduct, not update: AsyncNotifier already has an `update`
  /// with a different signature, and overriding it accidentally is a compile
  /// error at best and the wrong behaviour at worst.
  Future<void> updateProduct(
    String id, {
    required String name,
    required String description,
    required int price,
    required String category,
    required int stock,
    required List<String> images,
  }) async {
    final token = await _token;
    if (token == null) throw StateError('Signed out');

    await _service.updateProduct(
      token,
      id,
      name: name,
      description: description,
      price: price,
      category: category,
      stock: stock,
      images: images,
    );
    await _afterChange();
  }

  Future<void> remove(String id) async {
    final token = await _token;
    if (token == null) throw StateError('Signed out');

    await _service.deleteProduct(token, id);
    await _afterChange();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final token = await _token;
      if (token == null) return const <Product>[];
      return _service.fetchMyProducts(token);
    });
  }
}
