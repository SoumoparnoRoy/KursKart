/// Formats whole rupees with Indian digit grouping, e.g. 123456 -> "₹1,23,456".
///
/// Grouped by hand rather than pulling in `intl` for a single format. Indian
/// grouping takes the last three digits, then pairs everything above them.
String formatRupees(int amount) {
  final digits = amount.abs().toString();
  final sign = amount < 0 ? '-' : '';

  if (digits.length <= 3) return '$sign₹$digits';

  final head = digits.substring(0, digits.length - 3);
  final tail = digits.substring(digits.length - 3);

  final groups = <String>[];
  var rest = head;
  while (rest.length > 2) {
    groups.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) groups.insert(0, rest);

  return '$sign₹${groups.join(',')},$tail';
}
