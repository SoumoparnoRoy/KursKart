/// A store as it appears attached to a product in the feed. The full store
/// profile endpoint returns these fields plus its product list.
class Store {
  const Store({
    required this.id,
    required this.name,
    required this.description,
    required this.logoUrl,
  });

  final String id;
  final String name;
  final String description;
  final String logoUrl;

  factory Store.fromMap(Map<String, dynamic> map) {
    return Store(
      id: map['_id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      logoUrl: map['logoUrl'] as String? ?? '',
    );
  }
}
