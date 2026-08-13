import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Index of the selected bottom-navigation tab.
///
/// Held in a provider rather than [MainScreen]'s own state so screens inside a
/// tab can move the user elsewhere — checkout sends them to Orders.
final selectedTabProvider = StateProvider<int>((ref) => 0);

/// Tab indices, so callers do not pass bare integers around.
abstract final class Tabs {
  static const home = 0;
  static const cart = 1;
  static const orders = 2;
  static const profile = 3;
}
