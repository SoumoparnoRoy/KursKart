import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kurskart/providers/auth_provider.dart';
import 'package:kurskart/services/api_client.dart';
import 'package:kurskart/services/manage_http_response.dart';

/// Edits the single delivery address held on the user.
///
/// Pops with `true` once saved, so checkout can tell whether the user actually
/// finished or backed out.
class AddressScreen extends ConsumerStatefulWidget {
  const AddressScreen({super.key, this.reason});

  /// Shown above the form when checkout sent the user here.
  final String? reason;

  @override
  ConsumerState<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends ConsumerState<AddressScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).value;
    _fields = {
      'addressLine': TextEditingController(text: user?.addressLine ?? ''),
      'locality': TextEditingController(text: user?.locality ?? ''),
      'city': TextEditingController(text: user?.city ?? ''),
      'state': TextEditingController(text: user?.state ?? ''),
      'pincode': TextEditingController(text: user?.pincode ?? ''),
      'phone': TextEditingController(text: user?.phone ?? ''),
    };
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isSaving = true);
    try {
      await ref
          .read(authProvider.notifier)
          .saveAddress(
            addressLine: _fields['addressLine']!.text.trim(),
            locality: _fields['locality']!.text.trim(),
            city: _fields['city']!.text.trim(),
            addressState: _fields['state']!.text.trim(),
            pincode: _fields['pincode']!.text.trim(),
            phone: _fields['phone']!.text.trim(),
          );
      messenger.showSnackBar(
        const SnackBar(content: Text('Delivery address saved')),
      );
      navigator.pop(true);
    } on ApiException catch (e) {
      if (mounted) showSnackBar(context, e.message);
    } catch (_) {
      if (mounted) {
        showSnackBar(context, 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Delivery Address',
          style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  if (widget.reason != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 18,
                            color: Colors.orange.shade800,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.reason!,
                              style: GoogleFonts.nunitoSans(
                                color: Colors.orange.shade900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _field(
                    key: 'addressLine',
                    label: 'Address',
                    hint: 'House / flat, building, street',
                    maxLines: 2,
                    validator: _required('Address'),
                  ),
                  _field(
                    key: 'locality',
                    label: 'Locality (optional)',
                    hint: 'Area or landmark',
                  ),
                  _field(
                    key: 'city',
                    label: 'City',
                    validator: _required('City'),
                  ),
                  _field(
                    key: 'state',
                    label: 'State',
                    validator: _required('State'),
                  ),
                  _field(
                    key: 'pincode',
                    label: 'Pincode',
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    formatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return 'Pincode is required';
                      // Mirrors the server's rule so the user is told before
                      // a round trip.
                      if (!RegExp(r'^[1-9][0-9]{5}$').hasMatch(value)) {
                        return 'Enter a valid 6-digit pincode';
                      }
                      return null;
                    },
                  ),
                  _field(
                    key: 'phone',
                    label: 'Phone number',
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    formatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return 'Phone number is required';
                      if (!RegExp(r'^[6-9][0-9]{9}$').hasMatch(value)) {
                        return 'Enter a valid 10-digit phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 50,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 0, 47, 255),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              'Save Address',
                              style: GoogleFonts.lato(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? Function(String?) _required(String label) {
    return (value) =>
        (value ?? '').trim().isEmpty ? '$label is required' : null;
  }

  Widget _field({
    required String key,
    required String label,
    String? hint,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _fields[key],
        maxLines: maxLines,
        maxLength: maxLength,
        keyboardType: keyboardType,
        inputFormatters: formatters,
        textCapitalization: TextCapitalization.words,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          counterText: '',
          filled: true,
          fillColor: Colors.white,
          labelStyle: GoogleFonts.nunitoSans(fontSize: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
        ),
      ),
    );
  }
}
