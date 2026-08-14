import 'dart:convert';

class User {
  final String id;
  final String fullName;
  final String email;
  final String addressLine;
  final String locality;
  final String city;
  final String state;
  final String pincode;
  final String phone;
  final String role;
  final String password;

  User({
    required this.id,
    required this.fullName,
    required this.email,
    this.addressLine = '',
    this.locality = '',
    this.city = '',
    this.state = '',
    this.pincode = '',
    this.phone = '',
    this.role = 'customer',
    this.password = '',
  });

  /// Accounts created before roles existed have no role at all, which reads as
  /// an empty string — so this must test for vendor rather than not-customer.
  bool get isVendor => role == 'vendor';

  /// Matches the server's rule for a usable address: locality is optional.
  bool get hasAddress =>
      addressLine.isNotEmpty &&
      city.isNotEmpty &&
      state.isNotEmpty &&
      pincode.isNotEmpty &&
      phone.isNotEmpty;

  /// Multi-line form for display, skipping any empty parts.
  String get formattedAddress => [
    addressLine,
    locality,
    '$city, $state $pincode'.trim(),
    if (phone.isNotEmpty) 'Phone: $phone',
  ].where((line) => line.trim().isNotEmpty && line.trim() != ',').join('\n');

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'fullName': fullName,
      'email': email,
      'addressLine': addressLine,
      'locality': locality,
      'city': city,
      'state': state,
      'pincode': pincode,
      'phone': phone,
      'role': role,
      'password': password,
    };
  }

  String toJson() => json.encode(toMap());

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['_id'] as String? ?? "",
      fullName: map['fullName'] as String? ?? "",
      email: map['email'] as String? ?? "",
      addressLine: map['addressLine'] as String? ?? "",
      locality: map['locality'] as String? ?? "",
      city: map['city'] as String? ?? "",
      state: map['state'] as String? ?? "",
      pincode: map['pincode'] as String? ?? "",
      phone: map['phone'] as String? ?? "",
      role: map['role'] as String? ?? "customer",
      password: map['password'] as String? ?? "",
    );
  }

  factory User.fromJson(String source) =>
      User.fromMap(json.decode(source) as Map<String, dynamic>);
}
