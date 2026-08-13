import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurskart/models/product.dart';
import 'package:kurskart/services/product_service.dart';

final productServiceProvider = Provider<ProductService>(
  (ref) => const ProductService(),
);

/// The category currently selected in the feed. Null means "all".
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

/// The active search term. Debounced by the search field, so this only changes
/// when the user pauses typing — every change refetches the feed.
final searchQueryProvider = StateProvider<String>((ref) => '');

final categoriesProvider = FutureProvider<List<String>>(
  (ref) => ref.read(productServiceProvider).fetchCategories(),
);

/// The feed itself. Rebuilds whenever the selected category changes, because it
/// watches [selectedCategoryProvider].
final productFeedProvider = AsyncNotifierProvider<ProductFeed, List<Product>>(
  ProductFeed.new,
);

class ProductFeed extends AsyncNotifier<List<Product>> {
  ProductPage? _lastPage;

  bool get hasMore => _lastPage?.hasMore ?? false;

  @override
  Future<List<Product>> build() async {
    final page = await ref
        .read(productServiceProvider)
        .fetchProducts(
          category: ref.watch(selectedCategoryProvider),
          search: ref.watch(searchQueryProvider),
        );
    _lastPage = page;
    return page.products;
  }

  /// Pull-to-refresh. Errors surface through [state] so the list can show them.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final page = await ref
          .read(productServiceProvider)
          .fetchProducts(
            category: ref.read(selectedCategoryProvider),
            search: ref.read(searchQueryProvider),
          );
      _lastPage = page;
      return page.products;
    });
  }

  /// Appends the next page, leaving the existing items visible while it loads.
  Future<void> loadMore() async {
    final current = state.value;
    final last = _lastPage;
    if (current == null || last == null || !last.hasMore) return;

    final next = await ref
        .read(productServiceProvider)
        .fetchProducts(
          page: last.page + 1,
          category: ref.read(selectedCategoryProvider),
          search: ref.read(searchQueryProvider),
        );

    _lastPage = next;
    state = AsyncValue.data([...current, ...next.products]);
  }
}

final productDetailProvider = FutureProvider.family<Product, String>(
  (ref, id) => ref.read(productServiceProvider).fetchProduct(id),
);
